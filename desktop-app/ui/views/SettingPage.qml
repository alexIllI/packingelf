import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: settingView
    anchors.fill: parent
    title: qsTr("Settings")
    subtitle: qsTr("Manage the default prefix used by Printing")

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
                    text: qsTr("Order Prefix")
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
                            text: qsTr("Choose the middle prefix. The app will keep two previous and two next options ready for Printing.")
                            font.pixelSize: Constants.header3FontSize
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("Saved default: ") + formatPrefix(savedPrefix)
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
                            text: qsTr("Preview")
                            font.pixelSize: Constants.header3FontSize
                        }

                        Text {
                            color: Theme.header3Color
                            text: qsTr("Printing will show these five prefix choices, with the center value selected by default.")
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
                                            text: isSelected ? qsTr("Default") : qsTr("Option")
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            color: Theme.headerSubColor
                            text: qsTr("Config file: ") + (AppSettings ? AppSettings.configFilePath : "")
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
                text: qsTr("Reset")
                onClicked: {
                    prefixSpinBox.value = settingView.defaultPrefix;
                }
            }

            CustomButton {
                text: qsTr("Cancel")
                enabled: settingView.hasUnsavedChanges
                onClicked: {
                    prefixSpinBox.value = settingView.savedPrefix;
                }
            }

            CustomButton {
                text: qsTr("Save")
                highlighted: true
                enabled: settingView.hasUnsavedChanges
                onClicked: {
                    AppSettings.setOrderPrefix(prefixSpinBox.value);
                }
            }
        }
    }
}
