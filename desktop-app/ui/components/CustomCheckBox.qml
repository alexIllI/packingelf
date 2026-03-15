pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // ========= Public API =========
    property bool checked: false
    property alias text: label.text
    property int boxSize: 18
    property int circleSize: 36

    signal toggled

    implicitWidth: hitArea.width + (label.visible ? root.spacing + label.implicitWidth : 0)
    implicitHeight: Math.max(root.circleSize, label.implicitHeight)
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    spacing: 8

    // ========= Toggle on click =========
    TapHandler {
        id: tap
        onTapped: {
            root.checked = !root.checked;
            root.toggled();
            bounceAnim.start();
        }
    }

    Keys.onSpacePressed: {
        root.checked = !root.checked;
        root.toggled();
        bounceAnim.start();
    }

    // ========= Visual content =========
    contentItem: RowLayout {
        spacing: root.spacing

        // Container for the circle + checkbox, centered
        Item {
            id: hitArea
            implicitWidth: root.circleSize
            implicitHeight: root.circleSize
            Layout.alignment: Qt.AlignVCenter

            // Hover circle — appears gradually behind the checkbox
            Rectangle {
                id: hoverCircle
                anchors.centerIn: parent
                width: root.circleSize
                height: root.circleSize
                radius: root.circleSize / 2
                color: root.checked ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.checkedOpacity) : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                opacity: root.hovered ? 1.0 : 0.0
                scale: root.hovered ? 1.0 : 0.6

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // The actual checkbox square
            Rectangle {
                id: box
                anchors.centerIn: parent
                width: root.boxSize
                height: root.boxSize
                radius: 4
                color: root.checked ? Theme.primaryColor : "transparent"
                border.color: root.checked ? Theme.primaryColor : Theme.borderColor
                border.width: root.checked ? 0 : 1.5

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                // Checkmark drawn with Canvas
                Canvas {
                    id: checkmark
                    anchors.centerIn: parent
                    width: root.boxSize - 4
                    height: root.boxSize - 4
                    visible: root.checked
                    opacity: root.checked ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 2.2;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.beginPath();
                        // Checkmark path: proportional to canvas size
                        var w = width;
                        var h = height;
                        ctx.moveTo(w * 0.18, h * 0.50);
                        ctx.lineTo(w * 0.42, h * 0.75);
                        ctx.lineTo(w * 0.85, h * 0.25);
                        ctx.stroke();
                    }
                }
            }

            // Bounce animation on press
            transform: Scale {
                id: scaleTransform
                origin.x: hitArea.width / 2
                origin.y: hitArea.height / 2
                xScale: 1.0
                yScale: 1.0
            }

            SequentialAnimation {
                id: bounceAnim
                NumberAnimation {
                    target: scaleTransform
                    properties: "xScale,yScale"
                    to: 0.78
                    duration: 80
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    target: scaleTransform
                    properties: "xScale,yScale"
                    to: 1.08
                    duration: 120
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.0
                }
                NumberAnimation {
                    target: scaleTransform
                    properties: "xScale,yScale"
                    to: 1.0
                    duration: 80
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Label text
        Text {
            id: label
            visible: label.text.length > 0
            color: Theme.header3Color
            font.pixelSize: Constants.header3FontSize
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
        }
    }

    // No background needed
    background: null

    // ========= Accessibility =========
    Accessible.role: Accessible.CheckBox
    Accessible.name: label.text
    Accessible.checked: root.checked
}
