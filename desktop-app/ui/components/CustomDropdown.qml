// CustomDropdown.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0 // Theme, Constants

Control {
    id: root
    implicitWidth: 160
    implicitHeight: 40
    focusPolicy: Qt.TabFocus
    hoverEnabled: true

    // ========= Public API =========
    property var model: ["test1", "test2", "test3"]
    property string textRole: "text"
    property string valueRole: "value"

    property int currentIndex: -1
    readonly property string currentText: root._textAt(currentIndex)
    readonly property var currentValue: root._valueAt(currentIndex)

    property string placeholderText: qsTr("Select an item")
    property int maxVisibleRows: 6
    property int delegateHeight: 34

    signal activated(int index, var value, string text)

    // ========= Helpers =========
    function _count() {
        if (model === null || model === undefined)
            return 0;
        if (Array.isArray(model))
            return model.length;
        if (typeof model.count === "number")
            return model.count; // ListModel / QAbstractItemModel
        return 0;
    }
    function _textAt(i) {
        if (i < 0 || i >= _count())
            return "";
        if (Array.isArray(model))
            return String(model[i]);
        const it = model.get ? model.get(i) : model[i];
        if (it === undefined || it === null)
            return "";
        return (it[textRole] !== undefined ? it[textRole] : (it.display ?? it.name ?? it.title ?? ""));
    }
    function _valueAt(i) {
        if (i < 0 || i >= _count())
            return undefined;
        if (Array.isArray(model))
            return model[i];
        const it = model.get ? model.get(i) : model[i];
        if (it === undefined || it === null)
            return undefined;
        return (it[valueRole] !== undefined ? it[valueRole] : (it[textRole] !== undefined ? it[textRole] : it));
    }

    // ========= Interaction =========
    TapHandler {
        id: opener
        acceptedButtons: Qt.LeftButton
        // passive; just open the popup
        onTapped: popup.open()
    }

    Keys.onDownPressed: popup.open()
    Keys.onUpPressed: popup.open()
    Keys.onEscapePressed: popup.close()
    Keys.onEnterPressed: if (popup.opened && list.currentIndex >= 0)
        delegateSelect(list.currentIndex)
    Keys.onReturnPressed: if (popup.opened && list.currentIndex >= 0)
        delegateSelect(list.currentIndex)

    function delegateSelect(i) {
        // capture before change if you prefer:
        const v = _valueAt(i);
        const t = _textAt(i);
        currentIndex = i;
        popup.close();
        activated(i, v, t);
    }

    // ========= Visuals =========
    // Colors from Theme; tweak to your palette
    readonly property color bgColor: !enabled ? Theme.surfaceDisabled : hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08) : Theme.surface
    readonly property color borderColor: focus ? Theme.primaryColor : Theme.borderColor
    readonly property color textColor: (currentIndex >= 0) ? Theme.header3Color : Theme.headerSubColor

    background: Rectangle {
        radius: 6
        color: root.bgColor
        border.color: root.borderColor
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    contentItem: RowLayout {
        spacing: 8
        anchors.fill: parent
        anchors.margins: 10

        Text {
            id: label
            text: (root.currentIndex >= 0) ? root.currentText : root.placeholderText
            color: root.textColor
            font.pixelSize: Constants.header3FontSize
            elide: Text.ElideRight
            Layout.fillWidth: true
            verticalAlignment: Text.AlignVCenter
        }

        // caret icon (you can swap to your own asset)
        Canvas {
            id: caret
            width: 12
            height: 12
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.header3Color;
                ctx.beginPath();
                ctx.moveTo(1, 4);
                ctx.lineTo(6, 9);
                ctx.lineTo(11, 4);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // ========= Popup =========
    Popup {
        id: popup
        y: root.height + 4
        x: 0
        width: root.width
        padding: 4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        modal: false
        focus: true
        background: Rectangle {
            radius: 6
            color: Theme.dropdownBgColor
            border.color: Theme.borderColor
            border.width: 1
        }

        // cap height to maxVisibleRows
        implicitHeight: Math.min(root.maxVisibleRows, root._count()) * root.delegateHeight + 8

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            model: root.model
            currentIndex: Math.max(0, root.currentIndex)
            keyNavigationWraps: true
            highlightMoveDuration: 100
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: ItemDelegate {
                id: del
                required property var model
                required property int index

                width: ListView.view.width
                height: root.delegateHeight
                text: Array.isArray(root.model) ? String(model) : (model[root.textRole] ?? model.display ?? model.name ?? model.title ?? "")
                highlighted: ListView.isCurrentItem
                onClicked: root.delegateSelect(index)
                // theming
                background: Rectangle {
                    radius: 4
                    color: del.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.10) : del.hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06) : "transparent"
                }
                contentItem: Text {
                    text: del.text
                    color: Theme.header3Color
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                    rightPadding: 8
                    font.pixelSize: Constants.header3FontSize
                }
            }
        }

        // flip above if near window bottom (optional)
        onAboutToShow: {
            // crude but effective: if the popup would run off-screen, show above
            const view = root.Window ? root.Window.window : null;
            if (view) {
                const global = root.mapToItem(view.contentItem, 0, root.height);
                const spaceBelow = (view.height - global.y);
                const targetH = implicitHeight;
                y = (spaceBelow >= targetH + 8) ? (root.height + 4) : (-targetH - 4);
            }
        }
    }

    // ========= Accessibility =========
    Accessible.role: Accessible.ComboBox
    Accessible.name: currentIndex >= 0 ? currentText : placeholderText
}
