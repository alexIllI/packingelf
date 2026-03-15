import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: settingView
    anchors.fill: parent
    title: qsTr("設定")
    subtitle: qsTr("管理應用程式設定")

    ColumnLayout {
        id: columnLayout1
        anchors.fill: parent
        anchors.margins: 10

        Rectangle {
            id: tab
            color: Theme.backgroundColor
            radius: 15
            border.color: Theme.borderColor
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            ColumnLayout {
                id: columnLayout
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                Text {
                    id: orderPrefixHeader3
                    color: Theme.header3Color
                    text: qsTr("貨單前綴")
                    font.pixelSize: Constants.header3FontSize
                }

                Rectangle {
                    id: prefixTab
                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                    radius: 15
                    border.color: Theme.borderColor
                    ColumnLayout {
                        id: prefixFrame
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        Text {
                            id: infoHeader3
                            color: Theme.header3Color
                            text: qsTr("以下的數字將作為貨單前缀的基準,列印頁面將顯示當前數字、前一個及下面三個數字。")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Text {
                            id: currentPrefixHeader3
                            color: Theme.header3Color
                            text: qsTr("目前貨單前綴")
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomSpinBox {
                            id: prefixSpinBox
                            value: 24
                            from: 0
                            to: 99
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        }

                        Text {
                            id: prefixPreviewTitleHeader3
                            color: Theme.header3Color
                            text: qsTr("貨單前綴預覽")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Text {
                            id: prefixPreviewHeader3
                            color: Theme.header3Color
                            text: qsTr("列印頁面將顯示以下貨單前綴選項:")
                            font.pixelSize: Constants.header3FontSize
                        }

                        RowLayout {
                            id: prefixPreviewFrame
                            Rectangle {
                                id: prefix1
                                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                radius: 15
                                border.color: Theme.borderColor
                                Text {
                                    id: prefix1Header3
                                    x: 45
                                    y: 25
                                    color: Theme.header3Color
                                    text: qsTr("023")
                                    font.pixelSize: Constants.header3FontSize
                                }
                                Layout.preferredWidth: 113
                                Layout.preferredHeight: 66
                            }

                            Rectangle {
                                id: prefix2
                                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                radius: 15
                                border.color: Theme.borderColor
                                Text {
                                    id: prefix2Header3
                                    x: 45
                                    y: 25
                                    color: Theme.header3Color
                                    text: qsTr("024")
                                    font.pixelSize: Constants.header3FontSize
                                }
                                Layout.preferredWidth: 113
                                Layout.preferredHeight: 66
                            }

                            Rectangle {
                                id: prefix3
                                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                radius: 15
                                border.color: Theme.borderColor
                                Text {
                                    id: prefix3Header3
                                    x: 45
                                    y: 25
                                    color: Theme.header3Color
                                    text: qsTr("025")
                                    font.pixelSize: Constants.header3FontSize
                                }
                                Layout.preferredWidth: 113
                                Layout.preferredHeight: 66
                            }

                            Rectangle {
                                id: prefix4
                                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                radius: 15
                                border.color: Theme.borderColor
                                Text {
                                    id: prefix4Header3
                                    x: 45
                                    y: 25
                                    color: Theme.header3Color
                                    text: qsTr("026")
                                    font.pixelSize: Constants.header3FontSize
                                }
                                Layout.preferredWidth: 113
                                Layout.preferredHeight: 66
                            }

                            Rectangle {
                                id: prefix5
                                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                radius: 15
                                border.color: Theme.borderColor
                                Text {
                                    id: prefix5Header3
                                    x: 45
                                    y: 25
                                    color: Theme.header3Color
                                    text: qsTr("027")
                                    font.pixelSize: Constants.header3FontSize
                                }
                                Layout.preferredWidth: 113
                                Layout.preferredHeight: 66
                            }
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        }
                    }
                    Layout.preferredWidth: 886
                    Layout.preferredHeight: 519
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
            Layout.preferredWidth: 929
            Layout.preferredHeight: 583
        }

        RowLayout {
            id: buttonFrame
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            CustomButton {
                id: resetButton
                text: qsTr("重置預設")
            }

            CustomButton {
                id: cancelButton
                text: qsTr("取消")
            }

            CustomButton {
                id: saveButton
                text: qsTr("儲存變更")
                highlighted: true
            }
        }
    }
}
