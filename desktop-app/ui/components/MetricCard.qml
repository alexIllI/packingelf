import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Card {
    id: root
    property string title: ""
    property string unit: ""
    property int value: ""
    property url iconSource: ""
    property color valueColor: Theme.textColor

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.margins: Constants.cardPadding
        spacing: Constants.spMedium

        Image {
            visible: iconSource !== ""
            source: iconSource
            sourceSize.width: 28
            sourceSize.height: 28
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: title
                color: Theme.subtle
                font.pixelSize: Constants.header2FontSize
            }
            Text {
                text: String(value)
                color: valueColor
                font.pixelSize: Constants.header1FontSize
                font.bold: true
            }
            Text {
                text: unit
                color: Theme.subtle
                font.pixelSize: Constants.header3FontSize
            }
        }
    }
}
