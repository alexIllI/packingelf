import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import PackingElf 1.0 // Theme, Constants, NavStore singletons

T.Button {
    id: control

    // Public API
    property string route: "" // e.g. "Home"
    text: control.text // from T.AbstractButton
    icon.width: 28
    icon.height: 28

    // Do NOT let the button toggle its own checked state
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    checkable: false
    checked: NavStore.route === route

    // Visual structure (sidebar)
    flat: true
    display: T.AbstractButton.TextUnderIcon

    // Size & padding
    implicitHeight: 70
    implicitWidth: 70
    readonly property int indicatorWidth: 4
    leftPadding: 10 + indicatorWidth
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8
    spacing: 6

    // Interactions
    HoverHandler {
        id: hover
    }
    TapHandler {
        id: tap
        // Don't navigate here; Button's onClicked will handle it.
        // Keep it passive so it doesn't steal the gesture:
        gesturePolicy: TapHandler.WithinBounds // observe within bounds
        grabPermissions: PointerHandler.TakeOverForbidden
        onPressedChanged: if (pressed)
            ripple.playAt(point.position)
    }
    // Use the built-in clicked; no TapHandler
    onClicked: NavStore.go(route)

    // Accessibility
    Accessible.role: Accessible.Button
    Accessible.name: control.text
    Accessible.checked: checked

    // Content (icon above text) with Theme colors
    contentItem: ColumnLayout {
        spacing: control.spacing
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        Image {
            id: iconImg
            source: control.icon.source
            fillMode: Image.PreserveAspectFit

            // Logical on-screen size
            readonly property int logicalW: control.icon.width > 0 ? control.icon.width : 28
            readonly property int logicalH: control.icon.height > 0 ? control.icon.height : 28
            width: logicalW
            height: logicalH

            // Detect vector vs raster
            readonly property bool isVector: source.toString().toLowerCase().endsWith(".svg")

            // Only force sourceSize for raster formats (png/jpg/etc)
            readonly property real dpr: Screen.devicePixelRatio
            // Clamp to avoid huge allocations even for rasters (paranoia)
            readonly property int maxTex: 2048
            sourceSize.width: isVector ? 0 : Math.min(maxTex, Math.max(1, Math.round(width * dpr)))
            sourceSize.height: isVector ? 0 : Math.min(maxTex, Math.max(1, Math.round(height * dpr)))

            // Crispness
            smooth: false // avoid linear filtering on small icons
            mipmap: true // helps if occasionally downscaled
            cache: true

            // Snap position to whole pixels (prevents half-pixel blur)
            Component.onCompleted: {
                x = Math.round(x);
                y = Math.round(y);
            }
            onXChanged: x = Math.round(x)
            onYChanged: y = Math.round(y)
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }

        Text {
            text: control.text
            font: control.font
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            // color: control.checked ? Theme.sidebarTextActive : Theme.sidebarText
            color: Theme.header3Color
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
    }

    // Background with Theme colors + indicator + lightweight ripple
    background: Item {
        id: bgroot
        implicitWidth: 64
        implicitHeight: 40
        clip: true

        // base rounded rect with hover/checked tint from Theme
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 6
            color: !control.enabled ? "transparent" : control.checked ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.checkedOpacity) : hover.hovered ? Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.hoverOpacity) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        // Left active bar
        Rectangle {
            id: indicator
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: control.checked ? control.indicatorWidth : 0
            radius: 2
            color: Theme.primaryColor
            opacity: control.checked ? 1 : 0
            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        // Lightweight "ripple-ish" press effect (public API only)
        Item {
            id: rippleLayer
            anchors.fill: parent
            clip: true

            Rectangle {
                id: ripple
                visible: false
                width: 0
                height: 0
                radius: width / 2
                color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.3)

                // 1) store the origin where the user pressed (in rippleLayer coords)
                property real originX: rippleLayer.width / 2
                property real originY: rippleLayer.height / 2

                // 2) bind x/y to origin so center stays fixed while size animates
                x: originX - width / 2
                y: originY - height / 2

                function playAt(posInControl) {
                    // 3) map from the control's coord space to the ripple layer
                    const p = rippleLayer.mapFromItem(control, posInControl.x, posInControl.y);
                    originX = p.x;
                    originY = p.y;

                    visible = true;
                    width = height = 0;
                    opacity = 0.22;
                    growW.start();
                    growH.start();
                    fadeOut.start();
                }

                NumberAnimation {
                    id: growW
                    target: ripple
                    property: "width"
                    to: Math.max(rippleLayer.width, rippleLayer.height) * 1.6
                    duration: 400
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    id: growH
                    target: ripple
                    property: "height"
                    to: Math.max(rippleLayer.width, rippleLayer.height) * 1.6
                    duration: 400
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    id: fadeOut
                    target: ripple
                    property: "opacity"
                    from: 0.22
                    to: 0.0
                    duration: 240
                    onStopped: ripple.visible = false
                }
            }
        }
    }
}
