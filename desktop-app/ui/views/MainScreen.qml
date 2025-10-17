// MainScreen.qml (excerpt)
import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

RowLayout {
    anchors.fill: parent
    spacing: 0

    // Sidebar
    ColumnLayout {
        id: sidebar
        Layout.preferredWidth: 80
        spacing: 6
        anchors.margins: 5

        Item {
            id: logoSlot
            Layout.fillWidth: true
            Layout.leftMargin: 5
            Layout.rightMargin: 5
            Layout.topMargin: 8
            Layout.bottomMargin: 20
            // adapt height to width; clamp between min/max
            readonly property int minLogoHeight: 64
            readonly property int maxLogoHeight: 140
            // pick a ratio that feels right for your SVG in the sidebar
            readonly property real heightByWidth: 109 / 112
            Layout.preferredHeight: Math.max(minLogoHeight, Math.min(maxLogoHeight, Math.round(width * heightByWidth)))
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

            Image {
                id: meridian
                anchors.centerIn: parent
                // keep aspect ratio; Image handles SVG fine
                source: "../assets/images/meridian.svg"
                fillMode: Image.PreserveAspectFit
                // logical size you want on screen:
                readonly property int logicalW: parent.width > 0 ? parent.width : 28
                readonly property int logicalH: parent.height > 0 ? parent.height : 28
                width: logicalW
                height: logicalH

                // match sourceSize to *device* pixels to avoid any post-scaling:
                readonly property real dpr: Screen.devicePixelRatio
                sourceSize.width: Math.round(width * dpr)
                sourceSize.height: Math.round(height * dpr)
                asynchronous: true
                cache: true
                smooth: true

                // Accessibility
                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("Meridian logo")

                // Optional: subtle fallback if image missing
                onStatusChanged: if (status === Image.Error)
                    console.warn("Logo image not found:", source)
            }
        }

        NavButton {
            text: qsTr("首頁")
            icon.source: "../assets/images/home.svg"
            route: "Home"
            Layout.fillWidth: true
        }
        NavButton {
            text: qsTr("列印出貨單")
            icon.source: "../assets/images/printing.svg"
            route: "Printing"
            Layout.fillWidth: true
        }
        NavButton {
            text: qsTr("歷史紀錄")
            icon.source: "../assets/images/history.svg"
            route: "History"
            Layout.fillWidth: true
        }
        NavButton {
            text: qsTr("設定")
            icon.source: "../assets/images/settings.svg"
            route: "Settings"
            Layout.fillWidth: true
        }

        Item {
            Layout.fillHeight: true
        } // spacer

        // TODO: Profile page
        // NavButton {
        //     text: qsTr("個人檔案")
        //     icon: "../assets/images/profile.svg"
        //     route: "Profile"
        //     Layout.fillWidth: true
        //     implicitHeight: 85
        // }
    }

    // Page area
    StackLayout {
        id: pages
        Layout.preferredWidth: Constants.pageWidth
        Layout.preferredHeight: Constants.pageHeight

        // Map route → index
        property var routes: ["Home", "Printing", "History", "Settings", "Profile"]
        currentIndex: {
            const i = routes.indexOf(NavStore.route);
            i >= 0 ? i : 0;
        }

        // Lazy-load each page only when selected
        Loader {
            asynchronous: true
            active: pages.currentIndex === 0
            source: "HomePage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        // TODO: Implement lazy loading for other pages
        // Loader {
        //     asynchronous: true
        //     active: pages.currentIndex === 1
        //     source: "pages/PrintingPage.qml"
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }
        // Loader {
        //     asynchronous: true
        //     active: pages.currentIndex === 2
        //     source: "pages/HistoryPage.qml"
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }
        // Loader {
        //     asynchronous: true
        //     active: pages.currentIndex === 3
        //     source: "pages/SettingsPage.qml"
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }

        // TODO: Profile page
        // Loader {
        //     asynchronous: true
        //     active: pages.currentIndex === 4
        //     source: "pages/ProfilePage.qml"
        //     Layout.fillWidth: true
        //     Layout.fillHeight: true
        // }
    }
}
