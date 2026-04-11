import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: homeView
    anchors.fill: parent

    property int totalOrders: DashboardVM.totalOrders
    property int pendingOrders: DashboardVM.pendingOrders
    property int todayProcessed: DashboardVM.todayProcessed
    property int errorJobs: DashboardVM.errorCount
    property bool hostDbOnline: SyncSvc.hostOnline
    property bool localDbOnline: AppSupport.localDbHealthy
    property int pendingSyncCount: SyncSvc.pendingOutboxCount
    property bool waitingForConnectionTest: false
    property bool waitingForSync: false
    property bool waitingForBrowserRestart: false
    readonly property int sectionRadius: 14
    readonly property int sectionPadding: 12
    readonly property int actionButtonHeight: 38

    title: qsTr("首頁")
    subtitle: qsTr("掌握今日進度、網頁自動化狀態與資料同步情況")

    function browserStatusLabel() {
        const state = ScraperSvc.browserState;
        if (state === 0)
            return qsTr("未啟動");
        if (state === 1)
            return qsTr("啟動中");
        if (state === 2)
            return qsTr("就緒");
        if (state === 3)
            return qsTr("登入中");
        if (state === 4)
            return qsTr("等待登入");
        return qsTr("異常");
    }

    function browserStatusColor() {
        const state = ScraperSvc.browserState;
        if (state === 2)
            return Theme.goodColor;
        if (state === 1 || state === 3 || state === 4)
            return Theme.warningColor;
        return Theme.errorColor;
    }

    function hostStatusLabel() {
        return homeView.hostDbOnline ? qsTr("已連線") : qsTr("未連線");
    }

    function localStatusLabel() {
        return homeView.localDbOnline ? qsTr("正常") : qsTr("異常");
    }

    function hostDetailText() {
        if (SyncSvc.statusText && SyncSvc.statusText.length > 0)
            return SyncSvc.statusText;
        return qsTr("等待同步服務更新");
    }

    function syncSummaryText() {
        if (homeView.pendingSyncCount > 0)
            return qsTr("還有 %1 筆變更待同步到主機。").arg(homeView.pendingSyncCount);
        if (!homeView.hostDbOnline)
            return qsTr("主機目前未連線，本機資料仍可使用，稍後會自動重試同步。");
        return qsTr("目前沒有待同步資料。");
    }

    function workHintText() {
        if (homeView.pendingOrders > 0)
            return qsTr("目前有 %1 筆待處理貨單，建議優先完成列印。").arg(homeView.pendingOrders);
        if (ScraperSvc.browserState !== 2)
            return qsTr("自動化網頁尚未完全就緒，開始列印前請先確認瀏覽器登入狀態。");
        return qsTr("目前流程正常，可以直接前往列印頁繼續作業。");
    }

    function autoLoginLabel() {
        return AppSettings.autoLoginEnabled ? qsTr("自動登入：%1").arg(AppSettings.selectedMyAcgAccountName || qsTr("未指定帳號")) : qsTr("手動登入");
    }

    function statusSummaryText() {
        if (homeView.hostDbOnline && homeView.localDbOnline && ScraperSvc.browserState === 2)
            return qsTr("本機與同步服務皆正常，可以直接開始作業。");
        if (!homeView.hostDbOnline)
            return qsTr("主機離線中，系統會先保留本機作業結果並稍後重試同步。");
        if (!homeView.localDbOnline)
            return qsTr("本機資料庫需要檢查，建議先測試資料庫連線。");
        return qsTr("自動化網頁尚未就緒，請先確認登入或重新啟動自動化網頁。");
    }

    function diagnosticsSummaryText() {
        return qsTr("待處理 %1 筆 / 待同步 %2 筆 / 前綴 %3").arg(homeView.pendingOrders).arg(homeView.pendingSyncCount).arg(AppSettings.orderPrefix.toString().padStart(3, "0"));
    }

    function shortenPath(pathValue) {
        if (!pathValue || pathValue.length <= 48)
            return pathValue;
        return pathValue.slice(0, 22) + "..." + pathValue.slice(pathValue.length - 20);
    }

    function showOpenLogError() {
        AppDialog.showError(qsTr("開啟失敗"), qsTr("目前無法開啟記錄檔或資料夾。"));
    }

    function showOpenDatabaseError() {
        AppDialog.showError(qsTr("開啟失敗"), qsTr("目前無法開啟資料庫位置。"));
    }

    function showOperationResult(ok, titleText, messageText) {
        if (ok)
            AppDialog.showSuccess(titleText, messageText);
        else
            AppDialog.showError(titleText, messageText);
    }

    Item {
        anchors.fill: parent

        Connections {
            target: SyncSvc

            function onConnectionTestFinished(ok, message) {
                if (!homeView.waitingForConnectionTest)
                    return;

                homeView.waitingForConnectionTest = false;
                homeView.showOperationResult(ok, qsTr("主機連線測試"), message && message.length > 0 ? message : (ok ? qsTr("主機連線正常。") : qsTr("主機連線失敗。")));
            }

            function onSyncCycleFinished(ok, message) {
                if (!homeView.waitingForSync)
                    return;

                homeView.waitingForSync = false;
                homeView.showOperationResult(ok, qsTr("同步結果"), message && message.length > 0 ? message : (ok ? qsTr("同步完成。") : qsTr("同步失敗。")));
            }
        }

        Connections {
            target: ScraperSvc

            function onBrowserReady() {
                if (!homeView.waitingForBrowserRestart)
                    return;

                homeView.waitingForBrowserRestart = false;
                AppDialog.showSuccess(qsTr("自動化網頁已重啟"), qsTr("瀏覽器已就緒，可以繼續列印。"));
            }

            function onBrowserDied(reason) {
                if (!homeView.waitingForBrowserRestart)
                    return;

                homeView.waitingForBrowserRestart = false;
                AppDialog.showError(qsTr("自動化網頁重啟失敗"), reason && reason.length > 0 ? reason : qsTr("自動化網頁目前無法啟動。"));
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Constants.pageGap

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                MetricCard {
                    Layout.fillWidth: true
                    title: qsTr("總貨單")
                    targetValue: homeView.totalOrders
                    unit: qsTr("筆")
                    iconSource: "../assets/images/total_orders.svg"
                }
                MetricCard {
                    Layout.fillWidth: true
                    title: qsTr("今日完成")
                    targetValue: homeView.todayProcessed
                    unit: qsTr("筆")
                    iconSource: "../assets/images/record.svg"
                }
                MetricCard {
                    Layout.fillWidth: true
                    title: qsTr("待處理")
                    targetValue: homeView.pendingOrders
                    unit: qsTr("筆")
                    iconSource: "../assets/images/pending.svg"
                }
                MetricCard {
                    Layout.fillWidth: true
                    title: qsTr("待同步")
                    targetValue: homeView.pendingSyncCount
                    unit: qsTr("筆")
                    iconSource: "../assets/images/history.svg"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Constants.pageGap

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 620
                    Layout.minimumHeight: 320

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: qsTr("系統狀態")
                            color: Theme.header1Color
                            font.pixelSize: Constants.header2FontSize
                            font.bold: true
                        }

                        ScrollView {
                            id: leftScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            BasicControls.ScrollBar.vertical: BasicControls.ScrollBar {
                                id: leftScrollBar
                                policy: BasicControls.ScrollBar.AsNeeded
                                width: 8
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 2

                                contentItem: Rectangle {
                                    implicitWidth: 5
                                    implicitHeight: 30
                                    radius: 3
                                    color: leftScrollBar.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.6) : leftScrollBar.hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4) : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }

                                background: Item {
                                    implicitWidth: 8
                                }
                            }

                            Column {
                                width: leftScroll.availableWidth
                                spacing: 12

                                GridLayout {
                                    width: parent.width
                                    columns: 3
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: [
                                            {
                                                "title": qsTr("自動化網頁"),
                                                "label": homeView.browserStatusLabel(),
                                                "color": homeView.browserStatusColor()
                                            },
                                            {
                                                "title": qsTr("主機同步"),
                                                "label": homeView.hostStatusLabel(),
                                                "color": homeView.hostDbOnline ? Theme.goodColor : Theme.errorColor
                                            },
                                            {
                                                "title": qsTr("本機資料庫"),
                                                "label": homeView.localStatusLabel(),
                                                "color": homeView.localDbOnline ? Theme.goodColor : Theme.errorColor
                                            }
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 74
                                            radius: homeView.sectionRadius
                                            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08)
                                            border.color: Theme.borderColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 8

                                                Text {
                                                    text: modelData.title
                                                    color: Theme.headerSubColor
                                                    font.pixelSize: Constants.header3FontSize
                                                }
                                                StatusLight {
                                                    label: modelData.label
                                                    indicatorColor: modelData.color
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.10)
                                    border.color: Theme.borderColor
                                    implicitHeight: summaryCol.implicitHeight + homeView.sectionPadding * 2

                                    Column {
                                        id: summaryCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        spacing: 8

                                        Text {
                                            text: qsTr("目前總覽")
                                            color: Theme.header1Color
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: true
                                        }
                                        Text {
                                            text: homeView.statusSummaryText()
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                                    border.color: Theme.borderColor
                                    implicitHeight: detailGrid.implicitHeight + homeView.sectionPadding * 2

                                    GridLayout {
                                        id: detailGrid
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        columns: 2
                                        columnSpacing: 14
                                        rowSpacing: 10

                                        Text {
                                            text: qsTr("自動化網頁狀態")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: ScraperSvc.statusText
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("同步狀態")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: homeView.hostDetailText()
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("主機位址")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: SyncSvc.hostBaseUrl && SyncSvc.hostBaseUrl.length > 0 ? SyncSvc.hostBaseUrl : qsTr("尚未設定")
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("資料庫檢查")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: AppSupport.localDbStatusText
                                            color: homeView.localDbOnline ? Theme.header3Color : Theme.warningColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("登入模式")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: homeView.autoLoginLabel()
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                                    border.color: Theme.borderColor
                                    implicitHeight: pathGrid.implicitHeight + homeView.sectionPadding * 2

                                    GridLayout {
                                        id: pathGrid
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        columns: 2
                                        columnSpacing: 14
                                        rowSpacing: 10

                                        Text {
                                            text: qsTr("設定檔")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: homeView.shortenPath(AppSettings.configFilePath)
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("資料庫位置")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: homeView.shortenPath(AppSupport.databasePath)
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: qsTr("記錄資料夾")
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                        }
                                        Text {
                                            text: homeView.shortenPath(AppSupport.logDirectoryPath)
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10

                            CustomButton {
                                text: qsTr("重新啟動自動化網頁")
                                highlighted: ScraperSvc.browserState === 0 || ScraperSvc.browserState === 5
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    homeView.waitingForBrowserRestart = true;
                                    ScraperSvc.restartConfiguredBrowser();
                                }
                            }

                            CustomButton {
                                text: qsTr("重新同步")
                                highlighted: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    homeView.waitingForSync = true;
                                    SyncSvc.triggerSync();
                                }
                            }

                            CustomButton {
                                text: qsTr("測試主機連線")
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    homeView.waitingForConnectionTest = true;
                                    SyncSvc.testConnection();
                                }
                            }

                            CustomButton {
                                text: qsTr("測試本機資料庫")
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    AppSupport.testLocalDatabase();
                                    homeView.showOperationResult(AppSupport.localDbHealthy, qsTr("本機資料庫測試"), AppSupport.localDbStatusText);
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 440
                    Layout.minimumHeight: 320

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: qsTr("工作提醒與診斷")
                            color: Theme.header1Color
                            font.pixelSize: Constants.header2FontSize
                            font.bold: true
                        }

                        ScrollView {
                            id: rightScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            BasicControls.ScrollBar.vertical: BasicControls.ScrollBar {
                                id: rightScrollBar
                                policy: BasicControls.ScrollBar.AsNeeded
                                width: 8
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 2

                                contentItem: Rectangle {
                                    implicitWidth: 5
                                    implicitHeight: 30
                                    radius: 3
                                    color: rightScrollBar.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.6) : rightScrollBar.hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4) : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                            easing.type: Easing.InOutCubic
                                        }
                                    }
                                }

                                background: Item {
                                    implicitWidth: 8
                                }
                            }

                            Column {
                                width: rightScroll.availableWidth
                                spacing: 12

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.10)
                                    border.color: Theme.borderColor
                                    implicitHeight: hintCol.implicitHeight + homeView.sectionPadding * 2

                                    Column {
                                        id: hintCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        spacing: 8

                                        Text {
                                            text: qsTr("作業建議")
                                            color: Theme.header1Color
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: true
                                        }
                                        Text {
                                            text: homeView.workHintText()
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                                    border.color: Theme.borderColor
                                    implicitHeight: syncCol.implicitHeight + homeView.sectionPadding * 2

                                    Column {
                                        id: syncCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        spacing: 8

                                        Text {
                                            text: qsTr("同步與錯誤提醒")
                                            color: Theme.header1Color
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: true
                                        }
                                        Text {
                                            text: homeView.syncSummaryText()
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                        Text {
                                            text: homeView.errorJobs > 0 ? qsTr("目前有 %1 筆同步錯誤待處理。").arg(homeView.errorJobs) : qsTr("目前沒有額外錯誤工作。")
                                            color: homeView.errorJobs > 0 ? Theme.warningColor : Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                                    border.color: Theme.borderColor
                                    implicitHeight: quickCol.implicitHeight + homeView.sectionPadding * 2

                                    Column {
                                        id: quickCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        spacing: 8

                                        Text {
                                            text: qsTr("快速資訊")
                                            color: Theme.header1Color
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: true
                                        }
                                        Text {
                                            text: homeView.diagnosticsSummaryText()
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                        Text {
                                            text: qsTr("登入模式：%1").arg(homeView.autoLoginLabel())
                                            color: Theme.header3Color
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: homeView.sectionRadius
                                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                                    border.color: Theme.borderColor
                                    implicitHeight: logCol.implicitHeight + homeView.sectionPadding * 2

                                    Column {
                                        id: logCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: homeView.sectionPadding
                                        spacing: 8

                                        Text {
                                            text: qsTr("記錄與診斷")
                                            color: Theme.header1Color
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: true
                                        }
                                        Text {
                                            text: qsTr("目前記錄檔：%1").arg(homeView.shortenPath(AppSupport.currentLogFilePath))
                                            color: Theme.headerSubColor
                                            font.pixelSize: Constants.header3FontSize
                                            wrapMode: Text.WrapAnywhere
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10

                            CustomButton {
                                text: qsTr("開啟目前記錄檔")
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    if (!AppSupport.openCurrentLogFile())
                                        homeView.showOpenLogError();
                                }
                            }

                            CustomButton {
                                text: qsTr("開啟記錄資料夾")
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    if (!AppSupport.openLogFolder())
                                        homeView.showOpenLogError();
                                }
                            }

                            CustomButton {
                                text: qsTr("開啟資料庫位置")
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: {
                                    if (!AppSupport.openDatabaseFolder())
                                        homeView.showOpenDatabaseError();
                                }
                            }

                            CustomButton {
                                text: qsTr("前往列印")
                                highlighted: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: homeView.actionButtonHeight
                                onClicked: NavStore.route = "Printing"
                            }
                        }
                    }
                }
            }
        }
    }
}
