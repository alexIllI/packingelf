// stores/NavStore.qml
pragma Singleton
import QtQuick

QtObject {
    id: nav
    property string route: "Home" // default landing page
    signal navigate(string route)

    function go(r) {
        if (r !== route) {
            route = r;
            navigate(r);
        }
    }
}
