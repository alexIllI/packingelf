pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // ========= Public API =========
    property alias text: inputField.text
    property alias placeholderText: placeholder.text
    property alias readOnly: inputField.readOnly
    property alias maximumLength: inputField.maximumLength
    property alias validator: inputField.validator
    property alias echoMode: inputField.echoMode
    property alias inputMethodHints: inputField.inputMethodHints

    signal accepted
    signal editingFinished

    // Sizing
    implicitWidth: 200
    implicitHeight: 36
    focusPolicy: Qt.StrongFocus

    // Forward focus to the inner TextInput
    onActiveFocusChanged: {
        if (root.activeFocus)
            inputField.forceActiveFocus();
    }

    // ========= Internal state =========
    readonly property bool _focused: root.activeFocus || inputField.activeFocus
    readonly property bool _hasText: inputField.text.length > 0

    // ========= Background =========
    background: Rectangle {
        id: bg
        radius: 8
        color: root._focused ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity) : Theme.surface
        border.width: 1.5
        border.color: root._focused ? Theme.primaryColor : Theme.borderColor

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
    contentItem: Item {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight

        // Placeholder text
        Text {
            id: placeholder
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            color: Theme.headerSubColor
            font.pixelSize: Constants.header3FontSize
            elide: Text.ElideRight
            visible: !root._hasText && !root._focused
            opacity: 0.6
        }

        // Actual text input
        TextInput {
            id: inputField
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.header3Color
            selectionColor: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4)
            selectedTextColor: "#ffffff"
            font.pixelSize: Constants.header3FontSize
            clip: true
            selectByMouse: true

            // Cursor styling
            cursorDelegate: Rectangle {
                id: cursor
                width: 1.5
                color: Theme.primaryColor
                visible: inputField.cursorVisible

                SequentialAnimation on opacity {
                    running: inputField.cursorVisible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1.0
                        to: 0.0
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        from: 0.0
                        to: 1.0
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            onAccepted: root.accepted()
            onEditingFinished: root.editingFinished()
        }
    }

    // ========= Accessibility =========
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholder.text
}
