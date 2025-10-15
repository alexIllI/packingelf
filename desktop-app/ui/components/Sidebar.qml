// ui/controls/Sidebar.qml
import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

Rectangle {
    id: root
    width: 90
    color: Theme.sidebarColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 8

        // Top logo (from your .ui file)
        Image {
            source: "images/meridian.svg"
            fillMode: Image.PreserveAspectFit
            Layout.preferredHeight: 120
            Layout.fillWidth: true
        }

        // Buttons
        ColumnLayout {
            Layout.fillWidth: true

            // A small model to avoid repetition
            Repeater {
                model: [
                    {
                        label: "首頁",
                        page: NavStore.page.Home,
                        icon: "images/home.svg"
                    },
                    {
                        label: "列印出貨單",
                        page: NavStore.page.Printing,
                        icon: "images/print.svg"
                    },
                    {
                        label: "歷史紀錄",
                        page: NavStore.page.History,
                        icon: "images/history.svg"
                    },
                    {
                        label: "設定",
                        page: NavStore.page.Setting,
                        icon: "images/settings.svg"
                    },
                    {
                        label: "個人資料",
                        page: NavStore.page.Profile,
                        icon: "images/user.svg"
                    }
                ]
                delegate: NavButton {
                    label: model.label
                    iconSource: model.icon
                    checked: Store.NavStore.currentPage === model.page
                    onTriggered: Store.NavStore.currentPage = model.page
                }
            }
        }

        Item {
            Layout.fillHeight: true
        } // spacer

        // Bottom user panel (from your .ui)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            Image {
                source: "images/towa_4.png"
                fillMode: Image.PreserveAspectFit
                Layout.preferredHeight: 54
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "User"
                color: Constants.header2Color
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }
}
