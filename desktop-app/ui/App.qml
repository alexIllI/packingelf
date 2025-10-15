// ui/App.qml
import QtQuick
import QtQuick.Controls
import PackingElf 1.0

ApplicationWindow {
    width: Constants.width
    height: Constants.height
    visible: true
    color: Theme.backgroundColor
    title: "Packingelf"

    MainScreen {
        anchors.fill: parent
    }
}
