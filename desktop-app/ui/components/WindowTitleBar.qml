import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

Rectangle {
    id: root

    required property Window window

    color: Theme.sidebarColor
    implicitHeight: 46
    radius: 16
    border.color: Theme.borderColor
    border.width: 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.radius
        color: root.color
        border.width: 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 12

        Image {
            source: "../assets/images/app_icon.ico"
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Text {
                text: qsTr("包貨小精靈")
                color: Theme.header1Color
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: qsTr("PackingElf")
                color: Theme.headerSubColor
                font.pixelSize: 10
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onDoubleTapped: {
                    if (root.window.visibility === Window.Maximized)
                        root.window.showNormal();
                    else
                        root.window.showMaximized();
                }
            }

            DragHandler {
                target: null
                onActiveChanged: {
                    if (active)
                        root.window.startSystemMove();
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 28
            radius: 8
            color: minimizeArea.containsMouse ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.16) : "transparent"
            border.color: Theme.borderColor

            Text {
                anchors.centerIn: parent
                text: "\u2014"
                color: Theme.header3Color
                font.pixelSize: 16
                font.bold: true
            }

            MouseArea {
                id: minimizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.window.showMinimized()
            }
        }

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 28
            radius: 8
            color: closeArea.containsMouse ? Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.18) : "transparent"
            border.color: closeArea.containsMouse ? Theme.errorColor : Theme.borderColor

            Text {
                anchors.centerIn: parent
                text: "\u2715"
                color: Theme.header3Color
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.window.close()
            }
        }
    }
}
