import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root
    implicitWidth: 320
    implicitHeight: 160
    padding: 0
    background: Rectangle {
        radius: Constants.cardRadius
        color: Theme.cardColor
        border.color: Theme.cardBorder
        border.width: 1
    }
    contentItem: Item {
        anchors.fill: parent
    }
}
