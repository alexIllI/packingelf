import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: printingView
    anchors.fill: parent

    title: qsTr("列印出貨單")
    subtitle: qsTr("建立列印工作並檢視已完成貨單")

    property string inputError: ""
    property string lastResult: ""
    property var prefixOptions: []
    property string preparedInvoiceNumber: ""
    property int selectedPrintedRow: -1
    property string selectedPrintedOrderNumber: ""
    property int selectedPendingRow: -1
    property string selectedPendingOrderNumber: ""
    property string pendingInputError: ""
    property string pendingLastResult: ""
    readonly property var printedStatusOptions: [
        {
            text: qsTr("全部"),
            value: "all"
        },
        {
            text: qsTr("成功"),
            value: "success"
        },
        {
            text: qsTr("關轉"),
            value: "closed"
        },
        {
            text: qsTr("取消"),
            value: "canceled"
        }
    ]

    function syncPrefixOptions() {
        var source = AppSettings ? AppSettings.printingPrefixOptions : null;
        var nextOptions = [];

        if (source && typeof source.length === "number") {
            for (var i = 0; i < source.length; ++i)
                nextOptions.push(String(source[i]));
        }

        if (nextOptions.length === 0)
            nextOptions = ["PG022", "PG023", "PG024", "PG025", "PG026"];

        prefixOptions = nextOptions;
    }

    function defaultPrefixText() {
        return prefixOptions.length >= 3 ? prefixOptions[2] : "PG024";
    }

    function currentPrefixText() {
        return prefixDropdown.currentText || defaultPrefixText();
    }

    function currentPendingPrefixText() {
        return pendingPrefixDropdown.currentText || defaultPrefixText();
    }

    function applyPrintedTableFilter() {
        var statusValue = printedStatusDropdown.currentValue;
        if (statusValue === undefined || statusValue === null || statusValue === "")
            statusValue = "all";

        PrintingOrdersTableVM.setRecentHoursFilter(24);
        PrintingOrdersTableVM.applyFilters(String(statusValue), "", "", "");
        clearPrintedSelection();
    }

    function searchPrintedOrder() {
        var query = searchPrintedInput.text.trim();
        if (query.length === 0) {
            AppDialog.showWarning(qsTr("請先輸入搜尋內容"),
                                  qsTr("請輸入要查找的貨單號碼或發票號碼。"));
            return;
        }

        var row = PrintingOrdersTableVM.findRow(query);
        if (row < 0) {
            AppDialog.showWarning(qsTr("查無資料"),
                                  qsTr("最近 24 小時的已完成貨單中找不到符合的資料。"));
            return;
        }

        printedOrdersTable.currentIndex = row;
        printedOrdersTable.scrollToIndex(row);
        selectPrintedRow(row);
    }

    function focusOrderEntry() {
        orderNumberInput.forceActiveFocus();
    }

    function focusInvoiceEntry() {
        invoiceNumberInput.forceActiveFocus();
    }

    function resetInputWorkflow() {
        preparedInvoiceNumber = "";
        orderNumberInput.text = "";
        invoiceNumberInput.text = "";
        focusOrderEntry();
    }

    function clearPrintedSelection() {
        selectedPrintedRow = -1;
        selectedPrintedOrderNumber = "";
        if (printedOrdersTable)
            printedOrdersTable.currentIndex = -1;
    }

    function selectPrintedRow(row) {
        selectedPrintedRow = row;
        selectedPrintedOrderNumber = PrintingOrdersTableVM.orderNumberAt(row);
    }

    function clearPendingSelection() {
        selectedPendingRow = -1;
        selectedPendingOrderNumber = "";
        if (pendingOrdersTable)
            pendingOrdersTable.currentIndex = -1;
    }

    function selectPendingRow(row) {
        selectedPendingRow = row;
        selectedPendingOrderNumber = PendingOrdersVM.orderNumberAt(row);
    }

    function formatOrderStatus(status) {
        var normalized = String(status || "").trim().toLowerCase();
        if (normalized === "success")
            return qsTr("列印完成");
        if (normalized === "canceled")
            return qsTr("訂單已取消");
        if (normalized === "closed")
            return qsTr("門市關轉");
        return normalized.length > 0 ? normalized : qsTr("未記錄");
    }

    function formatCouponFlag(usingCoupon) {
        return usingCoupon ? qsTr("有") : qsTr("無");
    }

    function formatTotalAmount(totalAmount) {
        var amount = Number(totalAmount || 0);
        return amount > 0 ? String(amount) : qsTr("未記錄");
    }

    function formatOrderInfoMessage(details) {
        return qsTr("貨單號碼：%1\n發票號碼：%2\n建立時間：%3\n目前狀態：%4\n總金額：%5\n優惠券：%6").arg(String(details.orderNumber || qsTr("未記錄"))).arg(String(details.invoiceNumber || qsTr("未記錄"))).arg(String(details.createdAt || qsTr("未記錄"))).arg(formatOrderStatus(details.status)).arg(formatTotalAmount(details.totalAmount)).arg(formatCouponFlag(Boolean(details.usingCoupon)));
    }

    function normalizedInvoiceText(rawText) {
        return String(rawText || "").trim().toUpperCase().replace(/\s+/g, "");
    }

    function tryExtractInvoiceNumber(rawText) {
        var normalized = normalizedInvoiceText(rawText);
        var validInvoiceRx = /^[A-Z]{2}\d{8}$/;

        if (validInvoiceRx.test(normalized))
            return normalized;

        if (normalized.length >= 15) {
            var sliced = normalized.slice(5, 15);
            if (validInvoiceRx.test(sliced))
                return sliced;
        }

        return "";
    }

    function handleOrderNumberEnter() {
        inputError = "";
        lastResult = "";

        var suffix = orderNumberInput.text.trim();
        var suffixRx = /^\d{5}$/;
        if (!suffixRx.test(suffix)) {
            inputError = qsTr("貨單尾碼必須為 5 位數字，例如 12345。");
            focusOrderEntry();
            return;
        }

        preparedInvoiceNumber = "";
        focusInvoiceEntry();
    }

    function submitPrintJob() {
        var suffix = orderNumberInput.text.trim();
        var invoice = normalizedInvoiceText(invoiceNumberInput.text);
        var prefix = currentPrefixText();

        inputError = "";
        lastResult = "";

        var suffixRx = /^\d{5}$/;
        if (!suffixRx.test(suffix)) {
            inputError = qsTr("貨單尾碼必須為 5 位數字，例如 12345。");
            focusOrderEntry();
            return;
        }

        var invoiceRx = /^[A-Z]{2}\d{8}$/;
        if (!invoiceRx.test(invoice))
            invoice = tryExtractInvoiceNumber(invoiceNumberInput.text);

        if (!invoiceRx.test(invoice)) {
            inputError = qsTr("發票號碼格式必須為 2 個英文字母加 8 位數字，例如 AB12345678。");
            focusInvoiceEntry();
            return;
        }

        preparedInvoiceNumber = invoice;
        invoiceNumberInput.text = invoice;

        var fullOrderNumber = prefix + suffix;
        var existingOrder = OrdersVM.orderDetailsByOrderNumber(fullOrderNumber);
        if (existingOrder && existingOrder.id) {
            AppDialog.confirm({
                titleText: qsTr("貨單已存在"),
                messageText: qsTr("這筆貨單已經列印過，是否要重新列印並覆蓋原本結果？\n\n%1").arg(formatOrderInfoMessage(existingOrder)),
                confirmText: qsTr("重新列印"),
                cancelText: qsTr("取消"),
                iconSource: AppDialog.questionIcon,
                accentColor: Theme.questionColor,
                onConfirmAction: function () {
                    printingView.startScrapeSubmission(fullOrderNumber, invoice);
                }
            });
            return;
        }

        startScrapeSubmission(fullOrderNumber, invoice);
    }

    function startScrapeSubmission(fullOrderNumber, invoice) {
        if (ScraperSvc.browserState !== 2) {
            inputError = qsTr("瀏覽器尚未就緒，請等待自動化網頁啟動完成。");
            focusOrderEntry();
            return;
        }

        var submissionId = OrdersVM.submitForScrape(fullOrderNumber, invoice);
        if (submissionId.length === 0) {
            inputError = qsTr("建立列印工作失敗。");
            focusOrderEntry();
            return;
        }

        ScraperSvc.scrape(submissionId, fullOrderNumber);
        lastResult = qsTr("已開始列印...");
        resetInputWorkflow();
        clearPrintedSelection();
    }

    function handleInvoiceEnter() {
        inputError = "";

        var extracted = tryExtractInvoiceNumber(invoiceNumberInput.text);
        if (extracted.length === 0) {
            preparedInvoiceNumber = "";
            inputError = qsTr("發票號碼格式必須為 2 個英文字母加 8 位數字，例如 AB12345678。");
            focusInvoiceEntry();
            return;
        }

        if (preparedInvoiceNumber === extracted && normalizedInvoiceText(invoiceNumberInput.text) === extracted) {
            submitPrintJob();
            return;
        }

        preparedInvoiceNumber = extracted;
        invoiceNumberInput.text = extracted;
        lastResult = qsTr("已擷取發票號碼，請再按一次 Enter 送出。");
        focusInvoiceEntry();
    }

    function presentScrapeOutcome(result) {
        var normalizedStatus = String(result.status || "").trim().toUpperCase();
        var reason = String(result.message || "");

        if (normalizedStatus === "SUCCESS") {
            printingView.lastResult = qsTr("列印完成。");
            return;
        }

        if (normalizedStatus === "ORDER_CANCELED" || normalizedStatus === "CANCELED") {
            printingView.lastResult = qsTr("該訂單已取消。");
            AppDialog.showWarning(qsTr("該訂單已取消"), qsTr("這筆貨單已取消，未進行列印。"));
            return;
        }

        if (normalizedStatus === "STORE_CLOSED" || normalizedStatus === "CLOSED") {
            printingView.lastResult = qsTr("門市關轉。");
            AppDialog.showWarning(qsTr("門市關轉"), qsTr("這筆貨單目前為門市關轉，未進行列印。"));
            return;
        }

        if (normalizedStatus === "ALREADY_PICKED_UP") {
            printingView.lastResult = qsTr("訂單已取貨。");
            AppDialog.showWarning(qsTr("訂單已取貨"), qsTr("這筆貨單已取貨，無法重新列印。"));
            return;
        }

        if (normalizedStatus === "ORDER_NOT_FOUND") {
            printingView.lastResult = qsTr("查無訂單。");
            AppDialog.showError(qsTr("查無訂單"), qsTr("找不到這筆貨單，請確認貨單號碼是否正確。"));
            return;
        }

        if (normalizedStatus === "PRINT_ERROR") {
            printingView.lastResult = qsTr("列印失敗。");
            AppDialog.showError(qsTr("列印失敗"), reason.length > 0 ? reason : qsTr("列印流程未完成，請再試一次。"));
            return;
        }

        printingView.lastResult = qsTr("列印失敗。");
        AppDialog.showError(qsTr("列印失敗"), reason.length > 0 ? reason : qsTr("列印流程發生未預期錯誤。"));
    }

    function requestDeletePrintedOrder() {
        if (selectedPrintedRow < 0)
            return;

        var details = OrdersVM.orderDetailsByOrderNumber(selectedPrintedOrderNumber);
        if (!details || !details.id)
            return;

        AppDialog.confirm({
            titleText: qsTr("刪除貨單"),
            messageText: qsTr("確定要刪除這筆貨單嗎？\n\n%1").arg(formatOrderInfoMessage(details)),
            confirmText: qsTr("刪除"),
            cancelText: qsTr("取消"),
            iconSource: AppDialog.warningIcon,
            accentColor: Theme.warningColor,
            onConfirmAction: function () {
                if (!OrdersVM.removeOrderByOrderNumber(printingView.selectedPrintedOrderNumber)) {
                    AppDialog.showError(qsTr("刪除失敗"), qsTr("無法刪除這筆貨單，請稍後再試。"));
                    return;
                }

                printingView.clearPrintedSelection();
                printingView.lastResult = qsTr("已刪除貨單。");
            }
        });
    }

    function requestReprintPrintedOrder() {
        if (selectedPrintedRow < 0)
            return;

        var details = OrdersVM.orderDetailsByOrderNumber(selectedPrintedOrderNumber);
        if (!details || !details.id)
            return;

        AppDialog.confirm({
            titleText: qsTr("重新列印"),
            messageText: qsTr("確定要重新列印這筆貨單嗎？重新列印後會覆蓋原本結果。\n\n%1").arg(formatOrderInfoMessage(details)),
            confirmText: qsTr("重新列印"),
            cancelText: qsTr("取消"),
            iconSource: AppDialog.questionIcon,
            accentColor: Theme.questionColor,
            onConfirmAction: function () {
                printingView.startScrapeSubmission(String(details.orderNumber || ""), String(details.invoiceNumber || ""));
            }
        });
    }

    function addPendingOrder() {
        var suffix = pendingOrderNumberInput.text.trim();
        var remark = remarkInput.text.trim();
        var suffixRx = /^\d{5}$/;

        pendingInputError = "";
        pendingLastResult = "";

        if (!suffixRx.test(suffix)) {
            pendingInputError = qsTr("待處理貨單尾碼必須為 5 位數字，例如 12345。");
            pendingOrderNumberInput.forceActiveFocus();
            return;
        }

        var fullOrderNumber = currentPendingPrefixText() + suffix;
        var error = PendingOrdersVM.addPendingOrder(fullOrderNumber, remark);
        if (error.length > 0) {
            pendingInputError = error;
            pendingOrderNumberInput.forceActiveFocus();
            return;
        }

        pendingOrderNumberInput.text = "";
        remarkInput.text = "";
        pendingLastResult = qsTr("已新增待處理貨單。");
        clearPendingSelection();
        pendingOrderNumberInput.forceActiveFocus();
    }

    function requestDeletePendingOrder() {
        if (selectedPendingRow < 0)
            return;

        var orderNumber = selectedPendingOrderNumber;
        AppDialog.confirm({
            titleText: qsTr("刪除待處理"),
            messageText: qsTr("確定要刪除這筆待處理貨單嗎？\n\n貨單號碼：%1").arg(orderNumber),
            confirmText: qsTr("刪除"),
            cancelText: qsTr("取消"),
            iconSource: AppDialog.warningIcon,
            accentColor: Theme.warningColor,
            onConfirmAction: function () {
                if (!PendingOrdersVM.removePendingOrder(printingView.selectedPendingRow)) {
                    AppDialog.showError(qsTr("刪除失敗"), qsTr("無法刪除這筆待處理貨單，請稍後再試。"));
                    return;
                }

                printingView.clearPendingSelection();
                printingView.pendingLastResult = qsTr("已刪除待處理貨單。");
            }
        });
    }

    function resetPrefixDropdowns() {
        var defaultIndex = Math.min(2, Math.max(0, prefixOptions.length - 1));
        prefixDropdown.currentIndex = defaultIndex;
        pendingPrefixDropdown.currentIndex = defaultIndex;
    }

    Component.onCompleted: {
        syncPrefixOptions();
        resetPrefixDropdowns();
        printedStatusDropdown.currentIndex = 0;
        PrintingOrdersTableVM.setRecentHoursFilter(24);
        applyPrintedTableFilter();
        focusOrderEntry();
    }

    Connections {
        target: ScraperSvc
        function onScraperFinishedForUi(submissionId, result) {
            printingView.presentScrapeOutcome(result || {});
        }

        function onScraperFailed(submissionId, reason) {
            printingView.lastResult = qsTr("列印失敗：") + reason;
            AppDialog.showError(qsTr("列印失敗"), reason && reason.length > 0 ? reason : qsTr("列印流程發生未預期錯誤。"));
        }
    }

    Connections {
        target: OrdersVM
        function onCountChanged() {
            printingView.applyPrintedTableFilter();
        }
    }

    Connections {
        target: AppSettings
        function onOrderPrefixChanged() {
            printingView.syncPrefixOptions();
            printingView.resetPrefixDropdowns();
        }
    }

    Connections {
        target: PrintingOrdersTableVM
        function onCountChanged() {
            if (printingView.selectedPrintedRow >= PrintingOrdersTableVM.count)
                printingView.clearPrintedSelection();
        }
    }

    Connections {
        target: PendingOrdersVM
        function onCountChanged() {
            if (printingView.selectedPendingRow >= PendingOrdersVM.count)
                printingView.clearPendingSelection();
        }
    }

    Flickable {
        id: printingScrollView
        anchors.fill: parent
        contentWidth: width
        contentHeight: printingLayout.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        BasicControls.ScrollBar.vertical: BasicControls.ScrollBar {
            id: pageScrollBar
            policy: BasicControls.ScrollBar.AsNeeded

            contentItem: Rectangle {
                implicitWidth: 5
                implicitHeight: 30
                radius: 3
                color: pageScrollBar.pressed ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.6) : pageScrollBar.hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4) : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            background: Item {}
        }

        ColumnLayout {
            id: printingLayout
            width: printingScrollView.width
            spacing: 16

            Text {
                color: Theme.header3Color
                text: qsTr("建立列印工作")
                font.pixelSize: Constants.header3FontSize
            }

            Rectangle {
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                radius: 15
                border.color: Theme.borderColor
                Layout.fillWidth: true
                Layout.minimumHeight: 380

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            color: Theme.header3Color
                            text: qsTr("前綴：")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomDropdown {
                            id: prefixDropdown
                            model: printingView.prefixOptions
                            placeholderText: printingView.defaultPrefixText()
                            Layout.maximumWidth: 110
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("貨單尾碼：")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: orderNumberInput
                            placeholderText: qsTr("請輸入 5 碼尾碼")
                            maximumLength: 5
                            Layout.fillWidth: true
                            onAccepted: printingView.handleOrderNumberEnter()
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("發票號碼：")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: invoiceNumberInput
                            placeholderText: qsTr("請輸入發票號碼")
                            Layout.fillWidth: true
                            onAccepted: printingView.handleInvoiceEnter()
                        }

                        CustomButton {
                            text: qsTr("開始列印")
                            highlighted: true
                            enabled: !ScraperSvc.busy
                            onClicked: printingView.submitPrintJob()
                        }

                        CustomBusyIndicator {
                            visible: ScraperSvc.busy
                            running: ScraperSvc.busy
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: printingView.inputError !== "" || printingView.lastResult !== ""

                        Text {
                            text: printingView.inputError !== "" ? printingView.inputError : printingView.lastResult
                            color: printingView.inputError !== "" ? "#ff6060" : Theme.goodColor
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    ToolSeparator {
                        Layout.fillWidth: true
                        orientation: Qt.Horizontal
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            color: Theme.header3Color
                            text: qsTr("已完成貨單")
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("搜尋：")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomEntry {
                            id: searchPrintedInput
                            placeholderText: qsTr("搜尋貨單號碼或發票號碼")
                            Layout.preferredWidth: 188
                            Layout.preferredHeight: 36
                            onAccepted: printingView.searchPrintedOrder()
                        }

                        CustomButton {
                            text: qsTr("搜尋")
                            onClicked: printingView.searchPrintedOrder()
                        }

                        CustomDropdown {
                            id: printedStatusDropdown
                            model: printingView.printedStatusOptions
                            textRole: "text"
                            valueRole: "value"
                            placeholderText: qsTr("全部")
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 38
                            onActivated: printingView.applyPrintedTableFilter()
                        }
                    }

                    CustomTable {
                        id: printedOrdersTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: [
                            {
                                title: qsTr("日期"),
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: qsTr("貨單號碼"),
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: qsTr("發票號碼"),
                                role: "invoiceNumber",
                                width: 0.2
                            },
                            {
                                title: qsTr("買家"),
                                role: "accountName",
                                width: 0.12
                            },
                            {
                                title: qsTr("總金額"),
                                role: "totalAmount",
                                width: 0.13
                            },
                            {
                                title: qsTr("狀態"),
                                role: "status",
                                width: 0.1
                            },
                            {
                                title: qsTr("優惠券"),
                                role: "usingCoupon",
                                width: 0.1
                            }
                        ]
                        model: PrintingOrdersTableVM

                        onRowClicked: index => {
                            printingView.selectPrintedRow(index);
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        CustomButton {
                            text: qsTr("清除選取")
                            enabled: printingView.selectedPrintedRow >= 0
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                            onClicked: printingView.clearPrintedSelection()
                        }

                        CustomButton {
                            text: qsTr("重新列印")
                            enabled: printingView.selectedPrintedRow >= 0 && !ScraperSvc.busy
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                            onClicked: printingView.requestReprintPrintedOrder()
                        }

                        CustomButton {
                            id: deletePrintedButton
                            text: qsTr("刪除")
                            enabled: printingView.selectedPrintedRow >= 0
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                            onClicked: printingView.requestDeletePrintedOrder()
                        }
                    }
                }
            }

            Text {
                color: Theme.header3Color
                text: qsTr("待處理貨單")
                font.pixelSize: Constants.header3FontSize
                Layout.topMargin: 20
            }

            Rectangle {
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                radius: 15
                border.color: Theme.borderColor
                Layout.fillWidth: true
                Layout.minimumHeight: 280

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Text {
                            color: Theme.header3Color
                            text: qsTr("前綴：")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomDropdown {
                            id: pendingPrefixDropdown
                            model: printingView.prefixOptions
                            placeholderText: printingView.defaultPrefixText()
                            Layout.maximumWidth: 110
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("貨單尾碼：")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: pendingOrderNumberInput
                            placeholderText: qsTr("請輸入 5 碼尾碼")
                            Layout.fillWidth: true
                            onAccepted: printingView.addPendingOrder()
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("備註")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: remarkInput
                            placeholderText: qsTr("請輸入備註")
                            Layout.fillWidth: true
                            onAccepted: printingView.addPendingOrder()
                        }

                        CustomButton {
                            text: qsTr("新增待處理")
                            highlighted: true
                            Layout.leftMargin: 20
                            Layout.maximumWidth: 120
                            Layout.fillWidth: true
                            onClicked: printingView.addPendingOrder()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: printingView.pendingInputError !== "" || printingView.pendingLastResult !== ""

                        Text {
                            text: printingView.pendingInputError !== "" ? printingView.pendingInputError : printingView.pendingLastResult
                            color: printingView.pendingInputError !== "" ? Theme.errorColor : Theme.goodColor
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    CustomTable {
                        id: pendingOrdersTable
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        columns: [
                            {
                                title: qsTr("日期"),
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: qsTr("貨單號碼"),
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: qsTr("備註"),
                                role: "remark",
                                width: 0.55
                            }
                        ]
                        model: PendingOrdersVM

                        onRowClicked: index => {
                            printingView.selectPendingRow(index);
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        CustomButton {
                            text: qsTr("清除選取")
                            enabled: printingView.selectedPendingRow >= 0
                            onClicked: printingView.clearPendingSelection()
                        }

                        CustomButton {
                            text: qsTr("刪除待處理")
                            enabled: printingView.selectedPendingRow >= 0
                            onClicked: printingView.requestDeletePendingOrder()
                        }
                    }
                }
            }
        }
    }
}
