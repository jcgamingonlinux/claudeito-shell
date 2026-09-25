pragma Singleton
import QtQuick

// Guarda la posición (x, ancho) de cada módulo de la barra, para que sus
// cajas de info (CPU/RAM/Temp/Volumen/Red) puedan centrarse justo debajo.
//
// Deliberadamente son propiedades planas (no un mapa indexado por clave
// dinámica como antes) — cada indicador solo actualiza la suya cuando
// está en la pantalla con foco (ver reportPos() en cada módulo), así que
// no hace falta guardar todas las pantallas a la vez, y esto evita
// depender de que la reactividad de QML funcione bien con lecturas tipo
// "objeto[clave]" (que en algunas versiones no siempre se comporta como
// se espera).
QtObject {
    property real cpuX: 0
    property real cpuWidth: 0

    property real ramX: 0
    property real ramWidth: 0

    property real tempX: 0
    property real tempWidth: 0

    property real volX: 0
    property real volWidth: 0

    property real lanX: 0
    property real lanWidth: 0

    property real batteryX: 0
    property real batteryWidth: 0

    property real bluetoothX: 0
    property real bluetoothWidth: 0

    property real menuX: 0
    property real menuWidth: 0

    property real clockX: 0
    property real clockWidth: 0

    property real notificationsX: 0
    property real notificationsWidth: 0

    property real powerX: 0
    property real powerWidth: 0

    property real configDockX: 0
    property real configDockWidth: 0
}
