pragma Singleton
import QtQuick

QtObject {
    property bool calendarOpen: false
    // Dos launchers independientes: click en Menu (arriba-izq) vs atajo (centrado)
    property bool menuLauncherOpen: false
    property bool shortcutLauncherOpen: false
    // Dos menús de energía independientes: click en Power (arriba-der) vs atajo (centrado)
    property bool menuPowerOpen: false
    property bool shortcutPowerOpen: false
    property bool wallpaperPickerOpen: false
    property bool networkPopupOpen: false
    property bool cpuPopupOpen: false
    property bool ramPopupOpen: false
    property bool tempPopupOpen: false
    property bool volumeOsdVisible: false
    // Abierto explícitamente al hacer click en VOL. Es independiente del OSD
    // temporal que muestran la rueda y las teclas multimedia.
    property bool volumePopupOpen: false
    property bool notificationsOpen: false
    property bool keybindsOpen: false
    property bool configDockOpen: false
    property bool barConfigOpen: false
    property bool batteryPopupOpen: false
    property bool bluetoothPopupOpen: false
    property bool windowListOpen: false

    // barConfigOpen y windowListOpen no solo deben ignorar el click afuera
    // y el cambio de foco para CERRARSE -- tampoco deben "arrastrarse" a
    // la pantalla que pasa a tener el foco mientras siguen abiertos (eso
    // pasaba porque en shell.qml su visibilidad dependía de
    // FocusedScreen.name). Acá se guarda en qué pantalla estaban cuando
    // se abrieron, y shell.qml los ancla a ESA en vez de a la del foco.
    property string barConfigScreen: ""
    property string windowListScreen: ""
    onBarConfigOpenChanged: if (barConfigOpen) barConfigScreen = FocusedScreen.name
    onWindowListOpenChanged: if (windowListOpen) windowListScreen = FocusedScreen.name

    // Fuerza a todas las barras (todas las pantallas) a ocultarse sin
    // importar hover/timer/autoHide. La setea el IPC "bar-visibility"
    // (hide/show/toggle) -- pensado para el listener de eventos de
    // fullscreen de Hyprland (ver README), que en algunas versiones no
    // oculta automáticamente los layer-surfaces "Top" al entrar a
    // pantalla completa.
    property bool barForceHidden: false

    // Reactiva: true si hay cualquier popup de la barra abierto. La usa el
    // auto-ocultado para no replegar la barra mientras un popup suyo sigue
    // abierto (quedaría "flotando" sin la barra debajo).
    readonly property bool anyPopupOpen: calendarOpen || menuLauncherOpen || shortcutLauncherOpen
        || menuPowerOpen || shortcutPowerOpen || wallpaperPickerOpen || networkPopupOpen
        || cpuPopupOpen || ramPopupOpen || tempPopupOpen || volumePopupOpen
        || notificationsOpen || keybindsOpen || configDockOpen || barConfigOpen || batteryPopupOpen
        || bluetoothPopupOpen || windowListOpen

    // Igual que anyPopupOpen, pero sin contar barConfigOpen/windowListOpen
    // (esos dos NO deben cerrarse con click afuera ni al cambiar de
    // pantalla -- ver closeScreenBoundPopups() más abajo). La usa la
    // "red de seguridad" para click afuera en otra pantalla, en shell.qml.
    readonly property bool anyScreenBoundPopupOpen: anyPopupOpen && !barConfigOpen && !windowListOpen

    // Los popups de la barra son mutuamente excluyentes. Esto también evita
    // que un click en la barra deje el popup anterior abierto por debajo.
    function closeTransientPopups() {
        calendarOpen = false
        menuLauncherOpen = false
        shortcutLauncherOpen = false
        menuPowerOpen = false
        shortcutPowerOpen = false
        wallpaperPickerOpen = false
        networkPopupOpen = false
        cpuPopupOpen = false
        ramPopupOpen = false
        tempPopupOpen = false
        volumePopupOpen = false
        notificationsOpen = false
        keybindsOpen = false
        configDockOpen = false
        barConfigOpen = false
        batteryPopupOpen = false
        bluetoothPopupOpen = false
        windowListOpen = false
    }

    function togglePopup(propertyName) {
        const shouldOpen = !this[propertyName]
        closeTransientPopups()
        this[propertyName] = shouldOpen
    }

    // Para popups que se abren por atajo de teclado/IPC (no por click en
    // un módulo de la barra): antes de abrirlos, se fuerza una consulta
    // fresca de qué pantalla tiene el foco. Sin esto, si cambiás de
    // workspace con un atajo del compositor y enseguida abrís el launcher
    // por SU atajo (sin llegar a hacer click en nada), había una carrera
    // -- nuestra detección de foco (asíncrona, vía swaymsg/niri msg/
    // hyprctl) a veces no había terminado de actualizarse todavía, y el
    // popup se abría en la pantalla/workspace VIEJO. Un click normal en
    // un módulo no tiene este problema porque el click en sí mismo ya
    // fuerza el foco de inmediato.
    function togglePopupFresh(propertyName) {
        FocusedScreen.refresh()
        freshOpenTimer.targetProp = propertyName
        freshOpenTimer.restart()
    }
    property Timer freshOpenTimer: Timer {
        property string targetProp: ""
        interval: 60
        onTriggered: Bridge.togglePopup(targetProp)
    }

    // Los popups solo se dibujan en la pantalla con foco (ver shell.qml:
    // "modelData.name === FocusedScreen.name"). Si el foco pasa a OTRA
    // pantalla mientras uno está abierto, dejaba de verse pero seguía
    // "abierto" en los datos -- clickear en la otra pantalla no lo cerraba
    // (ningún MouseArea de cierre existe ahí), y al volver a la pantalla
    // original reaparecía solo, sin haber hecho nada. Cerrarlos apenas
    // cambia el foco evita ese comportamiento fantasma.
    //
    // barConfigOpen y windowListOpen quedan afuera a propósito: para esos
    // dos se pidió específicamente que SOLO se cierren con Esc o su botón
    // X -- ni con click afuera, ni al mover el mouse/foco a otra pantalla.
    function closeScreenBoundPopups() {
        calendarOpen = false
        menuLauncherOpen = false
        shortcutLauncherOpen = false
        menuPowerOpen = false
        shortcutPowerOpen = false
        wallpaperPickerOpen = false
        networkPopupOpen = false
        cpuPopupOpen = false
        ramPopupOpen = false
        tempPopupOpen = false
        volumePopupOpen = false
        notificationsOpen = false
        keybindsOpen = false
        configDockOpen = false
        batteryPopupOpen = false
        bluetoothPopupOpen = false
    }

    property string _lastFocusedScreenName: ""
    property Connections _focusWatcher: Connections {
        target: FocusedScreen
        function onNameChanged() {
            if (Bridge._lastFocusedScreenName !== ""
                && Bridge._lastFocusedScreenName !== FocusedScreen.name
                && Bridge.anyPopupOpen) {
                Bridge.closeScreenBoundPopups()
            }
            Bridge._lastFocusedScreenName = FocusedScreen.name
        }
    }
}
