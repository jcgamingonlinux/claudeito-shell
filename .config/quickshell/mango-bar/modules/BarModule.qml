import QtQuick

Loader {
    id: root
    property string moduleId: ""
    property string screenName: ""
    property var barWindow: null
    source: {
        const files = { config: "ConfigButton.qml", menu: "MenuButton.qml", workspaces: "Workspaces.qml", activeWindow: "ActiveWindow.qml",
            cpu: "Cpu.qml", ram: "Ram.qml", temp: "Temp.qml", volume: "VolumeIndicator.qml",
            network: "NetworkIndicator.qml", systray: "SysTray.qml", notifications: "NotificationCenterButton.qml",
            keybinds: "KeybindsButton.qml", configDock: "ConfigDockButton.qml", battery: "BatteryIndicator.qml", bluetooth: "BluetoothIndicator.qml", windowlist: "WindowListButton.qml", clock: "Clock.qml", power: "PowerMenu.qml" }
        return files[moduleId] || ""
    }
    onLoaded: {
        if (item && item.hasOwnProperty("screenName")) item.screenName = screenName
        if (item && item.hasOwnProperty("barWindow")) item.barWindow = barWindow
    }
}

