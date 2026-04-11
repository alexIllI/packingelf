import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: settingView
    anchors.fill: parent
    title: qsTr("設定")
    subtitle: qsTr("管理列印頁面的預設貨單前綴")

    readonly property int defaultPrefix: 24
    readonly property int minPrefix: 2
    readonly property int maxPrefix: 997
    readonly property int savedPrefix: AppSettings ? AppSettings.orderPrefix : defaultPrefix
    readonly property bool hasUnsavedChanges: prefixSpinBox.value !== savedPrefix

    function formatPrefix(prefix) {
        return Number(prefix).toString().padStart(3, "0");
    }

    function previewPrefixAt(offset) {
        return formatPrefix(prefixSpinBox.value + offset);
    }

    Component.onCompleted: {
        prefixSpinBox.value = savedPrefix;
    }

    Connections {
        target: AppSettings
        function onOrderPrefixChanged() {
            prefixSpinBox.value = AppSettings.orderPrefix;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        Rectangle {
            color: Theme.backgroundColor
            radius: 15
            border.color: Theme.borderColor
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Text {
                    color: Theme.header3Color
                    text: qsTr("貨單前綴")
                    font.pixelSize: Constants.header3FontSize
                }

                Rectangle {
                    color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                    radius: 15
                    border.color: Theme.borderColor
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Text {
                            color: Theme.header3Color
                            text: qsTr("請選擇中間的前綴號碼，列印頁面會自動顯示前兩個與後兩個可選項目。")
                            font.pixelSize: Constants.header3FontSize
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("目前預設值：") + formatPrefix(savedPrefix)
                            font.pixelSize: Constants.header3FontSize
                        }

                        CustomSpinBox {
                            id: prefixSpinBox
                            value: settingView.defaultPrefix
                            valueText: settingView.formatPrefix(value)
                            from: settingView.minPrefix
                            to: settingView.maxPrefix
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("預覽")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("列印頁面會顯示以下五個前綴，並預設選取中間值。")
                            font.pixelSize: Constants.header3FontSize
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            Repeater {
                                model: 5

                                delegate: Rectangle {
                                    required property int index

                                    readonly property bool isSelected: index === 2
                                    color: isSelected
                                        ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.18)
                                        : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                                    radius: 15
                                    border.color: isSelected ? Theme.primaryColor : Theme.borderColor
                                    border.width: isSelected ? 2 : 1
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 72

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: Theme.header3Color
                                            text: settingView.previewPrefixAt(index - 2)
                                            font.pixelSize: Constants.header3FontSize
                                            font.bold: isSelected
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: Theme.headerSubColor
                                            text: isSelected ? qsTr("預設") : qsTr("選項")
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            color: Theme.headerSubColor
                            text: qsTr("設定檔位置：") + (AppSettings ? AppSettings.configFilePath : "")
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom

            CustomButton {
                text: qsTr("重設")
                onClicked: {
                    prefixSpinBox.value = settingView.defaultPrefix;
                }
            }

            CustomButton {
                text: qsTr("取消")
                enabled: settingView.hasUnsavedChanges
                onClicked: {
                    prefixSpinBox.value = settingView.savedPrefix;
                }
            }

            CustomButton {
                text: qsTr("儲存")
                highlighted: true
                enabled: settingView.hasUnsavedChanges
                onClicked: {
                    AppSettings.setOrderPrefix(prefixSpinBox.value);
                }
            }
        }
    }
}
