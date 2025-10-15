pragma Singleton
import QtQuick

QtObject {
    // property string relativeFontDirectory: "fonts"

    // /* Edit this comment to add your custom font */
    // readonly property font font: Qt.font({
    // family: Qt.application.font.family,
    // pixelSize: Qt.application.font.pixelSize
    // })
    // readonly property font largeFont: Qt.font({
    // family: Qt.application.font.family,
    // pixelSize: Qt.application.font.pixelSize * 1.6
    // })

    readonly property int width: 1080
    readonly property int height: 800
    readonly property int page_width: 980
    readonly property int page_height: 790

    readonly property int pageMargin: 10
    readonly property int pageGap: 20
    readonly property int contentGap: 10

    // Font Size
    readonly property int header1FontSize: 36
    readonly property int header2FontSize: 18
    readonly property int header3FontSize: 12
}
