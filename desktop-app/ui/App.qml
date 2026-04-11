// ui/App.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ApplicationWindow {
    id: appWindow

    width: Constants.width
    height: Constants.height
    minimumWidth: Constants.width
    minimumHeight: Constants.height
    visible: true
    color: "transparent"
    title: qsTr("包貨小精靈")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint

    Component.onCompleted: AppDialog.host = appDialogHost

    background: Rectangle {
        color: Theme.backgroundColor
        radius: 18
        border.color: Theme.borderColor
        border.width: 1
    }

    header: WindowTitleBar {
        window: appWindow
    }

    Item {
        anchors.fill: parent

        MainScreen {
            anchors.fill: parent
        }
    }

    StatusPopup {
        id: appDialogHost
        parent: Overlay.overlay
    }
}
