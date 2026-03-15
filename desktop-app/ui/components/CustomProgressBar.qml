pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // ========= Public API =========
    property real value: 0.0       // 0.0 – 1.0
    property real from: 0.0
    property real to: 1.0
    property bool indeterminate: false

    // Sizing
    implicitWidth: 200
    implicitHeight: 10

    // ========= Background (track) =========
    background: Rectangle {
        id: track
        radius: root.height / 2
        color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.4)
    }

    // ========= Content (fill bar) =========
    contentItem: Item {
        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.indeterminate
                ? parent.width * 0.35
                : parent.width * Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
            radius: root.height / 2

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.5)
                }
                GradientStop {
                    position: 1.0
                    color: Theme.primaryColor
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Subtle glow overlay on the fill
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 0

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(parent.width, 20)
                    height: parent.height
                    radius: parent.radius
                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.3)
                    visible: !root.indeterminate && fill.width > 4
                }
            }

            // Indeterminate sliding animation
            SequentialAnimation on x {
                running: root.indeterminate
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: root.width * 0.65
                    duration: 1200
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    from: root.width * 0.65
                    to: 0
                    duration: 1200
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    // ========= Accessibility =========
    Accessible.role: Accessible.ProgressBar
    Accessible.name: Math.round((root.value - root.from) / (root.to - root.from) * 100) + "%"
}
