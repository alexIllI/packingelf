pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as BasicControls
import QtQuick.Layouts
import PackingElf 1.0

Rectangle {
    id: root

    // Column definitions: list of objects with "title", "role", and "width".
    // Example: [{ title: "貨單號碼", role: "orderNumber", width: 0.4 }]
    property var columns: []

    // Data model: assign a ListModel, QAbstractItemModel, or JS array.
    property alias model: listView.model

    // Currently selected row index (-1 = none).
    property int currentIndex: -1

    // Row height in pixels.
    property int rowHeight: 36

    signal rowClicked(int index)

    color: "transparent"
    radius: 8
    border.color: Theme.borderColor
    border.width: 1
    clip: true

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rowHeight
        color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.18)
        radius: root.radius

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.radius
            color: parent.color
        }

        Row {
            id: headerRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Repeater {
                model: root.columns.length

                Text {
                    required property int index
                    width: headerRow.width * (root.columns[index].width ?? (1.0 / root.columns.length))
                    height: headerRow.height
                    text: root.columns[index].title ?? ""
                    color: Theme.primaryColor
                    font.pixelSize: Constants.header3FontSize
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.borderColor
        }
    }

    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.currentIndex

        ScrollBar.vertical: BasicControls.ScrollBar {
            id: vScrollBar
            policy: listView.contentHeight > listView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: 2

            contentItem: Rectangle {
                implicitWidth: 5
                implicitHeight: 30
                radius: 3
                color: vScrollBar.pressed
                    ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.6)
                    : vScrollBar.hovered
                        ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.4)
                        : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2)

                Behavior on color {
                    ColorAnimation { duration: 120; easing.type: Easing.InOutCubic }
                }
            }

            background: Item {
                implicitWidth: 8
            }
        }

        delegate: Rectangle {
            id: rowDelegate
            required property int index
            required property var model

            width: listView.width
            height: root.rowHeight

            color: root.currentIndex === rowDelegate.index
                ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.22)
                : rowDelegate.index % 2 === 0
                    ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
                    : "transparent"

            Behavior on color {
                ColorAnimation { duration: 80; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.06)
                visible: rowMouse.containsMouse && root.currentIndex !== rowDelegate.index
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentIndex = rowDelegate.index;
                    root.rowClicked(rowDelegate.index);
                }
            }

            Row {
                id: rowContent
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Repeater {
                    model: root.columns.length

                    Text {
                        required property int index
                        width: rowContent.width * (root.columns[index].width ?? (1.0 / root.columns.length))
                        height: rowContent.height
                        text: {
                            var role = root.columns[index].role ?? "";
                            if (role && rowDelegate.model[role] !== undefined)
                                return String(rowDelegate.model[role]);
                            return "";
                        }
                        color: Theme.header3Color
                        font.pixelSize: Constants.header3FontSize
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.4)
            }
        }

        Text {
            anchors.centerIn: parent
            text: qsTr("目前沒有資料")
            color: Theme.headerSubColor
            font.pixelSize: Constants.header3FontSize
            opacity: 0.5
            visible: listView.count === 0
        }
    }
}
