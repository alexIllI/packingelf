import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: homeView
    anchors.fill: parent

    // connect these to your ViewModels later
    // e.g., via property var dashboardVM: DashboardVM
    // for now use placeholders matching your original UI:
    property int totalOrders: 4696
    property int pendingOrders: 17
    property int todayProcessed: 312
    property int errorJobs: 5
    property bool hostDbOnline: true
    property bool localDbOnline: true

    title: qsTr("首頁")
    subtitle: qsTr("檢視包貨小精靈狀態")

    ColumnLayout {
        id: homeMainLayout
        anchors.fill: parent
        spacing: Constants.pageGap

        // ─────────────────────────────────────────────────────────────
        // Dashboard Layout
        // ─────────────────────────────────────────────────────────────
        RowLayout {
            id: dashboardLayout
            spacing: Constants.pageGap // 20
            Card {
                id: orderPanel
                Layout.minimumHeight: 135
                Layout.fillWidth: true
                RowLayout {
                    id: orderFrame
                    anchors.fill: parent
                    anchors.margins: 10
                    uniformCellSizes: true
                    MetricCard {
                        title: "全部貨單數量"
                        displayValue: homeView.totalOrders
                        unit: "件"
                        iconSource: "../assets/images/total_orders.svg"
                    }
                    MetricCard {
                        title: "標記貨單數量"
                        displayValue: homeView.pendingOrders
                        unit: "件"
                        iconSource: "../assets/images/pending.svg"
                    }
                    MetricCard {
                        title: "今日貨單數量"
                        displayValue: homeView.todayProcessed
                        unit: "件"
                        iconSource: "../assets/images/record.svg"
                    }
                }
            }
            Card {
                id: statusPanel
                Layout.minimumHeight: 135
                Layout.minimumWidth: 250
                RowLayout {
                    id: statusFrame
                    visible: true
                    anchors.fill: parent
                    anchors.margins: 10
                    uniformCellSizes: true
                    MetricCard {
                        title: "錯誤"
                        displayValue: homeView.errorJobs
                        unit: "件"
                        iconSource: "../assets/images/total_orders.svg"
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Data pipelines + Automation + Logs (stubs ok)
        // ─────────────────────────────────────────────────────────────

        RowLayout {
            id: controlLayout
            uniformCellSizes: false
            Layout.minimumHeight: 400
            Layout.fillWidth: true
            spacing: 20
            Card {
                id: appStatusPanel
                width: 200
                Layout.preferredWidth: 300
                Layout.minimumWidth: 300
                Layout.fillHeight: true
                Layout.fillWidth: true

                ColumnLayout {
                    id: appStatusFrame
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5
                    Text {
                        id: home_AppStatusHeader2
                        color: Theme.header2Color
                        text: qsTr("包貨小精靈狀態")
                        font.pixelSize: Constants.header2FontSize
                        Layout.bottomMargin: 10
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    Text {
                        id: home_AppStatusHeader3
                        color: Theme.header2Color
                        text: qsTr("工作階段:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    RowLayout {
                        id: descriptionFrame
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.maximumHeight: 30
                        CustomBusyIndicator {
                            id: home_AppBusyIndicator
                            visible: true
                            running: true
                            Layout.minimumHeight: 30
                            Layout.minimumWidth: 30
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 30
                        }

                        Text {
                            id: home_StatusDescriptionHeader3
                            color: Theme.header2Color
                            text: qsTr("正在連線到買動漫")
                            font.pixelSize: Constants.header3FontSize
                            Layout.minimumWidth: 100
                            Layout.fillHeight: false
                            Layout.fillWidth: false
                            Layout.preferredHeight: 17
                        }
                    }

                    CustomProgressBar {
                        id: home_AppProgressBar
                        value: 0.7
                        Layout.minimumHeight: 15
                        Layout.minimumWidth: 180
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 15
                    }

                    Text {
                        id: home_AppProgressHeader3
                        color: Theme.header2Color
                        text: Math.round(home_AppProgressBar.value * 100) + " %"
                        font.pixelSize: Constants.header3FontSize
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 17
                    }

                    Text {
                        id: home_ConsoleOutputHeader3
                        color: Theme.header3Color
                        text: qsTr("Console Output:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    RowLayout {
                        id: consoleFrame
                        Layout.fillWidth: true
                        CustomDropdown {
                            id: home_ConsoleDropdown
                            Layout.preferredHeight: 40
                        }

                        CustomButton {
                            id: home_ClearConsoleButton
                            text: qsTr("清除")
                            Layout.preferredHeight: 40
                            Layout.minimumHeight: 40
                        }

                        CustomButton {
                            id: home_OpenLogButton
                            text: qsTr("開啟日誌位置")
                            Layout.preferredHeight: 40
                            Layout.minimumHeight: 40
                        }
                    }

                    ScrollView {
                        id: home_ConsoleOutputScrollArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }
                }
            }

            Card {
                id: webControlPanel
                width: 200
                Layout.minimumWidth: 250
                Layout.fillHeight: true

                ColumnLayout {
                    id: webControlFrame
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 10
                    Text {
                        id: home_WebControlHeader2
                        color: Theme.header2Color
                        text: qsTr("網頁控制")
                        font.pixelSize: Constants.header2FontSize
                        Layout.bottomMargin: 10
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.preferredWidth: 78
                        Layout.preferredHeight: 27
                    }

                    RowLayout {
                        id: webStatusFrame
                        Text {
                            id: home_MyacgStatusHeader3
                            color: Theme.header3Color
                            text: qsTr("目前狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator
                            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                            radius: 15
                            Layout.minimumHeight: 25
                            Layout.minimumWidth: 70
                            RowLayout {
                                id: rowLayout
                                anchors.fill: parent
                                anchors.leftMargin: 5
                                anchors.rightMargin: 5
                                anchors.topMargin: 0
                                anchors.bottomMargin: 0
                                Rectangle {
                                    id: home_MyacgIndicator
                                    color: Theme.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: home_MyacgCurStatusHeader3
                                    color: Theme.header3Color
                                    text: qsTr("online")
                                    font.pixelSize: Constants.header3FontSize
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }
                            }
                        }
                    }

                    Text {
                        id: home_WebExcutingHeader3
                        color: Theme.header3Color
                        text: qsTr("目前執行:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    Text {
                        id: home_WebExcutedCommandHeader3
                        color: Theme.header3Color
                        text: qsTr("搜尋貨單...")
                        font.pixelSize: Constants.header3FontSize
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    RowLayout {
                        id: webControlButtonFrame
                        Layout.fillWidth: true
                        CustomButton {
                            id: home_WebRestartButton
                            text: qsTr("重新啟動")
                            Layout.fillWidth: true
                            Layout.minimumHeight: 35
                            Layout.minimumWidth: 85
                        }

                        CustomButton {
                            id: home_WebCalibrateButton
                            text: qsTr("校正")
                            Layout.fillWidth: true
                            Layout.minimumHeight: 35
                            Layout.fillHeight: false
                            Layout.minimumWidth: 85
                        }
                    }

                    RowLayout {
                        id: queuedTaskFrame
                        x: 0
                        y: 196
                        spacing: 30
                        Layout.fillWidth: true
                        Text {
                            id: home_QueuedTaskHeader3
                            color: Theme.header3Color
                            text: qsTr("佇列中的工作:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomCheckBox {
                            id: home_ShowWebOutputCheckBox
                            text: qsTr("顯示")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                    }

                    Text {
                        id: home_TaskListHeader3
                        color: Theme.header3Color
                        text: qsTr("列印 PG01234567")
                        font.pixelSize: Constants.header3FontSize
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }
                }
            }
            Card {
                id: hostDBPanel
                width: 200
                Layout.minimumWidth: 250
                Layout.fillHeight: true

                ColumnLayout {
                    id: hostDBFrame
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    Text {
                        id: home_DBStatusHeader2
                        color: Theme.header2Color
                        text: qsTr("資料庫狀態")
                        font.pixelSize: Constants.header2FontSize
                        Layout.bottomMargin: 10
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    RowLayout {
                        id: hostDBStatusFrame
                        Text {
                            id: home_HostDBStatus_Header3
                            color: Theme.header3Color
                            text: qsTr("遠端資料庫連線狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator1
                            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                            radius: 15
                            RowLayout {
                                id: rowLayout1
                                anchors.fill: parent
                                anchors.leftMargin: 5
                                anchors.rightMargin: 5
                                anchors.topMargin: 0
                                anchors.bottomMargin: 0
                                Rectangle {
                                    id: hostdbIndicator1
                                    color: Theme.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: hostdbstatus
                                    color: Theme.header3Color
                                    text: qsTr("online")
                                    font.pixelSize: Constants.header3FontSize
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }
                            }
                            Layout.minimumWidth: 70
                            Layout.minimumHeight: 25
                        }
                    }

                    RowLayout {
                        id: hostDBButtonFrame
                        CustomButton {
                            id: home_HostDBTestButton
                            text: qsTr("測試連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            id: home_HostDBReconnectButton
                            text: qsTr("重新連線")
                            highlighted: true
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: localDBStatusFrame
                        Text {
                            id: home_LocalDBStatus_Header3
                            color: Theme.header3Color
                            text: qsTr("本地資料庫連線狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator2
                            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                            radius: 15
                            RowLayout {
                                id: rowLayout2
                                anchors.fill: parent
                                anchors.leftMargin: 5
                                anchors.rightMargin: 5
                                anchors.topMargin: 0
                                anchors.bottomMargin: 0
                                Rectangle {
                                    id: hostdbIndicator2
                                    color: Theme.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: hostdbstatus1
                                    color: Theme.header3Color
                                    text: qsTr("online")
                                    font.pixelSize: Constants.header3FontSize
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }
                            }
                            Layout.minimumWidth: 70
                            Layout.minimumHeight: 25
                        }
                    }

                    RowLayout {
                        id: localDBButtonFrame
                        CustomButton {
                            id: home_LocalDBTestButton
                            text: qsTr("測試連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }

                        CustomButton {
                            id: home_LocalDBReconnectButton
                            text: qsTr("重新連線")
                            highlighted: true
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: queuedTaskFrame1
                        spacing: 5
                        Text {
                            id: home_QueuedTaskHeader4
                            color: Theme.header3Color
                            text: qsTr("佇列中的工作:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomCheckBox {
                            id: home_ShowDBOoutputCheckBox
                            text: qsTr("顯示")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                        Layout.preferredWidth: 207
                        Layout.preferredHeight: 48
                        Layout.fillWidth: true
                    }

                    Text {
                        id: home_DBConsoleHeader3
                        color: Theme.header3Color
                        text: qsTr("POST:")
                        font.pixelSize: Constants.header3FontSize
                        Layout.minimumHeight: 50
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }

                    CustomButton {
                        id: home_DBSettingButton
                        text: "更改資料庫設定"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 162
                        Layout.preferredHeight: 33
                    }
                }
            }
        }

        RowLayout {
            id: footerLayout
            Layout.fillWidth: true
            spacing: 20
            Text {
                id: versionHeader3
                color: "#ffffff"
                text: qsTr("version 1.0")
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.rowSpan: 1
            }

            Text {
                id: creditsHeader3
                color: "#ffffff"
                text: qsTr("koorino")
                font.pixelSize: 12
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.rowSpan: 2
            }
        }
    }
}
