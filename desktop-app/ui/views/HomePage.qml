import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Item {
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

    // background: Rectangle {
    //     anchors.fill: parent
    //     color: Theme.backgroundColor // colors from Theme
    // }

    ColumnLayout {
        id: homeMainLayout
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: Constants.pageGap

        Column {
            id: titleLayout
            Layout.bottomMargin: 40
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.topMargin: 50
            Layout.fillWidth: true
            spacing: 10
            Text {
                id: homeHeader1
                color: Theme.header1Color
                text: qsTr("首頁")
                font.pixelSize: Constants.header1FontSize
                font.bold: true
            }

            Text {
                id: homeHeaderSub
                color: Theme.headerSubColor
                text: qsTr("檢視包貨小精靈狀態")
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 3
                font.pixelSize: Constants.header3FontSize
            }

            Layout.preferredHeight: 70
        }

        // ─────────────────────────────────────────────────────────────
        // Dashboard Layout
        // ─────────────────────────────────────────────────────────────
        RowLayout {
            id: dashboardLayout
            spacing: Constants.pageGap // 20
            Rectangle {
                id: orderPanel
                color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
                radius: 15
                border.color: Constants.borderColor
                border.width: 1
                Layout.minimumHeight: 135
                Layout.fillWidth: true
                RowLayout {
                    id: orderFrame
                    visible: true
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    uniformCellSizes: true
                    MetricCard {
                        title: "全部貨單數量"
                        value: totalOrders
                        unit: "件"
                        iconSource: "images/total_orders.svg"
                    }
                    MetricCard {
                        title: "標記貨單數量"
                        value: pendingOrders
                        unit: "件"
                        iconSource: "images/pending.svg"
                    }
                    MetricCard {
                        title: "今日貨單數量"
                        value: todayProcessed
                        unit: "件"
                        iconSource: "images/record.svg"
                    }
                }
            }
            Rectangle {
                id: statusPanel
                color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
                radius: 15
                border.color: Constants.borderColor
                border.width: 1
                Layout.minimumHeight: 135
                Layout.fillWidth: true
                RowLayout {
                    id: statusFrame
                    visible: true
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    uniformCellSizes: true
                    MetricCard {
                        title: "錯誤"
                        value: errorJobs
                        unit: "件"
                        iconSource: "images/total_orders.svg"
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
            Rectangle {
                id: appStatusPanel
                width: 200
                color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
                radius: 15
                border.color: Constants.borderColor
                Layout.preferredWidth: 300
                Layout.minimumWidth: 300
                Layout.fillHeight: true
                Layout.fillWidth: true

                ColumnLayout {
                    id: appStatusFrame
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 5
                    Text {
                        id: home_AppStatusHeader2
                        color: Constants.header2Color
                        text: qsTr("包貨小精靈狀態")
                        font.pixelSize: Constants.header2FontSize
                        Layout.bottomMargin: 10
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    Text {
                        id: home_AppStatusHeader3
                        color: Constants.header2Color
                        text: qsTr("工作階段:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    RowLayout {
                        id: descriptionFrame
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.maximumHeight: 30
                        BusyIndicator {
                            id: home_AppBusyIndicator
                            visible: true
                            Layout.minimumHeight: 30
                            Layout.minimumWidth: 30
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 30
                        }

                        Text {
                            id: home_StatusDescriptionHeader3
                            color: Constants.header2Color
                            text: qsTr("正在連線到買動漫")
                            font.pixelSize: Constants.header3FontSize
                            Layout.minimumWidth: 100
                            Layout.fillHeight: false
                            Layout.fillWidth: false
                            Layout.preferredHeight: 17
                        }
                    }

                    ProgressBar {
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
                        color: Constants.header2Color
                        text: qsTr("70 %")
                        font.pixelSize: Constants.header3FontSize
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 17
                    }

                    Text {
                        id: home_ConsoleOutputHeader3
                        color: Constants.header3Color
                        text: qsTr("Console Output:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    RowLayout {
                        id: consoleFrame
                        Layout.fillWidth: true
                        CustomDropdown {
                            id: home_ConsoleDropdown
                            Layout.preferredHeight: 30
                            selected: "全部"
                        }

                        Button {
                            id: home_ClearConsoleButton
                            text: qsTr("清除")
                            Layout.preferredHeight: 40
                            Layout.minimumHeight: 40
                        }

                        Button {
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

            Rectangle {
                id: webControlPanel
                width: 200
                color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
                radius: 15
                border.color: Constants.borderColor
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
                        color: Constants.header2Color
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
                            color: Constants.header3Color
                            text: qsTr("目前狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator
                            color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
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
                                    color: Constants.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: home_MyacgCurStatusHeader3
                                    color: Constants.header3Color
                                    text: qsTr("online")
                                    font.pixelSize: Constants.header3FontSize
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }
                            }
                        }
                    }

                    Text {
                        id: home_WebExcutingHeader3
                        color: Constants.header3Color
                        text: qsTr("目前執行:")
                        font.pixelSize: Constants.header3FontSize
                    }

                    Text {
                        id: home_WebExcutedCommandHeader3
                        color: Constants.header3Color
                        text: qsTr("搜尋貨單...")
                        font.pixelSize: Constants.header3FontSize
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    RowLayout {
                        id: webControlButtonFrame
                        Layout.fillWidth: true
                        Button {
                            id: home_WebRestartButton
                            text: qsTr("重新啟動")
                            Layout.fillWidth: true
                            Layout.minimumHeight: 35
                            Layout.minimumWidth: 85
                        }

                        Button {
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
                            color: Constants.header3Color
                            text: qsTr("佇列中的工作:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CheckBox {
                            id: home_ShowWebOutputCheckBox
                            text: qsTr("顯示")
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        }
                    }

                    Text {
                        id: home_TaskListHeader3
                        color: Constants.header3Color
                        text: qsTr("列印 PG01234567")
                        font.pixelSize: Constants.header3FontSize
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }
                }
            }
            Rectangle {
                id: hostDBPanel
                width: 200
                color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
                radius: 15
                border.color: Constants.borderColor
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
                        color: Constants.header2Color
                        text: qsTr("資料庫狀態")
                        font.pixelSize: Constants.header2FontSize
                        Layout.bottomMargin: 10
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    RowLayout {
                        id: hostDBStatusFrame
                        Text {
                            id: home_HostDBStatus_Header3
                            color: Constants.header3Color
                            text: qsTr("遠端資料庫連線狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator1
                            color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
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
                                    color: Constants.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: hostdbstatus
                                    color: Constants.header3Color
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
                        Button {
                            id: home_HostDBTestButton
                            text: qsTr("測試連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }

                        Button {
                            id: home_HostDBReconnectButton
                            text: qsTr("重新連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                        }
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: localDBStatusFrame
                        Text {
                            id: home_LocalDBStatus_Header3
                            color: Constants.header3Color
                            text: qsTr("本地資料庫連線狀態:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Rectangle {
                            id: home_WebIndicator2
                            color: Qt.rgba(Constants.primaryColor.r, Constants.primaryColor.g, Constants.primaryColor.b, 0.08)
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
                                    color: Constants.goodColor
                                    radius: 5
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                }

                                Text {
                                    id: hostdbstatus1
                                    color: Constants.header3Color
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
                        Button {
                            id: home_LocalDBTestButton
                            text: qsTr("測試連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                        }

                        Button {
                            id: home_LocalDBReconnectButton
                            text: qsTr("重新連線")
                            Layout.minimumWidth: 85
                            Layout.minimumHeight: 35
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                        }
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        id: queuedTaskFrame1
                        spacing: 5
                        Text {
                            id: home_QueuedTaskHeader4
                            color: Constants.header3Color
                            text: qsTr("佇列中的工作:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CheckBox {
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
                        color: Constants.header3Color
                        text: qsTr("POST:")
                        font.pixelSize: Constants.header3FontSize
                        Layout.minimumHeight: 50
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }

                    Button {
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
