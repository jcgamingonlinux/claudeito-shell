pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

// NOTA IMPORTANTE: este módulo registra a Quickshell como el demonio de
// notificaciones de D-Bus (org.freedesktop.Notifications). Solo UNA
// aplicación puede tener ese rol a la vez — asegúrate de que mako, dunst,
// swaync, etc. NO estén corriendo (ni en el autostart de sway/niri), o
// habrá conflicto por quién atiende las notificaciones.
//
// Los nombres exactos de propiedades/señales de NotificationServer
// (onNotification, appName, summary, body, urgency, expireTimeout,
// actions[].identifier/.text, tracked, closed, dismiss) son los que usan
// la mayoría de los shells de Quickshell que existen hoy, pero es la
// parte de la API más nueva/sensible a la versión instalada. Si algo no
// compila, el error de quickshell suele señalar exactamente qué propiedad
// o señal no existe — compara contra la documentación de tu versión en
// quickshell.outfoxxed.me (Quickshell.Services.Notifications).

QtObject {
    id: root

    // Notificaciones visibles ahora mismo (toasts flotantes)
    property var active: []
    // Historial reciente (para el desplegable del área de notificaciones)
    property var history: []
    readonly property int maxHistory: 50
    readonly property int defaultTimeout: 5000
    // Contador para dar a cada entrada del historial un id único propio
    // (el id de D-Bus se puede reciclar entre notificaciones distintas,
    // así que no sirve para borrar una sola del historial con seguridad).
    property int historyCounter: 0

    property NotificationServer server: NotificationServer {
        onNotification: (notification) => {
            // Sin esto, Quickshell puede destruir el objeto apenas termina
            // este handler; lo necesitamos vivo para leer sus campos y
            // poder invocar acciones/objetar el cierre más tarde.
            notification.tracked = true

            let entry = {
                id: notification.id,
                historyId: root.historyCounter++,
                appName: notification.appName || "",
                summary: notification.summary || "",
                body: notification.body || "",
                urgency: notification.urgency,
                actions: (notification.actions || []).map(a => ({ id: a.identifier, text: a.text })),
                time: new Date(),
                _ref: notification
            }

            let act = root.active.slice()
            act.push(entry)
            root.active = act

            let hist = root.history.slice()
            hist.unshift(entry)
            if (hist.length > root.maxHistory) hist = hist.slice(0, root.maxHistory)
            root.history = hist

            // Si la app o el usuario cierran la notificación por su cuenta
            // (p. ej. Discord la retira sola), la sacamos de "activas" ya.
            notification.closed.connect(() => root.removeActive(entry.id))

            let timeoutMs = notification.expireTimeout > 0 ? notification.expireTimeout : root.defaultTimeout
            let timer = Qt.createQmlObject(
                "import QtQuick; Timer { interval: " + timeoutMs + "; running: true; repeat: false }",
                root
            )
            timer.triggered.connect(() => {
                root.removeActive(entry.id)
                timer.destroy()
            })
        }
    }

    function removeActive(id) {
        root.active = root.active.filter(n => n.id !== id)
    }

    function invokeAction(entry, actionId) {
        if (entry._ref && entry._ref.actions) {
            let a = entry._ref.actions.find(x => x.identifier === actionId)
            if (a) a.invoke()
        }
        removeActive(entry.id)
    }

    function dismiss(entry) {
        if (entry._ref) entry._ref.dismiss()
        removeActive(entry.id)
    }

    function clearHistory() { root.history = [] }

    function removeFromHistory(historyId) {
        root.history = root.history.filter(n => n.historyId !== historyId)
    }
}
