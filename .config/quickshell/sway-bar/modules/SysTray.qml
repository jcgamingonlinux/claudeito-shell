import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    id: root
    spacing: Scaling.pxFor(screenName, 6)

    // Ventana real de la barra en este monitor, pasada desde Bar.qml. Se
    // necesita explícitamente porque display() exige una ventana concreta.
    property var barWindow: null

    // Nombres de ícono de TEMA candidatos (nunca rutas): tal cual, y en
    // minúsculas -- por si algún tray declara el nombre con mayúsculas
    // que no coinciden con el tema.
    function iconNameCandidates(name) {
        let names = []
        if (!name || name.length === 0) return names
        names.push(name)
        let lower = name.toLowerCase()
        if (lower !== name) names.push(lower)
        return names
    }

    // Nombres de ejecutable posibles a partir de una línea Exec= de un
    // .desktop. Contempla Flatpak, donde el primer token de Exec=
    // SIEMPRE es "flatpak" (el ejecutable real está en --command=X, o
    // en el app-id reverse-DNS al final, ej. "org.videolan.VLC") -- si
    // no se contempla este caso, ninguna app instalada por Flatpak
    // cruza nunca con AppList.
    function execMatchCandidates(exec) {
        let e = (exec || "").trim()
        if (e.length === 0) return []
        let out = []
        let cmdMatch = e.match(/--command=(\S+)/)
        if (cmdMatch) out.push(cmdMatch[1].split("/").pop().toLowerCase())
        let idMatch = e.match(/\b[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_-]+){2,}\b/)
        if (idMatch) {
            let id = idMatch[0].toLowerCase()
            out.push(id)
            let leaf = id.split(".").pop()
            if (leaf.length > 0 && leaf !== id) out.push(leaf)
        }
        out.push(e.split(" ")[0].split("/").pop().toLowerCase())
        return out
    }

    // Busca en AppList (mismo escaneo de .desktop que usa el launcher)
    // una app cuyo ejecutable coincida con el nombre pedido, y devuelve
    // su Icon= tal cual está declarado.
    function appListIconValue(name) {
        if (!name || name.length === 0) return ""
        let lower = name.toLowerCase()
        let match = AppList.apps.find(a => {
            let candidates = root.execMatchCandidates(a.exec)
            return candidates.some(exe => exe.length > 0 && (exe === lower
                || (lower.length >= 4 && exe.indexOf(lower) !== -1)
                || (exe.length >= 4 && lower.indexOf(exe) !== -1)))
        })
        return (match && match.icon) ? match.icon : ""
    }

    // Resuelve un valor de Icon= a una fuente usable -- nombre de tema,
    // ruta absoluta, o "~/...".
    function resolveIconValue(icon) {
        if (!icon || icon.length === 0) return ""
        let resolved = icon
        if (resolved === "~" || resolved.startsWith("~/")) {
            let home = Quickshell.env("HOME") || ""
            resolved = home + resolved.slice(1)
        }
        if (resolved.startsWith("/")) return "file://" + resolved
        return Quickshell.iconPath(resolved, true)
    }

    function resolvedIcon(rawIcon) {
        let s = (rawIcon || "").toString()
        let marker = "image://icon/"
        // Solo los íconos por NOMBRE de tema vienen como "image://icon/...".
        // Otros casos (ej. "image://qspixmap/..." de apps como OBS, que
        // mandan una imagen embebida directa por D-Bus en vez de un
        // nombre) ya son una fuente de imagen válida tal cual -- re-
        // envolverlos como si fueran un nombre de tema los rompía.
        if (!s.startsWith(marker)) return s
        let name = s.slice(marker.length)
        if (name.length === 0) return Quickshell.iconPath("application-x-executable", true)

        // "check" (booleano) en vez de "fallback" (string) -- mismo
        // motivo que ActiveWindow.qml/WindowListPopup.qml.
        let names = root.iconNameCandidates(name)
        for (let i = 0; i < names.length; i++) {
            let resolved = Quickshell.iconPath(names[i], true)
            if (resolved.length > 0) return resolved
        }

        // El nombre que declara el tray por D-Bus a veces no es el mismo
        // con el que Flatpak exportó el ícono -- VLC, por ejemplo,
        // declara "vlc" (hardcodeado en su propio código, sin relación
        // con el empaquetado), pero Flatpak solo exporta el ícono como
        // "org.videolan.VLC". Mismo cruce contra AppList que ya usan
        // ActiveWindow.qml/WindowListPopup.qml para este tipo de
        // desajuste.
        let fromAppList = root.resolveIconValue(root.appListIconValue(name))
        if (fromAppList.length > 0) return fromAppList

        // Ni el tema ni AppList lo resuelven -- probamos un pixmap
        // suelto por nombre de archivo antes de rendirnos.
        return "file:///usr/share/pixmaps/" + name + ".png"
    }

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property var modelData
            implicitWidth: Scaling.pxFor(screenName, 18)
            implicitHeight: Scaling.pxFor(screenName, 18)

            // Fallback visible cuando el ícono del tray no se puede resolver
            // (falta el nombre en el tema de íconos instalado, ej.
            // "network-wired", "hwloc", etc.) — muestra la inicial del
            // título en vez de quedar en blanco/roto.
            Rectangle {
                anchors.fill: parent
                radius: Scaling.pxFor(screenName, 3)
                color: "#313244"
                visible: trayIcon.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: (trayItem.modelData.title && trayItem.modelData.title.length > 0)
                          ? trayItem.modelData.title.charAt(0).toUpperCase() : "?"
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 9)
                    font.bold: true
                }
            }

            IconImage {
                id: trayIcon
                anchors.fill: parent
                asynchronous: true
                property bool triedPixmapFallback: false
                source: root.resolvedIcon(trayItem.modelData.icon)
                onStatusChanged: {
                    if (status !== Image.Error) return
                    if (!triedPixmapFallback) {
                        // Muchos temas minimalistas (ej. Adwaita) no traen
                        // íconos de apps de terceros como VLC. Antes de
                        // rendirnos, probamos la ubicación clásica
                        // /usr/share/pixmaps -- varios paquetes dejan ahí
                        // una copia como respaldo para clientes que no
                        // resuelven temas de íconos.
                        triedPixmapFallback = true
                        let raw = (trayItem.modelData.icon || "").toString()
                        let name = raw.split("/").pop().replace(/\?.*$/, "").replace(/\.(png|svg|xpm)$/i, "")
                        if (name.length > 0) source = "file:///usr/share/pixmaps/" + name + ".png"
                    } else {
                        console.log("SysTray: no cargó el ícono de \"" + (trayItem.modelData.title || "?")
                                    + "\" -- source pedido:", trayItem.modelData.icon)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: Bridge.closeTransientPopups()
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        console.log("SysTray:", trayItem.modelData.title || "?",
                                    "hasMenu =", trayItem.modelData.hasMenu)

                        if (trayItem.modelData.hasMenu) {
                            if (!root.barWindow) {
                                console.log("SysTray: no hay barWindow para display()")
                            } else {
                                try {
                                    let pos = trayItem.mapToItem(root.barWindow.contentItem, 0, trayItem.height)
                                    trayItem.modelData.display(root.barWindow, pos.x, pos.y)
                                } catch (e) {
                                    console.log("SysTray: display() falló:", e)
                                }
                            }
                        }
                    } else {
                        trayItem.modelData.activate()
                    }
                }
            }
        }
    }
}
