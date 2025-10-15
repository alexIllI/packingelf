// ui/views/MainScreen.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Item {
    id: root
    width: Constants.width
    height: Constants.height

    RowLayout {
        anchors.fill: parent
        spacing: 5

        Sidebar {
            id: sidebar
            Layout.preferredWidth: 90
            Layout.fillHeight: true
        }

        // Content area
        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            anchors.margins: 5

            sourceComponent: Store.NavStore.currentPage === Store.NavStore.Page.Home ? homeComp : Store.NavStore.currentPage === Store.NavStore.Page.Printing ? printingComp : Store.NavStore.currentPage === Store.NavStore.Page.History ? historyComp : Store.NavStore.currentPage === Store.NavStore.Page.Setting ? settingComp : profileComp
        }

        // Pages (stubs; replace with your real page QML)
        Component {
            id: homeComp
            // You can migrate your HomePage.ui.qml content into this HomePage.qml
            // and simply instantiate HomePage{} here.
            Item {
                anchors.fill: parent
                Text {
                    anchors.centerIn: parent
                    text: "Home Page"
                    color: "white"
                }
            }
        }
        Component {
            id: printingComp
            Item {
                anchors.fill: parent
                Text {
                    anchors.centerIn: parent
                    text: "Printing"
                    color: "white"
                }
            }
        }
        Component {
            id: historyComp
            Item {
                anchors.fill: parent
                Text {
                    anchors.centerIn: parent
                    text: "History"
                    color: "white"
                }
            }
        }
        Component {
            id: settingComp
            Item {
                anchors.fill: parent
                Text {
                    anchors.centerIn: parent
                    text: "Settings"
                    color: "white"
                }
            }
        }
        Component {
            id: profileComp
            Item {
                anchors.fill: parent
                Text {
                    anchors.centerIn: parent
                    text: "Profile"
                    color: "white"
                }
            }
        }
    }
}
