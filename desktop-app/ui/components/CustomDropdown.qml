import QtQuick
import QtQuick.Controls
import Packingelf 1.0

Item {
    id: root
    width: 160
    height: 40

    // public property for current selection
    property string selected: "Select an item"
    // public model (can be list or ListModel)
    property var modelData: ["Apple", "Banana", "Cherry"]

    Rectangle {
        id: button
        anchors.fill: parent
        radius: 5
        color: Qt.rgba(Constants.primaryColor.r,
                       Constants.primaryColor.g,
                       Constants.primaryColor.b, 0.08)
        border.color: "transparent"

        Row {
            anchors.centerIn: parent
            spacing: 8
            Text { text: root.selected; color: "white" }
            Image { source: "images/arrow_down.svg"; width: 12; height: 12 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: dropdown.open()
        }
    }

    Popup {
        id: dropdown
        y: button.height + 4
        width: button.width
        implicitHeight: listView.contentHeight
        background: Rectangle {
            color: "#222"
            radius: 5
            border.color: "#555"
        }

        ListView {
            id: listView
            width: parent.width
            model: root.modelData
            clip: true

            delegate: ItemDelegate {
                text: modelData
                width: parent.width
                onClicked: {
                    root.selected = modelData
                    dropdown.close()
                }
            }
        }
    }
}
