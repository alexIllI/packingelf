pragma Singleton

import QtQuick
import PackingElf 1.0

QtObject {
    id: root

    property var host: null

    readonly property url okIcon: Qt.resolvedUrl("assets/images/ok.png")
    readonly property url infoIcon: Qt.resolvedUrl("assets/images/info.png")
    readonly property url warningIcon: Qt.resolvedUrl("assets/images/warning.png")
    readonly property url questionIcon: Qt.resolvedUrl("assets/images/question.png")
    readonly property url errorIcon: Qt.resolvedUrl("assets/images/error.png")

    function showDialog(options) {
        if (!host) {
            console.warn("[AppDialog] Dialog host is not ready.");
            return;
        }

        host.showDialog(options || {});
    }

    function showInfo(titleText, messageText, options) {
        var next = options || {};
        next.titleText = titleText;
        next.messageText = messageText;
        next.iconSource = next.iconSource || infoIcon;
        next.accentColor = next.accentColor || Theme.infoColor;
        next.showCancelButton = false;
        showDialog(next);
    }

    function showSuccess(titleText, messageText, options) {
        var next = options || {};
        next.titleText = titleText;
        next.messageText = messageText;
        next.iconSource = next.iconSource || okIcon;
        next.accentColor = next.accentColor || Theme.goodColor;
        next.showCancelButton = false;
        showDialog(next);
    }

    function showWarning(titleText, messageText, options) {
        var next = options || {};
        next.titleText = titleText;
        next.messageText = messageText;
        next.iconSource = next.iconSource || warningIcon;
        next.accentColor = next.accentColor || Theme.warningColor;
        next.showCancelButton = false;
        showDialog(next);
    }

    function showError(titleText, messageText, options) {
        var next = options || {};
        next.titleText = titleText;
        next.messageText = messageText;
        next.iconSource = next.iconSource || errorIcon;
        next.accentColor = next.accentColor || Theme.errorColor;
        next.showCancelButton = false;
        showDialog(next);
    }

    function confirm(options) {
        var next = options || {};
        if (!next.confirmText)
            next.confirmText = qsTr("確認");
        if (!next.cancelText)
            next.cancelText = qsTr("取消");
        next.showCancelButton = true;
        next.iconSource = next.iconSource || questionIcon;
        next.accentColor = next.accentColor || Theme.questionColor;
        showDialog(next);
    }
}
