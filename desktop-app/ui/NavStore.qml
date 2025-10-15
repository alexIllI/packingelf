pragma Singleton
import QtQuick

QtObject {
    // Page "enum" (property names must start with lowercase)
    readonly property var page: ({
            Home: 0,
            Printing: 1,
            History: 2,
            Setting: 3,
            Profile: 4
        })

    // current page (default to Home)
    property int currentPage: page.Home
}
