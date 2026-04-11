import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: printingView
    anchors.fill: parent

    title: qsTr("列印出貨單")
    subtitle: qsTr("建立抓單工作並檢視已完成貨單")

    property string inputError: ""
    property string lastResult: ""
    property var prefixOptions: []
    property string preparedInvoiceNumber: ""

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
        if (ScraperSvc.browserState !== 2) {
            inputError = qsTr("瀏覽器尚未就緒，請等待抓單器啟動完成。");
            focusOrderEntry();
            return;
        }

        var submissionId = OrdersVM.submitForScrape(fullOrderNumber, invoice);
        if (submissionId.length === 0) {
            inputError = qsTr("建立抓單工作失敗。");
            focusOrderEntry();
            return;
        }

        ScraperSvc.scrape(submissionId, fullOrderNumber);
        lastResult = qsTr("已開始抓單...");
        resetInputWorkflow();
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

        if (preparedInvoiceNumber === extracted
                && normalizedInvoiceText(invoiceNumberInput.text) === extracted) {
            submitPrintJob();
            return;
        }

        preparedInvoiceNumber = extracted;
        invoiceNumberInput.text = extracted;
        lastResult = qsTr("已擷取發票號碼，請再按一次 Enter 送出。");
        focusInvoiceEntry();
    }

    function resetPrefixDropdowns() {
        var defaultIndex = Math.min(2, Math.max(0, prefixOptions.length - 1));
        prefixDropdown.currentIndex = defaultIndex;
        pendingPrefixDropdown.currentIndex = defaultIndex;
    }

    Component.onCompleted: {
        syncPrefixOptions();
        resetPrefixDropdowns();
        focusOrderEntry();
    }

    Connections {
        target: ScraperSvc
        function onScraperFinished(submissionId, result) {
            if (result.isSuccess) {
                printingView.lastResult = qsTr("抓單完成。");
            } else {
                printingView.lastResult = qsTr("抓單失敗：") + result.message;
            }
        }

        function onScraperFailed(submissionId, reason) {
            printingView.lastResult = qsTr("抓單失敗：") + reason;
        }
    }

    Connections {
        target: AppSettings
        function onOrderPrefixChanged() {
            printingView.syncPrefixOptions();
            printingView.resetPrefixDropdowns();
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
                color: pageScrollBar.pressed
                    ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.6)
                    : pageScrollBar.hovered
                        ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4)
                        : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2)

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
                text: qsTr("建立抓單")
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
                            text: qsTr("開始抓單")
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
                            placeholderText: qsTr("搜尋貨單號碼")
                            Layout.preferredWidth: 188
                            Layout.preferredHeight: 36
                        }

                        CustomButton {
                            text: qsTr("搜尋")
                        }

                        CustomDropdown {
                            placeholderText: qsTr("排序")
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 38
                        }
                    }

                    CustomTable {
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
                                width: 0.15
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
                        model: OrdersVM

                        onRowClicked: index => {
                            console.log("Selected row:", index);
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        CustomButton {
                            text: qsTr("重新列印")
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                        }

                        CustomButton {
                            id: deletePrintedButton
                            text: qsTr("刪除")
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                            onClicked: {
                                console.log("Delete clicked");
                            }
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
                        }

                        CustomButton {
                            text: qsTr("新增待處理")
                            highlighted: true
                            Layout.leftMargin: 20
                            Layout.maximumWidth: 120
                            Layout.fillWidth: true
                        }
                    }

                    CustomTable {
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

                        onRowClicked: index => {
                            console.log("Selected row:", index);
                        }
                    }

                    CustomButton {
                        text: qsTr("刪除待處理")
                    }
                }
            }
        }
    }
}
