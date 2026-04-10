pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // ========= Public API =========
    property int value: 0
    property int from: 0
    property int to: 99
    property int stepSize: 1
    property string valueText: root.value.toString()

    signal valueModified

    // Sizing
    implicitWidth: 250
    implicitHeight: 80
    focusPolicy: Qt.ClickFocus

    function _increment() {
        if (root.value + root.stepSize <= root.to) {
            root.value += root.stepSize;
            root.valueModified();
        }
    }
    function _decrement() {
        if (root.value - root.stepSize >= root.from) {
            root.value -= root.stepSize;
            root.valueModified();
        }
    }

    // ========= Background =========
    background: Rectangle {
        id: bg
        radius: 8
        color: Theme.surface
        border.width: 1.5
        border.color: Theme.borderColor

        Behavior on border.color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutCubic
            }
        }
    }

    // ========= Content =========
    contentItem: RowLayout {
        spacing: 0

        // Decrement button
        Rectangle {
            id: decrementBtn
            Layout.preferredWidth: 50
            Layout.fillHeight: true
            color: decMouse.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.15) : decMouse.containsMouse ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08) : "transparent"
            radius: 6

            Behavior on color {
                ColorAnimation {
                    duration: 80
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: "−"
                color: root.value <= root.from ? Theme.borderColor : Theme.primaryColor
                font.pixelSize: 24
                font.bold: true

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: decMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._decrement()

                // Auto-repeat on press-and-hold
                onPressAndHold: repeatDecTimer.start()
                onReleased: repeatDecTimer.stop()
                onExited: repeatDecTimer.stop()
            }

            Timer {
                id: repeatDecTimer
                interval: 100
                repeat: true
                onTriggered: root._decrement()
            }
        }

        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.5)
        }

        // Value input
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                text: root.valueText
                color: Theme.header3Color
                font.pixelSize: 32
                font.bold: true
            }
        }

        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.5)
        }

        // Increment button
        Rectangle {
            id: incrementBtn
            Layout.preferredWidth: 50
            Layout.fillHeight: true
            color: incMouse.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.15) : incMouse.containsMouse ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08) : "transparent"
            radius: 6

            Behavior on color {
                ColorAnimation {
                    duration: 80
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: root.value >= root.to ? Theme.borderColor : Theme.primaryColor
                font.pixelSize: 24
                font.bold: true

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: incMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._increment()

                onPressAndHold: repeatIncTimer.start()
                onReleased: repeatIncTimer.stop()
                onExited: repeatIncTimer.stop()
            }

            Timer {
                id: repeatIncTimer
                interval: 100
                repeat: true
                onTriggered: root._increment()
            }
        }
    }

    // ========= Keyboard =========
    Keys.onUpPressed: root._increment()
    Keys.onDownPressed: root._decrement()

    // ========= Accessibility =========
    Accessible.role: Accessible.SpinBox
    Accessible.name: root.valueText
}
