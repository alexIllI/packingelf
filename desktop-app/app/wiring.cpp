#include "wiring.h"

#include "HostClient.h"
#include "OutboxStore.h"

WiredApp wireEverything() {
  WiredApp app;

  app.appSettings = std::make_unique<AppSettings>();
  app.database = std::make_unique<Database>();
  if (!app.database->open()) {
    qWarning() << "[Wiring] Database failed to open!";
    return app;
  }

  auto outbox = std::make_unique<OutboxStore>(app.database->db());
  app.ordersRepo = std::make_shared<OrdersRepository>(app.database->db());
  app.ordersVM = std::make_unique<OrdersViewModel>(app.ordersRepo, outbox.get());
  app.dashboardVM = std::make_unique<DashboardViewModel>(app.ordersRepo);
  auto hostClient = std::make_unique<HostClient>();
  app.syncSvc = std::make_unique<SyncService>(
      app.ordersRepo,
      std::move(outbox),
      std::move(hostClient));

  app.scraperSvc = std::make_unique<ScraperService>();
  app.scraperSvc->startBrowser(QStringLiteral(""));

  QObject::connect(app.scraperSvc.get(), &ScraperService::scraperFinished,
                   app.ordersVM.get(), &OrdersViewModel::handleScraperFinished);
  QObject::connect(app.scraperSvc.get(), &ScraperService::scraperFailed,
                   app.ordersVM.get(), &OrdersViewModel::handleScraperFailed);
  QObject::connect(app.ordersVM.get(), &OrdersViewModel::orderCreated,
                   app.syncSvc.get(), &SyncService::triggerSync);
  QObject::connect(app.ordersVM.get(), &OrdersViewModel::orderRemoved,
                   app.syncSvc.get(), &SyncService::triggerSync);
  QObject::connect(app.syncSvc.get(), &SyncService::ordersChanged,
                   app.ordersVM.get(), &OrdersViewModel::refresh);

  app.dashboardVM->connectToOrdersVM(app.ordersVM.get());

  return app;
}
