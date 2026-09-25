pragma Singleton
import QtQuick
import Quickshell.Io

// Ruta del fondo de pantalla actual, persistida en disco para que
// sobreviva a reinicios de quickshell/la sesión.
QtObject {
    id: root

    property string current: ""
    // Última posición navegada en el selector, para retomar ahí la próxima vez
    property int lastIndex: 0

    // Cómo se ajusta la imagen a la pantalla: "fill" (recorta manteniendo
    // proporción, llena toda la pantalla -- el comportamiento de antes,
    // y el default), "center" (tamaño original, centrada, sin escalar),
    // "stretch" (estirada para llenar exacto, sin mantener proporción).
    property string fillMode: "fill"
    readonly property var _validFillModes: ["fill", "center", "stretch"]

    function load() { reader.running = true; fillModeReader.running = true }

    function setWallpaper(path) {
        root.current = path
        // Codificado en base64 al escribir para evitar cualquier problema
        // de comillas/espacios/caracteres especiales en la ruta.
        let b64 = Qt.btoa(path)
        writer.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + b64 + "' | base64 -d > \"$HOME/.config/quickshell/wallpaper-path.txt\""]
        writer.running = true
    }

    function setFillMode(mode) {
        if (root._validFillModes.indexOf(mode) === -1) return
        root.fillMode = mode
        fillModeWriter.command = ["sh", "-c",
            "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + mode + "' > \"$HOME/.config/quickshell/wallpaper-fillmode.txt\""]
        fillModeWriter.running = true
    }

    property Process reader: Process {
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/wallpaper-path.txt\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim()
                if (p.length > 0) root.current = p
            }
        }
    }

    property Process writer: Process { }

    property Process fillModeReader: Process {
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/wallpaper-fillmode.txt\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let m = text.trim()
                if (root._validFillModes.indexOf(m) !== -1) root.fillMode = m
            }
        }
    }

    property Process fillModeWriter: Process { }

    Component.onCompleted: root.load()
}
