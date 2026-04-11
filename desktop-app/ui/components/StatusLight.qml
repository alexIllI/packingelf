pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

Rectangle {
    id: root
    property string label: "online"
    property color indicatorColor: Theme.goodColor
    property int horizontalPadding: 10
    property int verticalPadding: 6
    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
    radius: 14
    border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.85)
    border.width: 1

    implicitHeight: Math.max(row.implicitHeight + verticalPadding * 2, 32)
    implicitWidth: Math.max(row.implicitWidth + horizontalPadding * 2, 96)

    // Accessibility
    Accessible.role: Accessible.Indicator
    Accessible.name: label

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
        spacing: 8

        Rectangle {
            id: indicatorLight
            width: 11
            height: 11
            radius: 5.5
            color: root.indicatorColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: statusText
            text: root.label
            color: Theme.header3Color
            font.pixelSize: Constants.header3FontSize
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
