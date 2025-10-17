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

    // Load the main QML file
    const QUrl url(QStringLiteral("qrc:/qt/qml/PackingElf/ui/App.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, []()
                     { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty())
    {
        qWarning() << "Failed to load QML";
        return -1;
    }

    return app.exec();
}
