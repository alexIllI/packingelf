import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: historyView
    anchors.fill: parent

    title: qsTr("出貨紀錄")
    subtitle: qsTr("查詢和管理過去的出貨單")

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        spacing: Constants.pageGap

        Text {
            id: filterHeader3
            color: Theme.header3Color
            text: qsTr("過濾選項")
            font.pixelSize: Constants.header3FontSize
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        }

        Rectangle {
            id: filterFrame
            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
            radius: 15
            border.color: Theme.borderColor
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.minimumHeight: 150
            Layout.fillWidth: true

            ColumnLayout {
                id: columnLayout1
                anchors.fill: parent
                anchors.margins: 10
                spacing: 0
                RowLayout {
                    id: orderNumberPanel
                    spacing: 15
                    CustomEntry {
                        id: searchInput
                        placeholderText: qsTr("請輸入欲搜尋的完整貨單號碼")
                        Layout.fillWidth: true
                    }

                    CustomButton {
                        id: searchCustomButton
                        text: qsTr("搜尋")
                        highlighted: true
                        Layout.maximumWidth: 88
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    id: filterPanel
                    spacing: 15
                    Layout.fillWidth: true
                    Text {
                        id: fromDateHeader3
                        color: Theme.header3Color
                        text: qsTr("從 ")
                        font.pixelSize: Constants.header3FontSize
                        Layout.fillWidth: true
                    }

                    CustomDropdown {
                        id: fromDateCombobox
                        Layout.fillWidth: true
                    }

                    Text {
                        id: toDateHeader3
                        color: Theme.header3Color
                        text: qsTr("到 ")
                        font.pixelSize: Constants.header3FontSize
                        Layout.leftMargin: 30
                    }

                    CustomDropdown {
                        id: toDateComboBox
                        Layout.fillWidth: true
                    }

                    Text {
                        id: orderStatusHeader3
                        color: Theme.header3Color
                        text: qsTr("狀態 ")
                        font.pixelSize: Constants.header3FontSize
                        Layout.fillWidth: true
                        Layout.leftMargin: 50
                    }

                    CustomDropdown {
                        id: orderStatusDropdown
                        placeholderText: "全部"
                        Layout.fillWidth: true
                        Layout.maximumWidth: 120
                    }

                    CustomButton {
                        id: applyFilterCustomButton
                        text: qsTr("套用篩選")
                        highlighted: true
                        Layout.fillWidth: true
                        Layout.maximumWidth: 120
                        Layout.leftMargin: 60
                    }

                    CustomButton {
                        id: resetFilterCustomButton
                        text: qsTr("重置")
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Rectangle {
            id: tmptable
            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
            border.color: Theme.borderColor
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.minimumHeight: 200
            Layout.fillWidth: true
        }

        RowLayout {
            id: deleteAndInfoFrame
            Layout.alignment: Qt.AlignLeft | Qt.AlignBottom
            CustomButton {
                id: deleteCustomButton
                text: qsTr("刪除")
            }

            Text {
                id: diplayOrderCountHeader3
                color: Theme.header3Color
                text: qsTr("共顯示2904筆貨單")
                font.pixelSize: Constants.header3FontSize
            }
        }
    }
}
