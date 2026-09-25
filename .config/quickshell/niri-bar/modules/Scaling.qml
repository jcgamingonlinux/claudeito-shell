pragma Singleton
import QtQuick
import Quickshell

// Factor de escala global de la interfaz, calculado a partir de la altura
// del monitor con foco (ver FocusedScreen.qml) comparada contra una
// resolución de referencia. A 1920x1080 el factor es 1.0 (tamaños
// actuales sin cambio); en un monitor más chico todo se ve
// proporcionalmente más chico, y en uno más grande, más grande.
//
// OJO: esto es un eje DISTINTO de la escala HiDPI que ya aplica Wayland
// según el "scale" que configures en tu compositor (niri/sway/Hyprland)
// para cada output — eso sigue funcionando igual y se combina con esto,
// no lo reemplaza. Este factor es para que la interfaz se vea
// proporcionalmente parecida entre pantallas de distinta RESOLUCIÓN
// lógica (ej. un laptop 1366x768 vs. un monitor 1920x1080), no para
// pantallas físicamente densas.
QtObject {
    id: root

    readonly property int referenceHeight: 1080

    // Límites para que la interfaz nunca quede ilegiblemente chica ni
    // descomunalmente grande en resoluciones extremas.
    readonly property real minFactor: 0.75
    readonly property real maxFactor: 1.6

    property real factor: 1.0
    readonly property real userFactor: BarConfig.scalePercent / 100.0

    // Mapa screenName -> factor, calculado independientemente para CADA
    // pantalla conectada (no solo la que tiene el foco). Antes "factor"
    // era el único valor global y todo (Scaling.px) lo usaba sin importar
    // en qué monitor se estuviera dibujando: con monitores de resoluciones
    // muy distintas (ej. 1360x768 y 4K), la barra del monitor chico se
    // ponía enorme cuando el foco estaba en el 4K, y viceversa. Ahora la
    // barra y sus módulos (ver Bar.qml y BarModule.qml) usan pxFor() con
    // el nombre de SU propia pantalla en vez del factor global.
    property var screenFactors: ({})

    function computeFactor(h) {
        let raw = h / root.referenceHeight
        return Math.max(root.minFactor, Math.min(root.maxFactor, raw))
    }

    // Atajo para escalar un tamaño fijo: Scaling.px(22) en vez de
    // "22 * Scaling.factor" repetido en cada módulo.
    function px(n) {
        return n * root.factor * root.userFactor
    }

    // Igual que px(), pero calculado con la resolución de una pantalla
    // puntual en vez de la que tiene el foco. Usar para todo lo que se
    // dibuja per-pantalla (la barra y sus módulos); para popups únicos
    // (que siempre aparecen en la pantalla con foco) px() sigue sirviendo.
    function pxFor(screenName, n) {
        let f = root.screenFactors[screenName]
        if (f === undefined) f = root.factor
        return n * f * root.userFactor
    }

    function recomputeAll() {
        let screens = Quickshell.screens
        let map = {}
        for (let i = 0; i < screens.length; i++)
            map[screens[i].name] = root.computeFactor(screens[i].height)
        root.screenFactors = map
    }

    function recompute() {
        root.recomputeAll()
        let screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === FocusedScreen.name) {
                root.factor = root.computeFactor(screens[i].height)
                return
            }
        }
        // Respaldo: si todavía no hay monitor con foco detectado (recién
        // arrancando), usa el primero disponible.
        if (screens.length > 0) root.factor = root.computeFactor(screens[0].height)
    }

    property Connections _watcher: Connections {
        target: FocusedScreen
        function onNameChanged() { root.recompute() }
    }

    property Connections _screenWatcher: Connections {
        target: Quickshell
        function onScreensChanged() { root.recompute() }
    }

    Component.onCompleted: root.recompute()
}
