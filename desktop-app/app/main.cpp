// ─────────────────────────────────────────────────────────────
// main.cpp
// Application entry point for PackingElf desktop app.
//
// Responsibilities:
//   1. Create the QGuiApplication with org/app names
//      (these names determine the QStandardPaths directory)
//   2. Call wireEverything() to set up Database → Repo → ViewModels
//   3. Expose ViewModels to QML as context properties
//   4. Load the root QML file and start the event loop
//
// QML Context Properties:
//   - "OrdersVM"    → OrdersViewModel*  (list model for tables)
//   - "DashboardVM" → DashboardViewModel* (metrics for HomePage)
//
// These are accessed in QML like global singletons:
//   model: OrdersVM
//   property int total: DashboardVM.totalOrders
// ─────────────────────────────────────────────────────────────
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "AppSettings.h"
#include "DashboardViewModel.h"
#include "OrdersViewModel.h"
#include "ScraperService.h"
#include "SyncService.h"
#include "wiring.h"

int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);

  // Set organization and application name — these are used by
  // QStandardPaths::AppDataLocation to determine where the
  // SQLite database file is stored on disk.
  // On Windows: C:/Users/<user>/AppData/Local/Meridian/PackingElf/
  app.setOrganizationName(QStringLiteral("Meridian"));
  app.setApplicationName(QStringLiteral("PackingElf"));

  // ─── Wire up all layers ───
  // Database → Repository → ViewModels (with signal connections)
  // The `wired` struct is kept alive for the app's entire lifetime.
  auto wired = wireEverything();

  QQmlApplicationEngine engine;

  // ─── Expose ViewModels to QML ───
  // setContextProperty makes these available as global names in QML.
  // Any QML file can reference OrdersVM and DashboardVM directly.
  engine.rootContext()->setContextProperty(QStringLiteral("AppSettings"),
                                           wired.appSettings.get());
  engine.rootContext()->setContextProperty(QStringLiteral("OrdersVM"),
                                           wired.ordersVM.get());
  engine.rootContext()->setContextProperty(QStringLiteral("DashboardVM"),
                                           wired.dashboardVM.get());
  // ScraperSvc.scrape(orderId, orderNumber, accountName) → QML triggers a
  // scrape ScraperSvc.busy → bind to show a loading spinner
  engine.rootContext()->setContextProperty(QStringLiteral("ScraperSvc"),
                                           wired.scraperSvc.get());
  engine.rootContext()->setContextProperty(QStringLiteral("SyncSvc"),
                                           wired.syncSvc.get());

  // ─── Load the root QML file ───
  // This is the entry point for the QML UI, defined in the
  // qt_add_qml_module() in CMakeLists.txt.
  const QUrl url(QStringLiteral("qrc:/qt/qml/PackingElf/ui/App.qml"));

  // If QML object creation fails, exit with error code
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

  engine.load(url);

  if (engine.rootObjects().isEmpty()) {
    qWarning() << "Failed to load QML";
    return -1;
  }

  // Start the Qt event loop (blocks until app is closed)
  return app.exec();
}
