pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    property string title: ""
    property real displayValue: 0
    property int targetValue: 0
    property string unit: qsTr("筆")
    property url iconSource: ""
    property int iconSize: 22

    implicitWidth: 196
    implicitHeight: 102
    padding: 14

    property bool _ready: false
    Component.onCompleted: {
        displayValue = targetValue;
        _ready = true;
    }

    Behavior on displayValue {
        enabled: root._ready
        NumberAnimation {
            duration: Math.min(700, 180 + Math.abs(root.targetValue - root.displayValue) * 9)
            easing.type: Easing.OutCubic
        }
    }

    onTargetValueChanged: {
        displayValue = targetValue;
        pulseAnim.restart();
    }

    SequentialAnimation {
        id: pulseAnim
        PropertyAnimation {
            target: valueText
            property: "scale"
            to: 1.03
            duration: 80
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: valueText
            property: "scale"
            to: 1.0
            duration: 110
            easing.type: Easing.OutCubic
        }
    }

    Accessible.role: Accessible.Pane
    Accessible.name: title

    background: Rectangle {
        radius: 18
        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08)
        border.color: Theme.borderColor
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.title
                color: Theme.header2Color
                font.pixelSize: Constants.header2FontSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.12)
                border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.85)

                Image {
                    anchors.centerIn: parent
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: root.iconSize
                    sourceSize.height: root.iconSize
                    width: root.iconSize
                    height: root.iconSize
                }
            }
        }

        RowLayout {
            spacing: 6

            Text {
                id: valueText
                text: Math.round(root.displayValue).toString()
                color: Theme.header1Color
                font.pixelSize: 28
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.unit
                color: Theme.headerSubColor
                font.pixelSize: Constants.header3FontSize
                Layout.alignment: Qt.AlignBottom
                bottomPadding: 3
            }
        }
    }
}
