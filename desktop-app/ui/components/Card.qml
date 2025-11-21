pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import PackingElf 1.0

Control {
    id: root
    default property alias content: container.data
    property real cardWidth: 100
    property real cardHeight: 100

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    padding: 10

    background: Rectangle {
        radius: 15
        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
        border.color: Theme.borderColor
        border.width: 1
    }
    contentItem: Item {
        id: container
    }
}
