import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: printingView
    anchors.fill: parent

    title: qsTr("Printing")
    subtitle: qsTr("Create a scrape job and review finalized orders")

    property string inputError: ""
    property string lastResult: ""
    readonly property var prefixOptions: AppSettings ? AppSettings.printingPrefixOptions : ["PG022", "PG023", "PG024", "PG025", "PG026"]

    function defaultPrefixText() {
        return prefixOptions.length >= 3 ? prefixOptions[2] : "PG024";
    }

    function resetPrefixDropdowns() {
        var defaultIndex = Math.min(2, Math.max(0, prefixOptions.length - 1));
        prefixDropdown.currentIndex = defaultIndex;
        pendingPrefixDropdown.currentIndex = defaultIndex;
    }

    Component.onCompleted: {
        resetPrefixDropdowns();
    }

    Connections {
        target: ScraperSvc
        function onScraperFinished(submissionId, result) {
            if (result.isSuccess) {
                printingView.lastResult = qsTr("Scrape finished.");
            } else {
                printingView.lastResult = qsTr("Scrape failed: ") + result.message;
            }
        }

        function onScraperFailed(submissionId, reason) {
            printingView.lastResult = qsTr("Scrape failed: ") + reason;
        }
    }

    Connections {
        target: AppSettings
        function onOrderPrefixChanged() {
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
                text: qsTr("Create Order")
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
                            text: qsTr("Prefix:")
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
                            text: qsTr("Order suffix:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: orderNumberInput
                            placeholderText: qsTr("Enter the 5 digit suffix")
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("Invoice:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: invoiceNumberInput
                            placeholderText: qsTr("Enter invoice number")
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            text: qsTr("Scrape")
                            highlighted: true
                            enabled: !ScraperSvc.busy
                            onClicked: {
                                var suffix = orderNumberInput.text.trim();
                                var invoice = invoiceNumberInput.text.trim().toUpperCase();
                                var prefix = prefixDropdown.currentText || printingView.defaultPrefixText();
                                printingView.inputError = "";
                                printingView.lastResult = "";

                                var suffixRx = /^\d{5}$/;
                                if (!suffixRx.test(suffix)) {
                                    printingView.inputError = qsTr("Order suffix must be exactly 5 digits, for example 12345.");
                                    return;
                                }

                                var invoiceRx = /^[A-Z]{2}\d{7}$/;
                                if (!invoiceRx.test(invoice)) {
                                    printingView.inputError = qsTr("Invoice must use 2 letters and 7 digits, for example AB1234567.");
                                    return;
                                }

                                var fullOrderNumber = prefix + suffix;
                                if (ScraperSvc.browserState !== 2) {
                                    printingView.inputError = qsTr("Browser is not ready yet. Please wait for the scraper to finish starting.");
                                    return;
                                }

                                var submissionId = OrdersVM.submitForScrape(fullOrderNumber, invoice);
                                if (submissionId.length === 0) {
                                    printingView.inputError = qsTr("Failed to create a scrape submission.");
                                    return;
                                }

                                ScraperSvc.scrape(submissionId, fullOrderNumber);
                                printingView.lastResult = qsTr("Scrape started...");
                                orderNumberInput.text = "";
                                invoiceNumberInput.text = "";
                            }
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
                            text: qsTr("Finalized Orders")
                            font.pixelSize: Constants.header3FontSize
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("Search:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomEntry {
                            id: searchPrintedInput
                            placeholderText: qsTr("Search order number")
                            Layout.preferredWidth: 188
                            Layout.preferredHeight: 36
                        }

                        CustomButton {
                            text: qsTr("Search")
                        }

                        CustomDropdown {
                            placeholderText: qsTr("Sort")
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 38
                        }
                    }

                    CustomTable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: [
                            {
                                title: qsTr("Date"),
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: qsTr("Order Number"),
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: qsTr("Invoice Number"),
                                role: "invoiceNumber",
                                width: 0.2
                            },
                            {
                                title: qsTr("Buyer"),
                                role: "accountName",
                                width: 0.15
                            },
                            {
                                title: qsTr("Status"),
                                role: "status",
                                width: 0.1
                            },
                            {
                                title: qsTr("Coupon"),
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
                            text: qsTr("Reprint")
                            Layout.preferredWidth: 93
                            Layout.preferredHeight: 41
                        }

                        CustomButton {
                            id: deletePrintedButton
                            text: qsTr("Delete")
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
                text: qsTr("Pending Orders")
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
                            text: qsTr("Prefix:")
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
                            text: qsTr("Order suffix:")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: pendingOrderNumberInput
                            placeholderText: qsTr("Enter the 5 digit suffix")
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("Remark")
                            font.pixelSize: Constants.header3FontSize
                            Layout.leftMargin: 24
                        }

                        CustomEntry {
                            id: remarkInput
                            placeholderText: qsTr("Add remark")
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            text: qsTr("Add Pending")
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
                                title: qsTr("Date"),
                                role: "date",
                                width: 0.15
                            },
                            {
                                title: qsTr("Order Number"),
                                role: "orderNumber",
                                width: 0.3
                            },
                            {
                                title: qsTr("Remark"),
                                role: "remark",
                                width: 0.55
                            }
                        ]

                        onRowClicked: index => {
                            console.log("Selected row:", index);
                        }
                    }

                    CustomButton {
                        text: qsTr("Delete Pending")
                    }
                }
            }
        }
    }
}
