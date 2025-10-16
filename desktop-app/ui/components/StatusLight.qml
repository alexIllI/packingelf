import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

Rectangle {
    id: root
    property string label: "online"
    property color indicatorColor: Theme.goodColor
    property int horizontalPadding: 5
    property int verticalPadding: 0
    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
    radius: 15

    implicitHeight: Math.max(row.implicitHeight + verticalPadding * 2, 25)
    implicitWidth: Math.max(row.implicitWidth + horizontalPadding * 2, 70)

    // Accessibility
    Accessible.role: Accessible.Indicator
    Accessible.name: label

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 5

        Rectangle {
            id: indicatorLight
            width: 10
            height: 10
            radius: 5
            color: root.indicatorColor
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            id: statusText
            text: root.label
            color: Theme.header3Color
            font.pixelSize: Constants.header3FontSize
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
