import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

RowLayout {
    property string label: ""
    property color color: Theme.goodColor
    spacing: 5
    anchors.leftMargin: 5
    anchors.rightMargin: 5

    Rectangle {
        width: 10
        height: 10
        radius: 5
        color: parent.color
    }
    Text {
        text: parent.label
        color: Theme.header3Color
        font.pixelSize: Constants.header3FontSize
    }
}
