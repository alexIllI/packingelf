pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // ========= Public API =========
    property alias text: label.text
    property bool highlighted: false  // primary/accent style variant

    signal clicked()

    // Sizing
    implicitWidth: Math.max(80, label.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 36
    leftPadding: 16
    rightPadding: 16
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    // ========= Internal colors =========
    readonly property color _bgNormal: root.highlighted
        ? Theme.primaryColor
        : Theme.surface
    readonly property color _bgHovered: root.highlighted
        ? Qt.darker(Theme.primaryColor, 1.15)
        : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.checkedOpacity)
    readonly property color _bgPressed: root.highlighted
        ? Qt.darker(Theme.primaryColor, 1.3)
        : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.22)

    readonly property color _textNormal: root.highlighted ? "#000000" : Theme.header3Color
    readonly property color _borderNormal: root.highlighted ? "transparent" : Theme.borderColor
    readonly property color _borderHovered: root.highlighted ? "transparent" : Theme.primaryColor

    // ========= Background =========
    background: Rectangle {
        id: bg
        radius: 8
        color: tap.pressed ? root._bgPressed
             : root.hovered ? root._bgHovered
             : root._bgNormal
        border.width: 1.5
        border.color: root.hovered || root.activeFocus ? root._borderHovered : root._borderNormal

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.InOutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 100; easing.type: Easing.InOutCubic }
        }

        // Press scale animation
        transform: Scale {
            id: bgScale
            origin.x: bg.width / 2
            origin.y: bg.height / 2
            xScale: 1.0
            yScale: 1.0
        }
    }

    // ========= Content =========
    contentItem: Text {
        id: label
        color: root._textNormal
        font.pixelSize: Constants.header3FontSize
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.InOutCubic }
        }
    }

    // ========= Press bounce animation =========
    SequentialAnimation {
        id: pressAnim
        NumberAnimation {
            target: bgScale
            properties: "xScale,yScale"
            to: 0.94
            duration: 60
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: bgScale
            properties: "xScale,yScale"
            to: 1.0
            duration: 120
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }
    }

    // ========= Click handling =========
    TapHandler {
        id: tap
        onTapped: {
            pressAnim.start();
            root.clicked();
        }
    }

    Keys.onReturnPressed: {
        pressAnim.start();
        root.clicked();
    }
    Keys.onSpacePressed: {
        pressAnim.start();
        root.clicked();
    }

    // ========= Accessibility =========
    Accessible.role: Accessible.Button
    Accessible.name: label.text
}
