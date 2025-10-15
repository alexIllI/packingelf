#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

// #include "AppConfig.h"
// #include "wiring.h"
// #include "viewmodels/NavigationViewModel.h"
// #include "viewmodels/DashboardViewModel.h"
// #include "viewmodels/JobsViewModel.h"

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);

    // TODO: Implement AppConfig and wiring when ready
    // AppConfig cfg = AppConfig::load();
    // auto wired = wireEverything(cfg);
    // qmlRegisterSingletonInstance("App", 1, 0, "Nav", wired.nav.get());
    // qmlRegisterSingletonInstance("App", 1, 0, "DashboardVM", wired.dashboard.get());
    // qmlRegisterSingletonInstance("App", 1, 0, "JobsVM", wired.jobs.get());

    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/");

    // TODO: Create ui/App.qml when ready
    // const QUrl url(QStringLiteral("qrc:/ui/App.qml"));
    // engine.load(url);

    // For now, just run the app without loading QML
    // if (engine.rootObjects().isEmpty())
    //     return 1;

    return app.exec();
}
