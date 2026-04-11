pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Popup {
    id: root

    property url iconSource: ""
    property string titleText: ""
    property string messageText: ""
    property string confirmText: qsTr("確認")
    property string cancelText: qsTr("取消")
    property color accentColor: Theme.primaryColor
    property bool showCancelButton: false
    property var onConfirmAction: null
    property var onCancelAction: null

    signal acknowledged()
    signal cancelled()

    readonly property int dialogWidth: Math.max(340, Math.min(480, (parent ? parent.width : 480) - 48))

    width: dialogWidth
    implicitHeight: dialogLayout.implicitHeight + topPadding + bottomPadding
    height: implicitHeight
    modal: true
    focus: true
    padding: 28
    topPadding: 24
    bottomPadding: 24
    closePolicy: Popup.NoAutoClose

    x: Math.round(((parent ? parent.width : width) - width) / 2)
    y: Math.round(((parent ? parent.height : height) - height) / 2)

    function showDialog(options) {
        var next = options || {};
        iconSource = next.iconSource || "";
        titleText = next.titleText || "";
        messageText = next.messageText || "";
        confirmText = next.confirmText || qsTr("確認");
        cancelText = next.cancelText || qsTr("取消");
        accentColor = next.accentColor || Theme.primaryColor;
        showCancelButton = next.showCancelButton === true;
        onConfirmAction = next.onConfirmAction || null;
        onCancelAction = next.onCancelAction || null;
        open();
    }

    function runCallback(callback) {
        if (typeof callback === "function")
            callback();
    }

    function clearCallbacks() {
        onConfirmAction = null;
        onCancelAction = null;
    }

    function confirm() {
        close();
        acknowledged();
        runCallback(onConfirmAction);
        clearCallbacks();
    }

    function cancel() {
        close();
        cancelled();
        runCallback(onCancelAction);
        clearCallbacks();
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.56)
    }

    background: Rectangle {
        radius: 24
        color: Theme.sidebarColor
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.88)
    }

    contentItem: ColumnLayout {
        id: dialogLayout
        width: root.availableWidth
        spacing: 16

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.iconSource ? 108 : 0
            Layout.preferredHeight: root.iconSource ? 108 : 0
            visible: root.iconSource !== ""

            Image {
                anchors.centerIn: parent
                width: 108
                height: 108
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.titleText
            color: Theme.header1Color
            font.pixelSize: 22
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.messageText
            color: Theme.headerSubColor
            font.pixelSize: 14
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 14

            CustomButton {
                visible: root.showCancelButton
                text: root.cancelText
                Layout.preferredWidth: 128
                Layout.preferredHeight: 44
                onClicked: root.cancel()
            }

            CustomButton {
                id: confirmButton
                text: root.confirmText
                highlighted: true
                Layout.preferredWidth: 128
                Layout.preferredHeight: 44
                onClicked: root.confirm()
            }
        }
    }

    Keys.onEscapePressed: event => {
        if (root.showCancelButton)
            root.cancel();
        else {
            root.close();
            root.clearCallbacks();
        }
        event.accepted = true;
    }

    onOpened: confirmButton.forceActiveFocus()
}
