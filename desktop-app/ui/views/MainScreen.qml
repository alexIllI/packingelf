import QtQuick
import QtQuick.Layouts
import PackingElf 1.0

RowLayout {
    anchors.fill: parent
    spacing: 0

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
            readonly property int minLogoHeight: 64
            readonly property int maxLogoHeight: 140
            readonly property real heightByWidth: 109 / 112
            Layout.preferredHeight: Math.max(minLogoHeight, Math.min(maxLogoHeight, Math.round(width * heightByWidth)))
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

            Image {
                id: meridian
                anchors.centerIn: parent
                source: "../assets/images/meridian.svg"
                fillMode: Image.PreserveAspectFit
                readonly property int logicalW: parent.width > 0 ? parent.width : 28
                readonly property int logicalH: parent.height > 0 ? parent.height : 28
                width: logicalW
                height: logicalH
                readonly property real dpr: Screen.devicePixelRatio
                sourceSize.width: Math.round(width * dpr)
                sourceSize.height: Math.round(height * dpr)
                asynchronous: true
                cache: true
                smooth: true

                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("Meridian logo")

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
            text: qsTr("列印")
            icon.source: "../assets/images/printing.svg"
            route: "Printing"
            Layout.fillWidth: true
        }
        NavButton {
            text: qsTr("歷史")
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
        }
    }

    StackLayout {
        id: pages
        Layout.preferredWidth: Constants.pageWidth
        Layout.preferredHeight: Constants.pageHeight
        Layout.fillWidth: true
        Layout.fillHeight: true

        property var routes: ["Home", "Printing", "History", "Settings", "Profile"]
        currentIndex: {
            const i = routes.indexOf(NavStore.route);
            return i >= 0 ? i : 0;
        }

        Loader {
            asynchronous: true
            active: true
            visible: pages.currentIndex === 0
            source: "HomePage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        Loader {
            asynchronous: true
            active: true
            visible: pages.currentIndex === 1
            source: "PrintingPage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        Loader {
            asynchronous: true
            active: true
            visible: pages.currentIndex === 2
            source: "HistoryPage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        Loader {
            asynchronous: true
            active: true
            visible: pages.currentIndex === 3
            source: "SettingPage.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
