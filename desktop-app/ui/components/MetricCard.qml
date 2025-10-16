/*
This componet is for home page and includes:
- Title: header2
- Value: header1, bold
- Unit: header3
- icon: provide only name to icon
*/

// MetricCard.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // Public API
    property string title: qsTr("")
    property real displayValue: 0
    property int targetValue: 0
    property string unit: qsTr("件")
    property url iconSource: ""
    property int iconSize: 24

    // Sizing
    implicitWidth: 200
    implicitHeight: 90
    padding: 0

    // Only animate after init
    property bool _ready: false
    Component.onCompleted: {
        displayValue = targetValue; // set initial without animation
        _ready = true;
    }

    // Smooth numeric tween whenever displayValue changes
    Behavior on displayValue {
        enabled: root._ready
        NumberAnimation {
            // snappy but scales a bit with delta
            duration: Math.min(900, 200 + Math.abs(root.targetValue - root.displayValue) * 10)
            easing.type: Easing.OutCubic
        }
    }

    // Kick animation + pulse when targetValue changes
    onTargetValueChanged: {
        displayValue = targetValue; // triggers Behavior (when _ready)
        pulseAnim.restart();
    }

    // Subtle scale pulse on update
    SequentialAnimation {
        id: pulseAnim
        PropertyAnimation {
            target: value
            property: "scale"
            to: 1.06
            duration: 90
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: value
            property: "scale"
            to: 1.00
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    // Accessibility
    Accessible.role: Accessible.Pane
    Accessible.name: title

    // Content (don’t anchor; Control manages contentItem)
    contentItem: RowLayout {
        id: rootLayout
        spacing: 10
        Layout.fillWidth: true
        ColumnLayout {
            id: textColumn
            spacing: 10
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Text {
                id: titleText
                text: root.title
                color: Theme.header2Color
                font.pixelSize: Constants.header2FontSize
                font.bold: false
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }

            Text {
                id: value
                text: Math.round(root.displayValue).toString()
                color: Theme.header1Color
                font.pixelSize: Constants.header1FontSize
                font.bold: true
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                // nice subtle ramp when value color changes (optional)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            Text {
                id: unitText
                text: root.unit
                color: Theme.header3Color
                font.pixelSize: Constants.header3FontSize
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }
        }

        Image {
            id: icon
            visible: root.iconSource !== ""
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            Layout.alignment: Qt.AlignTop
        }
    }
}
