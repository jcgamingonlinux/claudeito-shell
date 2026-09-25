import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Nombre del monitor (output) donde vive esta barra, para que
    // Workspaces sepa filtrar y mostrar solo los suyos.
    property string screenName: ""
    // Referencia a la PanelWindow real de esta barra, para que SysTray
    // pueda mostrarle el menú contextual (nativo) de un ícono.
    property var barWindow: null

    // Auto-ocultar: la ventana contenedora (ver shell.qml) controla esta
    // propiedad. Cuando es false, el contenido de la barra se desliza fuera
    // de pantalla (hacia arriba o abajo según la posición) en vez de
    // ocultar la ventana entera, así el hover-catcher de abajo sigue
    // pudiendo detectar el mouse en el borde para volver a mostrarla.
    property bool revealed: true

    implicitHeight: Math.max(leftGroup.implicitHeight, centerGroup.implicitHeight, rightGroup.implicitHeight, Scaling.pxFor(screenName, 24))

    transform: Translate {
        y: root.revealed ? 0 : (BarConfig.barAtBottom ? (root.height + 4) : -(root.height + 4))
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    // Cierra el popup activo al pulsar una zona vacía de la barra. Los
    // controles interactivos cierran además los demás popups al abrirse.
    MouseArea {
        anchors.fill: parent
        // Hyprland puede dejar la superficie de la barra por encima del
        // overlay transparente del popup. Mantener esta área por encima del
        // fondo del Bar garantiza que esos clicks también se procesen aquí.
        // Los grupos con controles quedan por encima para conservar sus
        // acciones normales.
        z: 0
        onClicked: Bridge.closeTransientPopups()
    }

    // --- Izquierda: menú y espacios de trabajo ---
    RowLayout {
        id: leftGroup
        z: 1
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Scaling.pxFor(screenName, 12)

        // "config" (Ajustes) ahora es un módulo más de BarConfig.modules: se
        // puede mover de zona u ocultar como cualquier otro. Sigue siendo el
        // primero por defecto (ver defaultModules() en BarConfig.qml).
        Repeater {
            model: BarConfig.modulesFor("left")
            delegate: BarModule { required property var modelData; moduleId: modelData.id; screenName: root.screenName; barWindow: root.barWindow }
        }
    }

    // --- Derecha: cpu, ram, volumen, red, tray+notificaciones, batería, hora, power ---
    RowLayout {
        id: rightGroup
        z: 1
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Scaling.pxFor(screenName, 14)

        Repeater {
            model: BarConfig.modulesFor("right")
            delegate: BarModule { required property var modelData; moduleId: modelData.id; screenName: root.screenName; barWindow: root.barWindow }
        }
    }

    // --- Centro: ventana activa, centrado en el ancho total de la barra
    // (no en el espacio libre entre izquierda y derecha) -- así con un
    // solo módulo queda justo en el medio de la pantalla. Si el contenido
    // llegara a ser más ancho que el hueco disponible (ej. un título de
    // ventana largo), no se deja invadir a leftGroup/rightGroup: el x se
    // recorta a los bordes disponibles en vez de superponerse.
    RowLayout {
        id: centerGroup
        z: 1
        anchors.verticalCenter: parent.verticalCenter
        spacing: Scaling.pxFor(screenName, 12)

        readonly property real _minX: leftGroup.x + leftGroup.width + Scaling.pxFor(screenName, 12)
        readonly property real _maxX: rightGroup.x - width - Scaling.pxFor(screenName, 12)
        x: Math.max(_minX, Math.min((root.width - width) / 2, _maxX))

        Repeater {
            model: BarConfig.modulesFor("center")
            delegate: BarModule { required property var modelData; moduleId: modelData.id; screenName: root.screenName; barWindow: root.barWindow }
        }
    }
}
