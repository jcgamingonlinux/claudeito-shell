pragma Singleton
import QtQuick
import Quickshell.Io

// Escanea las apps instaladas (.desktop) -- compartido por los 2 launchers
// (botón Menu + atajo de teclado) para no duplicar el trabajo entre ellos.
// El listado completo SIGUE actualizándose cada vez que se abre un
// launcher (rescan()), para que una app recién instalada aparezca sin
// esperar a la próxima sesión. Lo único que se congela por sesión es el
// RANKING de "más usadas" (ver AppUsage.pinTop()).
//
// Dos cambios acá para que el escaneo no tarde varios segundos ni
// bloquee la interfaz (antes, mientras escaneaba, no se podía navegar
// ni siquiera el listado fijo de más-usadas):
//
// 1) Antes se leía cada .desktop con grep+cut+sed+tr por CADA campo
//    (NoDisplay, Hidden, Name, Exec, Icon) -- unos 10-11 procesos hijos
//    por app. Con las ~300-500 apps instaladas que deja Flatpak en un
//    equipo con varios meses de uso, eso son varios miles de procesos, y
//    ESE forking resultó ser, con diferencia, la parte más lenta de todo
//    el escaneo (medido: un solo proceso `awk` que lee y parsea TODOS
//    los .desktop de una sola pasada es un ~100x más rápido, con
//    exactamente la misma salida campo por campo).
//
// 2) Antes, cada línea que iba llegando del escaneo (cada app
//    encontrada) reasignaba "apps" de inmediato -- y eso disparaba, en
//    cada instancia de LauncherPopup que existiera (abierta o cerrada,
//    en cualquier monitor), un reordenamiento completo del listado.
//    Con varios cientos de apps eso son varios cientos de
//    reordenamientos por escaneo. Ahora el resultado se junta en un
//    buffer local (que no dispara nada al modificarse) y "apps" se
//    reasigna una sola vez, al terminar el escaneo completo.
QtObject {
    id: root

    property var apps: []
    // true en cuanto termina el escaneo en curso (haya encontrado apps o
    // no), para poder distinguir "todavía escaneando" de "no se encontró
    // ninguna". Se pone en false apenas arranca un nuevo rescan().
    property bool scanned: false

    // Enumera los mismos directorios/patrones que antes (sin forks: el
    // `for` + `[ -f ]` son builtins del shell) y arma la lista de
    // archivos existentes; UN solo `awk` los procesa a todos. awk toma
    // el primer NoDisplay=/Hidden=/Name=/Exec=/Icon= de cada archivo
    // (igual que el `grep -m1` de antes -- si un .desktop tiene además
    // secciones tipo "Desktop Action", se ignoran igual que antes),
    // limpia %f/%F/%u/%U/%i/%c y los tokens "@@...@@"/"@@" de Flatpak
    // del Exec, y saca comillas/backslashes de los 3 campos para no
    // complicar el escapado de JSON -- mismo criterio que antes, mismo
    // formato de salida.
    readonly property string scanScript: `
set --
for f in \\
  "$HOME"/.local/share/applications/*.desktop \\
  "$HOME"/.local/share/flatpak/exports/share/applications/*.desktop \\
  /var/lib/flatpak/exports/share/applications/*.desktop \\
  /usr/local/share/applications/*.desktop \\
  /usr/share/applications/*.desktop \\
  /usr/share/applications/*/*.desktop; do
  [ -f "$f" ] && set -- "$@" "$f"
done
[ "$#" -eq 0 ] && exit 0
awk '
  FNR == 1 { if (NR > 1) emit(); name=""; execraw=""; icon=""; nodisplay=""; hidden=""; hN=0; hE=0; hI=0; hD=0; hH=0 }
  !hD && /^NoDisplay=/ { nodisplay = substr($0, index($0,"=")+1); hD=1 }
  !hH && /^Hidden=/    { hidden    = substr($0, index($0,"=")+1); hH=1 }
  !hN && /^Name=/      { name      = substr($0, index($0,"=")+1); hN=1 }
  !hE && /^Exec=/      { execraw   = substr($0, index($0,"=")+1); hE=1 }
  !hI && /^Icon=/      { icon      = substr($0, index($0,"=")+1); hI=1 }
  END { emit() }
  function emit(   ) {
    if (nodisplay == "true") return
    if (hidden == "true") return
    if (name == "") return
    gsub(/%[fFuUick]/, "", execraw)
    gsub(/@@[a-zA-Z]*/, "", execraw)
    gsub(/@@/, "", execraw)
    gsub(/["\\\\]/, "", name)
    gsub(/["\\\\]/, "", execraw)
    gsub(/["\\\\]/, "", icon)
    if (execraw == "") return
    printf "{\\"name\\":\\"%s\\",\\"exec\\":\\"%s\\",\\"icon\\":\\"%s\\"}\\n", name, execraw, icon
  }
' "$@"
`

    function rescan() {
        // Evita disparar un segundo escaneo mientras uno ya está en
        // curso -- eso era lo que causaba que cada app apareciera 2 veces:
        // ambos escaneos superpuestos escribían sobre el mismo arreglo.
        if (root.scanning) return
        root.scanning = true
        root.scanned = false
        // "apps" NO se vacía acá -- el listado (más-usadas Y el resto)
        // queda tal cual estaba, navegable y buscable, hasta que este
        // escaneo termine y lo reemplace de una sola vez. Antes se
        // vaciaba de inmediato, así que CADA apertura del launcher
        // mostraba la lista en blanco mientras durara el escaneo.
        root._buffer = []
        scanner.command = ["sh", "-c", root.scanScript]
        scanner.running = true
    }

    property bool scanning: false

    // Buffer local de la pasada en curso. Se le hace push() línea a
    // línea; eso MUTA el arreglo sin reasignar la propiedad, así que no
    // dispara ningún reordenamiento en los launchers -- eso pasa una
    // sola vez, al final (onExited).
    property var _buffer: []

    property Process scanner: Process {
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                try {
                    root._buffer.push(JSON.parse(t))
                } catch (e) { /* línea no válida, se ignora */ }
            }
        }
        onExited: {
            // Un solo cambio de "apps" al final del escaneo completo --
            // antes se reasignaba una vez POR CADA app encontrada (podían
            // ser cientos), y cada una de esas reasignaciones disparaba
            // un reordenamiento completo en cada instancia de
            // LauncherPopup que existiera.
            root.apps = root._buffer
            root.scanned = true
            root.scanning = false
            // Solo la PRIMERA vez que termina un escaneo en esta sesión se
            // usa para fijar el ranking de más-usadas -- ver AppUsage.qml.
            // Escaneos posteriores (cada vez que se reabre un launcher)
            // siguen actualizando root.apps con normalidad, pero no tocan
            // ese ranking ya fijado.
            AppUsage.pinTop(root.apps)
        }
    }

    // Se escanea una vez al arrancar quickshell para tener datos desde el
    // primer instante (por si el launcher se abre casi enseguida).
    Component.onCompleted: root.rescan()
}
