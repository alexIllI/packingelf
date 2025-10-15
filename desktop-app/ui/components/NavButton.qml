// ui/components/NavButton.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root
    property string label: ""
    property url iconSource: ""
    property bool checked: false
    signal triggered

    implicitWidth: 200
    implicitHeight: 48
    hoverEnabled: true
    padding: 10

    background: Rectangle {
        radius: 6
        color: root.checked ? Constants.sidebarColorHovered : (root.hovered ? Constants.sidebarColorHovered : "transparent")
    }

    contentItem: RowLayout {
        spacing: 10
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Image {
            visible: iconSource !== ""
            source: iconSource
            sourceSize.width: 20
            sourceSize.height: 20
            fillMode: Image.PreserveAspectFit
        }

        Text {
            text: root.label
            color: Constants.textColor
            font.pixelSize: 14
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.triggered()
    }
}
