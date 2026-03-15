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
                            placeholderText: "PG024"
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

                    ListModel {
                        id: printedOrderModel
                        ListElement {
                            date: "2026/03/13"
                            orderNumber: "PG02491384"
                            invoiceNumber: "AB1234567"
                            accountName: "王小明"
                            status: "success"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/03/12"
                            orderNumber: "PG02458271"
                            invoiceNumber: "CD9876543"
                            accountName: "李大華"
                            status: "close"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/11"
                            orderNumber: "PG02430592"
                            invoiceNumber: "EF5678901"
                            accountName: "張美玲"
                            status: "return"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/03/10"
                            orderNumber: "PG02417846"
                            invoiceNumber: "GH2345678"
                            accountName: "陳志偉"
                            status: "success"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/09"
                            orderNumber: "PG02463019"
                            invoiceNumber: "IJ8901234"
                            accountName: "林淑芬"
                            status: "success"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/03/08"
                            orderNumber: "PG02475230"
                            invoiceNumber: "KL3456789"
                            accountName: "黃建國"
                            status: "close"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/07"
                            orderNumber: "PG02488412"
                            invoiceNumber: "MN0123456"
                            accountName: "吳雅婷"
                            status: "success"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/06"
                            orderNumber: "PG02442687"
                            invoiceNumber: "OP6789012"
                            accountName: "趙國強"
                            status: "return"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/03/05"
                            orderNumber: "PG02451093"
                            invoiceNumber: "QR4567890"
                            accountName: "周家豪"
                            status: "success"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/04"
                            orderNumber: "PG02429758"
                            invoiceNumber: "ST1234098"
                            accountName: "許雅琪"
                            status: "close"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/03/03"
                            orderNumber: "PG02486321"
                            invoiceNumber: "UV7890123"
                            accountName: "鄭明哲"
                            status: "success"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/02"
                            orderNumber: "PG02413574"
                            invoiceNumber: "WX3456012"
                            accountName: "蔡佳蓉"
                            status: "return"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/03/01"
                            orderNumber: "PG02467890"
                            invoiceNumber: "YZ8901567"
                            accountName: "劉冠廷"
                            status: "success"
                            usingCoupon: "yes"
                        }
                        ListElement {
                            date: "2026/02/28"
                            orderNumber: "PG02424156"
                            invoiceNumber: "AC2345891"
                            accountName: "楊詩涵"
                            status: "close"
                            usingCoupon: "no"
                        }
                        ListElement {
                            date: "2026/02/27"
                            orderNumber: "PG02495043"
                            invoiceNumber: "BD6780345"
                            accountName: "謝宗翰"
                            status: "success"
                            usingCoupon: "yes"
                        }
                    }

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

                        model: printedOrderModel

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
                    Rectangle {
                        id: pendingTableTemp
                        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                        border.color: Theme.borderColor
                        Layout.fillHeight: true
                        Layout.fillWidth: true
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
