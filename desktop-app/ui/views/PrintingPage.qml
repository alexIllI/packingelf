import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: printingView
    anchors.fill: parent

    title: qsTr("列印出貨單")
    subtitle: qsTr("建立和管理出貨單")

    // ── local state ─────────────────────────────────────────────────
    property string inputError: ""          // validation error message
    property string lastResult: ""          // last scrape result summary

    // Connect ScraperSvc signals once (Connections block)
    Connections {
        target: ScraperSvc
        function onScraperFinished(orderId, result) {
            if (result.isSuccess) {
                printingView.lastResult = qsTr("列印成功 ✔")
            } else {
                printingView.lastResult = qsTr("列印失敗: ") + result.message
            }
        }
        function onScraperFailed(orderId, reason) {
            printingView.lastResult = qsTr("錢誤: ") + reason
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
            spacing: 5
            uniformCellSizes: false
            Text {
                id: printingHeader3
                color: Theme.header3Color
                text: qsTr("列印出貨單")
                font.pixelSize: Constants.header3FontSize
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }

            Rectangle {
                id: printingPanel
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                radius: 15
                border.color: Theme.borderColor
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                Layout.minimumHeight: 400
                Layout.preferredWidth: 919
                Layout.preferredHeight: 418

                ColumnLayout {
                    id: printingFrame
                    anchors.fill: parent
                    anchors.margins: 10
                    RowLayout {
                        id: printingInputFrame
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            id: prefixHeader3
                            color: Theme.header3Color
                            text: qsTr("前綴:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomDropdown {
                            id: prefixDropdown
                            // Common myACG seller order prefixes
                            model: ["PG024", "PG025", "PG026", "PG027"]
                            Layout.fillWidth: true
                            Layout.maximumWidth: 80
                        }

                        Text {
                            id: orderNumberHeader3
                            color: Theme.header3Color
                            text: qsTr("貨單號碼:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 50
                        }

                        CustomEntry {
                            id: orderNumberInput
                            placeholderText: qsTr("請輸入貨單後五碼")
                            Layout.fillWidth: true
                        }

                        Text {
                            id: invoiceNumberHeader3
                            color: Theme.header3Color
                            text: qsTr("發票號碼:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 50
                        }

                        CustomEntry {
                            id: invoiceNumberInput
                            placeholderText: qsTr("請輸入發票號碼")
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            id: printButton
                            text: qsTr("列印")
                            highlighted: true
                            enabled: !ScraperSvc.busy
                            onClicked: {
                                // ─ 1. Get raw inputs ────────────────────────────
                                var suffix  = orderNumberInput.text.trim();
                                var invoice = invoiceNumberInput.text.trim().toUpperCase();
                                var prefix  = prefixDropdown.currentText || "PG024";
                                printingView.inputError = "";
                                printingView.lastResult = "";

                                // ─ 2. Validate order suffix: exactly 5 digits ───────────
                                var suffixRx = /^\d{5}$/;
                                if (!suffixRx.test(suffix)) {
                                    printingView.inputError =
                                        qsTr("貨單後五碼必須為 5 位數字（例：12345）");
                                    return;
                                }

                                // ─ 3. Validate invoice: 2 letters + 7 digits ──────────
                                var invoiceRx = /^[A-Z]{2}\d{7}$/;
                                if (!invoiceRx.test(invoice)) {
                                    printingView.inputError =
                                        qsTr("發票號碼格式錯誤，應為 2 英文字母 + 7 位數字（例：AB1234567）");
                                    return;
                                }

                                // ─ 4. Build full order number ──────────────────────
                                var fullOrderNumber = prefix + suffix;

                                // ─ 5. Check browser is ready ──────────────────────
                                // browserState: 2 = Ready
                                if (ScraperSvc.browserState !== 2) {
                                    printingView.inputError =
                                        qsTr("瀏覽器未就緒，請到首頁點擊「重新啟動」")
                                    return;
                                }

                                // ─ 6. Create order in DB, then trigger scraper ───────
                                var id = OrdersVM.createOrder(fullOrderNumber, invoice);
                                if (id.length === 0) {
                                    printingView.inputError = qsTr("建立資料庭檔失敗");
                                    return;
                                }

                                // Trigger scraper daemon
                                ScraperSvc.scrape(id, fullOrderNumber);
                                printingView.lastResult = qsTr("列印中…")

                                // Clear inputs for next entry
                                orderNumberInput.text = "";
                                invoiceNumberInput.text = "";
                            }
                        }

                        // Busy spinner while scraper is running
                        CustomBusyIndicator {
                            id: printBusyIndicator
                            visible: ScraperSvc.busy
                            running: ScraperSvc.busy
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                        }
                    }

                    // ─ Validation / result feedback row ───────────────────
                    RowLayout {
                        id: printFeedbackRow
                        Layout.fillWidth: true
                        visible: printingView.inputError !== "" || printingView.lastResult !== ""
                        Text {
                            id: printFeedbackText
                            text: printingView.inputError !== ""
                                  ? printingView.inputError
                                  : printingView.lastResult
                            color: printingView.inputError !== "" ? "#ff6060" : Theme.goodColor
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    ToolSeparator {
                        id: printingSeparator
                        Layout.fillWidth: true
                        orientation: Qt.Horizontal
                    }

                    RowLayout {
                        id: rowLayout
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            id: printedOrderHeader3
                            color: Theme.header3Color
                            text: qsTr("已列印的貨單")
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                        }

                        Text {
                            id: searchprintedHeader3
                            color: Theme.header3Color
                            text: qsTr("搜尋已列印的貨單:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }

                        CustomEntry {
                            id: searchPrintedInput
                            placeholderText: qsTr("請輸入完整貨單")
                            Layout.preferredWidth: 188
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }

                        CustomButton {
                            id: searchPrintedButton
                            text: qsTr("清除")
                        }

                        CustomDropdown {
                            id: customDropdown
                            placeholderText: "全部"
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 38
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                    }

                    // Model is provided by OrdersVM (C++ context property)

                    CustomTable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: [
                            {
                                title: "日期",
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: "貨單號碼",
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: "發票號碼",
                                role: "invoiceNumber",
                                width: 0.2
                            },
                            {
                                title: "帳號名稱",
                                role: "accountName",
                                width: 0.15
                            },
                            {
                                title: "出貨狀態",
                                role: "status",
                                width: 0.1
                            },
                            {
                                title: "優惠券",
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
                        id: printingTableButtonFrame
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        CustomButton {
                            id: reprintButton
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
                                // Use the CustomTable's currentIndex
                                var table = deletePrintedButton.parent.parent.children[3]; // the CustomTable
                                // For now just remove by currentIndex if set
                                // TODO: get proper selected index from table
                                console.log("Delete clicked");
                            }
                        }
                    }
                }
            }

            Text {
                id: pendingHeader3
                color: Theme.header3Color
                text: qsTr("標記貨單")
                font.pixelSize: Constants.header3FontSize
                Layout.topMargin: 35
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }

            Rectangle {
                id: pendingPanel
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                radius: 15
                border.color: Theme.borderColor
                Layout.minimumHeight: 300
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                Layout.preferredWidth: 919
                Layout.preferredHeight: 273

                ColumnLayout {
                    id: pendingFrame
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 10

                    RowLayout {
                        id: pendingInputFrame
                        spacing: 10
                        Text {
                            id: pendingPrefixHeader3
                            color: Theme.header3Color
                            text: qsTr("前綴:")
                            Layout.fillWidth: true
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomDropdown {
                            id: pendingPrefixDropdown
                            placeholderText: "PG024"
                            Layout.fillWidth: true
                            Layout.maximumWidth: 80
                        }

                        Text {
                            id: pendingOrderNumberHeader3
                            color: Theme.header3Color
                            text: qsTr("貨單號碼:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 50
                            Layout.fillWidth: true
                        }

                        CustomEntry {
                            id: pendingOrderNumberInput
                            placeholderText: qsTr("請輸入貨單後五碼")
                            Layout.fillWidth: true
                        }

                        Text {
                            id: remarkHeader3
                            color: Theme.header3Color
                            text: qsTr("備註")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 50
                            Layout.fillWidth: true
                        }

                        CustomEntry {
                            id: remarkInput
                            placeholderText: qsTr("請輸入備註")
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            id: addPendingButton
                            text: qsTr("新增標記")
                            highlighted: true
                            Layout.leftMargin: 20
                            Layout.maximumWidth: 120
                            Layout.fillWidth: true
                        }
                    }
                    CustomTable {
                        id: pendingTableTemp
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        columns: [
                            {
                                title: "日期",
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: "貨單號碼",
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: "備註",
                                role: "remark",
                                width: 0.55
                            }
                        ]

                        onRowClicked: index => {
                            console.log("Selected row:", index);
                        }
                    }

                    CustomButton {
                        id: deletePendingButton
                        text: qsTr("刪除標記")
                    }
                }
            }
        }
    }
}
