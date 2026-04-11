// ui/App.qml
import QtQuick
import QtQuick.Controls
import PackingElf 1.0

ApplicationWindow {
    id: appWindow

    width: Constants.width
    height: Constants.height
    visible: true
    color: Theme.backgroundColor
    title: "Packingelf"

    Component.onCompleted: AppDialog.host = appDialogHost

    MainScreen {
        anchors.fill: parent
    }

    StatusPopup {
        id: appDialogHost
        parent: Overlay.overlay
    }
}
