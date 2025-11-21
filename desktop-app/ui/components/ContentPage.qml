import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Control {
    id: root

    // Public API
    property string title: ""
    property string subtitle: ""

    // Allow outside to add page content directly
    default property alias content: body.data

    // Page sizing and spacing
    padding: Constants.pagePadding
    implicitWidth: Constants.pageWidth
    implicitHeight: Constants.pageHeight
    background: Rectangle {
        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
    }

    contentItem: ColumnLayout {
        id: homeMainLayout
        anchors.fill: parent
        anchors.margins: Constants.pageMargin
        spacing: Constants.pageGap

        Column {
            id: headerLayout
            spacing: 10
            Layout.bottomMargin: 40
            Layout.topMargin: 50
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.preferredHeight: 70

            Text {
                id: titleText
                color: Theme.header1Color
                text: root.title
                font.pixelSize: Constants.header1FontSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                id: subtitleText
                text: root.subtitle
                color: Theme.headerSubColor
                font.pixelSize: Constants.header3FontSize
                anchors.leftMargin: 3
                elide: Text.ElideRight
            }
        }
        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
