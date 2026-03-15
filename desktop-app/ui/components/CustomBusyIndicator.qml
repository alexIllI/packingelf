pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import PackingElf 1.0

Item {
    id: root

    // ========= Public API =========
    property bool running: true

    // Sizing
    implicitWidth: 30
    implicitHeight: 30

    visible: root.running
    opacity: root.running ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
    }

    // ========= Spinning dots =========
    Item {
        id: spinner
        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width

        RotationAnimation on rotation {
            running: root.running
            from: 0
            to: 360
            duration: 1200
            loops: Animation.Infinite
        }

        Repeater {
            model: 8

            Rectangle {
                required property int index

                readonly property real angle: index * (360 / 8) * (Math.PI / 180)
                readonly property real dotRadius: spinner.width * 0.38

                x: spinner.width / 2 + dotRadius * Math.cos(angle) - width / 2
                y: spinner.height / 2 + dotRadius * Math.sin(angle) - height / 2
                width: spinner.width * 0.14
                height: width
                radius: width / 2

                color: Theme.primaryColor
                opacity: {
                    // Dots fade from full opacity to low, creating a trailing effect
                    var base = 1.0 - (index / 8) * 0.75;
                    return Math.max(0.15, base);
                }

                scale: {
                    // Leading dots are slightly larger
                    var base = 1.0 - (index / 8) * 0.4;
                    return Math.max(0.6, base);
                }
            }
        }
    }

    // ========= Accessibility =========
    Accessible.role: Accessible.Animation
    Accessible.name: qsTr("Loading")
}
