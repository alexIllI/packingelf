import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: settingView
    anchors.fill: parent
    title: qsTr("設定")
    subtitle: qsTr("管理貨單前綴、myacg 帳號與登入方式")

    readonly property int defaultPrefix: 24
    readonly property int minPrefix: 2
    readonly property int maxPrefix: 997
    readonly property int savedPrefix: AppSettings ? AppSettings.orderPrefix : defaultPrefix
    readonly property bool hasUnsavedPrefixChanges: prefixSpinBox.value !== savedPrefix
    readonly property var tabLabels: [qsTr("貨單前綴"), qsTr("myacg 帳號")]
    readonly property bool autoLoginSelected: AppSettings ? AppSettings.autoLoginEnabled : false

    property int currentTabIndex: 0
    property string activeEditorAccountName: ""
    property string editingOriginalAccountName: ""
    property string editingAccountName: ""
    property string editingLoginAccount: ""
    property string editingPassword: ""
    property string accountNotice: ""
    property string pendingLoginTestName: ""

    function formatPrefix(prefix) { return Number(prefix).toString().padStart(3, "0"); }
    function previewPrefixAt(offset) { return formatPrefix(prefixSpinBox.value + offset); }
    function accountNames() { return AppSettings ? AppSettings.myAcgAccountNames : []; }
    function currentAutoLoginIndex() {
        var names = accountNames();
        var selected = AppSettings ? AppSettings.selectedMyAcgAccountName : "";
        for (var i = 0; i < names.length; ++i) {
            if (String(names[i]) === selected)
                return i;
        }
        return -1;
    }
    function syncAutoLoginDropdown() {
        if (autoLoginAccountDropdown)
            autoLoginAccountDropdown.currentIndex = currentAutoLoginIndex();
    }
    function prepareNewAccount() {
        activeEditorAccountName = "";
        editingOriginalAccountName = "";
        editingAccountName = "";
        editingLoginAccount = "";
        editingPassword = "";
        accountNotice = "";
    }
    function selectedStoredAccount() {
        return activeEditorAccountName.length > 0 && AppSettings
                ? AppSettings.myAcgAccount(activeEditorAccountName)
                : null;
    }
    function selectStoredAccount(name) {
        activeEditorAccountName = String(name || "");
    }
    function loadSelectedAccountIntoForm() {
        var details = selectedStoredAccount();
        if (!details || !details.name) {
            accountNotice = qsTr("請先選擇要操作的帳號。");
            return;
        }
        editingOriginalAccountName = String(details.name);
        editingAccountName = String(details.name);
        editingLoginAccount = String(details.account || "");
        editingPassword = String(details.password || "");
        accountNotice = qsTr("已將選取帳號帶入表單。");
    }
    function selectAccountForEditing(name) {
        var details = AppSettings ? AppSettings.myAcgAccount(name) : null;
        if (!details || !details.name) {
            prepareNewAccount();
            return;
        }
        activeEditorAccountName = String(details.name);
        editingOriginalAccountName = String(details.name);
        editingAccountName = String(details.name);
        editingLoginAccount = String(details.account || "");
        editingPassword = String(details.password || "");
        accountNotice = "";
    }
    function validateAccountForm() {
        if (editingAccountName.trim().length === 0) {
            accountNotice = qsTr("請輸入帳號名稱。");
            return false;
        }
        if (editingLoginAccount.trim().length === 0) {
            accountNotice = qsTr("請輸入 myacg 登入帳號。");
            return false;
        }
        if (editingPassword.length === 0) {
            accountNotice = qsTr("請輸入密碼。");
            return false;
        }
        return true;
    }
    function saveMyAcgAccount() {
        if (!validateAccountForm())
            return;
        var trimmedName = editingAccountName.trim();
        if (editingOriginalAccountName.length > 0
                && editingOriginalAccountName !== trimmedName
                && AppSettings.hasMyAcgAccount(trimmedName)) {
            accountNotice = qsTr("這個帳號名稱已存在，請改用其他名稱。");
            return;
        }
        if (!AppSettings.addOrUpdateMyAcgAccount(trimmedName, editingLoginAccount.trim(), editingPassword)) {
            accountNotice = qsTr("儲存帳號失敗，請確認欄位內容。");
            return;
        }
        if (editingOriginalAccountName.length > 0 && editingOriginalAccountName !== trimmedName)
            AppSettings.deleteMyAcgAccount(editingOriginalAccountName);

        editingOriginalAccountName = trimmedName;
        activeEditorAccountName = trimmedName;
        AppSettings.setSelectedMyAcgAccountName(trimmedName);
        accountNotice = qsTr("帳號已儲存。");
        syncAutoLoginDropdown();
    }
    function requestDeleteSelectedAccount() {
        if (activeEditorAccountName.length === 0) {
            accountNotice = qsTr("目前沒有可刪除的帳號。");
            return;
        }
        AppDialog.confirm({
            titleText: qsTr("刪除 myacg 帳號"),
            messageText: qsTr("確定要刪除帳號 %1 嗎？").arg(activeEditorAccountName),
            confirmText: qsTr("刪除"),
            cancelText: qsTr("取消"),
            iconSource: AppDialog.warningIcon,
            accentColor: Theme.warningColor,
            onConfirmAction: function() {
                if (!AppSettings.deleteMyAcgAccount(settingView.activeEditorAccountName)) {
                    settingView.accountNotice = qsTr("刪除帳號失敗。");
                    return;
                }
                settingView.accountNotice = qsTr("帳號已刪除。");
                if (AppSettings.myAcgAccountNames.length > 0) {
                    settingView.selectStoredAccount(AppSettings.selectedMyAcgAccountName || AppSettings.myAcgAccountNames[0]);
                } else {
                    settingView.prepareNewAccount();
                }
                settingView.syncAutoLoginDropdown();
            }
        });
    }
    function testSelectedAccountLogin() {
        var details = selectedStoredAccount();
        if (!details || !details.name) {
            accountNotice = qsTr("請先選擇要測試的帳號。");
            return;
        }
        pendingLoginTestName = String(details.name);
        accountNotice = qsTr("正在測試登入，請稍候...");
        ScraperSvc.restartBrowserWithCredentials(
                    String(details.name),
                    String(details.account || ""),
                    String(details.password || ""));
    }

    Component.onCompleted: {
        prefixSpinBox.value = savedPrefix;
        var names = accountNames();
        if (names.length > 0)
            selectStoredAccount(AppSettings.selectedMyAcgAccountName || names[0]);
        else
            prepareNewAccount();
        syncAutoLoginDropdown();
    }

    Connections {
        target: AppSettings

        function onOrderPrefixChanged() {
            prefixSpinBox.value = AppSettings.orderPrefix;
        }

        function onMyAcgAccountsChanged() {
            var names = settingView.accountNames();
            if (settingView.activeEditorAccountName.length > 0
                    && AppSettings.hasMyAcgAccount(settingView.activeEditorAccountName)) {
                settingView.selectStoredAccount(settingView.activeEditorAccountName);
            } else if (names.length > 0) {
                settingView.selectStoredAccount(AppSettings.selectedMyAcgAccountName || names[0]);
            } else {
                settingView.prepareNewAccount();
            }
            settingView.syncAutoLoginDropdown();
        }

        function onAutoLoginSettingsChanged() {
            settingView.syncAutoLoginDropdown();
        }
    }

    Connections {
        target: ScraperSvc

        function onBrowserReady() {
            if (settingView.pendingLoginTestName.length === 0)
                return;
            AppDialog.showSuccess(
                        qsTr("登入成功"),
                        qsTr("帳號 %1 已成功登入 myacg。").arg(settingView.pendingLoginTestName));
            settingView.accountNotice = qsTr("測試登入成功。");
            settingView.pendingLoginTestName = "";
        }

        function onBrowserDied(reason) {
            if (settingView.pendingLoginTestName.length === 0)
                return;
            AppDialog.showError(
                        qsTr("登入失敗"),
                        reason && reason.length > 0 ? reason : qsTr("無法使用這組帳號登入 myacg。"));
            settingView.accountNotice = qsTr("測試登入失敗。");
            settingView.pendingLoginTestName = "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 18

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            Rectangle {
                anchors.centerIn: parent
                width: 360
                height: 56
                radius: 20
                color: Theme.sidebarColor
                border.color: Theme.borderColor

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Repeater {
                        model: settingView.tabLabels

                        delegate: Rectangle {
                            required property int index
                            required property string modelData

                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: 15
                            color: settingView.currentTabIndex === index
                                   ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.16)
                                   : "transparent"
                            border.width: settingView.currentTabIndex === index ? 1 : 0
                            border.color: settingView.currentTabIndex === index ? Theme.primaryColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: settingView.currentTabIndex === index ? Theme.header1Color : Theme.headerSubColor
                                font.pixelSize: Constants.header2FontSize
                                font.bold: settingView.currentTabIndex === index
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingView.currentTabIndex = index
                            }
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: settingView.currentTabIndex

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: prefixContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: prefixContent
                        width: parent.width
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: prefixCardContent.implicitHeight + 44
                            radius: 20
                            color: Theme.sidebarColor
                            border.color: Theme.borderColor

                            ColumnLayout {
                                id: prefixCardContent
                                anchors.fill: parent
                                anchors.margins: 22
                                spacing: 20

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: qsTr("貨單前綴設定")
                                            color: Theme.header2Color
                                            font.pixelSize: Constants.header2FontSize
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            text: qsTr("列印頁會顯示目前前綴前後各兩個選項，並自動把中間值當作預設。")
                                        }
                                    }

                                    Rectangle {
                                        radius: 13
                                        color: settingView.hasUnsavedPrefixChanges
                                               ? Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.14)
                                               : Qt.rgba(Theme.goodColor.r, Theme.goodColor.g, Theme.goodColor.b, 0.14)
                                        border.color: settingView.hasUnsavedPrefixChanges ? Theme.warningColor : Theme.goodColor
                                        Layout.preferredWidth: 88
                                        Layout.preferredHeight: 32

                                        Text {
                                            anchors.centerIn: parent
                                            text: settingView.hasUnsavedPrefixChanges ? qsTr("未儲存") : qsTr("已儲存")
                                            color: Theme.header1Color
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: width >= 760 ? 2 : 1
                                    columnSpacing: 16
                                    rowSpacing: 16

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 132
                                        radius: 18
                                        color: Theme.surface
                                        border.color: Theme.borderColor

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 10

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: qsTr("目前儲存")
                                                color: Theme.headerSubColor
                                                font.pixelSize: Constants.header3FontSize
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: formatPrefix(savedPrefix)
                                                color: Theme.header1Color
                                                font.pixelSize: 32
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 132
                                        radius: 18
                                        color: Theme.surface
                                        border.color: Theme.borderColor

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 12

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: qsTr("調整預設前綴")
                                                color: Theme.headerSubColor
                                                font.pixelSize: Constants.header3FontSize
                                            }

                                            CustomSpinBox {
                                                id: prefixSpinBox
                                                value: settingView.defaultPrefix
                                                valueText: settingView.formatPrefix(value)
                                                from: settingView.minPrefix
                                                to: settingView.maxPrefix
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: qsTr("列印頁預覽")
                                        color: Theme.header2Color
                                        font.pixelSize: Constants.header2FontSize
                                        font.bold: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Repeater {
                                            model: 5

                                            delegate: Rectangle {
                                                required property int index
                                                readonly property bool isSelected: index === 2

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 92
                                                radius: 16
                                                color: isSelected
                                                       ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.18)
                                                       : Theme.surface
                                                border.width: isSelected ? 2 : 1
                                                border.color: isSelected ? Theme.primaryColor : Theme.borderColor

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: settingView.previewPrefixAt(index - 2)
                                                        color: Theme.header1Color
                                                        font.pixelSize: Constants.header2FontSize
                                                        font.bold: true
                                                    }

                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: isSelected ? qsTr("預設值") : qsTr("選項")
                                                        color: Theme.headerSubColor
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: configPathText.implicitHeight + 28
                                    radius: 16
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08)
                                    border.color: Theme.borderColor

                                    Text {
                                        id: configPathText
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        wrapMode: Text.WordWrap
                                        text: qsTr("設定檔位置：") + (AppSettings ? AppSettings.configFilePath : "")
                                        color: Theme.headerSubColor
                                        font.pixelSize: 12
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Item { Layout.fillWidth: true }

                                    CustomButton {
                                        text: qsTr("恢復預設")
                                        onClicked: prefixSpinBox.value = settingView.defaultPrefix
                                    }

                                    CustomButton {
                                        text: qsTr("取消")
                                        enabled: settingView.hasUnsavedPrefixChanges
                                        onClicked: prefixSpinBox.value = settingView.savedPrefix
                                    }

                                    CustomButton {
                                        text: qsTr("儲存")
                                        highlighted: true
                                        enabled: settingView.hasUnsavedPrefixChanges
                                        onClicked: AppSettings.setOrderPrefix(prefixSpinBox.value)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: accountContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: accountContent
                        width: parent.width
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: loginModeCardContent.implicitHeight + 44
                            radius: 20
                            color: Theme.sidebarColor
                            border.color: Theme.borderColor

                            ColumnLayout {
                                id: loginModeCardContent
                                anchors.fill: parent
                                anchors.margins: 22
                                spacing: 16

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: qsTr("登入方式")
                                            color: Theme.header2Color
                                            font.pixelSize: Constants.header2FontSize
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            text: qsTr("先選擇登入模式。若選擇自動登入但沒有可用帳號，app 啟動時仍會安全退回手動登入。")
                                        }
                                    }

                                    Rectangle {
                                        radius: 13
                                        color: settingView.autoLoginSelected
                                               ? Qt.rgba(Theme.infoColor.r, Theme.infoColor.g, Theme.infoColor.b, 0.14)
                                               : Qt.rgba(Theme.headerSubColor.r, Theme.headerSubColor.g, Theme.headerSubColor.b, 0.08)
                                        border.color: settingView.autoLoginSelected ? Theme.infoColor : Theme.borderColor
                                        Layout.preferredWidth: 108
                                        Layout.preferredHeight: 32

                                        Text {
                                            anchors.centerIn: parent
                                            text: settingView.autoLoginSelected ? qsTr("自動登入") : qsTr("手動登入")
                                            color: Theme.header1Color
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 14

                                    Rectangle {
                                        Layout.preferredWidth: 220
                                        Layout.preferredHeight: 50
                                        radius: 16
                                        color: Theme.surface
                                        border.color: Theme.borderColor

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            spacing: 5

                                            Repeater {
                                                model: [
                                                    { label: qsTr("手動登入"), auto: false },
                                                    { label: qsTr("自動登入"), auto: true }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    width: (parent.width - 5) / 2
                                                    height: parent.height
                                                    radius: 13
                                                    color: settingView.autoLoginSelected === Boolean(modelData.auto)
                                                           ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.18)
                                                           : "transparent"
                                                    border.width: settingView.autoLoginSelected === Boolean(modelData.auto) ? 1 : 0
                                                    border.color: settingView.autoLoginSelected === Boolean(modelData.auto)
                                                                  ? Theme.primaryColor
                                                                  : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        color: settingView.autoLoginSelected === Boolean(modelData.auto)
                                                               ? Theme.header1Color
                                                               : Theme.headerSubColor
                                                        font.pixelSize: Constants.header3FontSize
                                                        font.bold: settingView.autoLoginSelected === Boolean(modelData.auto)
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: AppSettings.setAutoLoginEnabled(Boolean(parent.modelData.auto))
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    CustomDropdown {
                                        id: autoLoginAccountDropdown
                                        Layout.fillWidth: true
                                        model: AppSettings ? AppSettings.myAcgAccountNames : []
                                        placeholderText: qsTr("請選擇自動登入帳號")
                                        enabled: settingView.autoLoginSelected && AppSettings && AppSettings.myAcgAccountNames.length > 0

                                        onActivated: function(index, value, text) {
                                            AppSettings.setSelectedMyAcgAccountName(text);
                                            if (!settingView.autoLoginSelected)
                                                AppSettings.setAutoLoginEnabled(true);
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: Theme.headerSubColor
                                    font.pixelSize: 12
                                    text: settingView.autoLoginSelected
                                          ? (AppSettings && AppSettings.myAcgAccountNames.length > 0
                                             ? qsTr("已啟用自動登入，請確認預設帳號正確。")
                                             : qsTr("目前為自動登入模式，但尚未建立帳號。請先在下方新增帳號。"))
                                          : qsTr("目前為手動登入模式。下方帳號區塊會維持唯讀。")
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 300
                                Layout.minimumWidth: 300
                                Layout.maximumWidth: 300
                                Layout.preferredHeight: Math.max(470, existingAccountsCardContent.implicitHeight + 36)
                                Layout.minimumHeight: 470
                                Layout.alignment: Qt.AlignTop
                                radius: 20
                                color: Theme.sidebarColor
                                border.color: Theme.borderColor
                                clip: true
                                opacity: settingView.autoLoginSelected ? 1.0 : 0.55

                                ColumnLayout {
                                    id: existingAccountsCardContent
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 14

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            text: qsTr("已建立帳號")
                                            color: Theme.header2Color
                                            font.pixelSize: Constants.header2FontSize
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        text: qsTr("點選左側帳號即可編輯。")
                                        color: Theme.headerSubColor
                                        font.pixelSize: 12
                                    }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: accountListColumn.implicitHeight

                                        Column {
                                            id: accountListColumn
                                            width: parent.width
                                            spacing: 10

                                            Repeater {
                                                model: AppSettings ? AppSettings.myAcgAccounts : []

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    width: accountListColumn.width
                                                    height: 88
                                                    radius: 16
                                                    color: settingView.activeEditorAccountName === String(modelData.name)
                                                           ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.18)
                                                           : Theme.surface
                                                    border.width: settingView.activeEditorAccountName === String(modelData.name) ? 2 : 1
                                                    border.color: settingView.activeEditorAccountName === String(modelData.name)
                                                                  ? Theme.primaryColor
                                                                  : Theme.borderColor

                                                    Column {
                                                        anchors.fill: parent
                                                        anchors.margins: 14
                                                        spacing: 6

                                                        Text {
                                                            text: String(modelData.name)
                                                            color: Theme.header1Color
                                                            font.pixelSize: Constants.header3FontSize
                                                            font.bold: true
                                                        }

                                                        Text {
                                                            text: String(modelData.account)
                                                            color: Theme.headerSubColor
                                                            font.pixelSize: 12
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        enabled: settingView.autoLoginSelected
                                                        onClicked: settingView.selectStoredAccount(String(parent.modelData.name))
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: AppSettings && AppSettings.myAcgAccounts.length === 0
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                                text: qsTr("目前尚未建立任何 myacg 帳號。")
                                                color: Theme.headerSubColor
                                                font.pixelSize: Constants.header3FontSize
                                            }
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 10
                                        rowSpacing: 10

                                        CustomButton {
                                            Layout.fillWidth: true
                                            text: qsTr("載入資料")
                                            enabled: settingView.autoLoginSelected && settingView.activeEditorAccountName.length > 0
                                            onClicked: settingView.loadSelectedAccountIntoForm()
                                        }

                                        CustomButton {
                                            Layout.fillWidth: true
                                            text: qsTr("測試登入")
                                            enabled: settingView.autoLoginSelected && settingView.activeEditorAccountName.length > 0
                                            onClicked: settingView.testSelectedAccountLogin()
                                        }

                                        CustomButton {
                                            Layout.columnSpan: 2
                                            Layout.fillWidth: true
                                            text: qsTr("刪除帳號")
                                            enabled: settingView.autoLoginSelected && settingView.activeEditorAccountName.length > 0
                                            onClicked: settingView.requestDeleteSelectedAccount()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(470, addAccountCardContent.implicitHeight + 44)
                                Layout.minimumHeight: 470
                                Layout.alignment: Qt.AlignTop
                                radius: 20
                                color: Theme.sidebarColor
                                border.color: Theme.borderColor
                                opacity: settingView.autoLoginSelected ? 1.0 : 0.55

                                ColumnLayout {
                                    id: addAccountCardContent
                                    anchors.fill: parent
                                    anchors.margins: 22
                                    spacing: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: qsTr("新增帳號")
                                            color: Theme.header2Color
                                            font.pixelSize: Constants.header2FontSize
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: qsTr("名稱只用於 app 內辨識，登入帳號與密碼會保存在這台電腦的設定檔中。若名稱相同，會覆蓋原本帳號資料。")
                                            color: Theme.headerSubColor
                                            font.pixelSize: 12
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: width >= 520 ? 2 : 1
                                        columnSpacing: 14
                                        rowSpacing: 14

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: qsTr("名稱")
                                                color: Theme.header3Color
                                                font.pixelSize: Constants.header3FontSize
                                            }

                                            CustomEntry {
                                                Layout.fillWidth: true
                                                text: settingView.editingAccountName
                                                placeholderText: qsTr("例如：主要帳號")
                                                enabled: settingView.autoLoginSelected
                                                onTextChanged: settingView.editingAccountName = text
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: qsTr("myacg 帳號")
                                                color: Theme.header3Color
                                                font.pixelSize: Constants.header3FontSize
                                            }

                                            CustomEntry {
                                                Layout.fillWidth: true
                                                text: settingView.editingLoginAccount
                                                placeholderText: qsTr("請輸入登入帳號")
                                                enabled: settingView.autoLoginSelected
                                                onTextChanged: settingView.editingLoginAccount = text
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.columnSpan: width >= 520 ? 2 : 1
                                            spacing: 8

                                            Text {
                                                text: qsTr("密碼")
                                                color: Theme.header3Color
                                                font.pixelSize: Constants.header3FontSize
                                            }

                                            CustomEntry {
                                                Layout.fillWidth: true
                                                text: settingView.editingPassword
                                                placeholderText: qsTr("請輸入密碼")
                                                echoMode: TextInput.Password
                                                enabled: settingView.autoLoginSelected
                                                onTextChanged: settingView.editingPassword = text
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: settingView.accountNotice.length > 0
                                        Layout.fillWidth: true
                                        radius: 14
                                        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08)
                                        border.color: Theme.borderColor

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            wrapMode: Text.WordWrap
                                            text: settingView.accountNotice
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Item { Layout.fillWidth: true }

                                        CustomButton {
                                            text: qsTr("清空")
                                            enabled: settingView.autoLoginSelected
                                            onClicked: settingView.prepareNewAccount()
                                        }

                                        CustomButton {
                                            text: qsTr("新增")
                                            highlighted: true
                                            enabled: settingView.autoLoginSelected && settingView.editingAccountName.trim().length > 0
                                            onClicked: settingView.saveMyAcgAccount()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
