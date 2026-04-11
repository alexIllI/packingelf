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
  app.pendingOrdersVM = std::make_unique<PendingOrdersViewModel>(app.ordersRepo);
  app.dashboardVM = std::make_unique<DashboardViewModel>(app.ordersRepo);
  auto hostClient = std::make_unique<HostClient>();
  app.syncSvc = std::make_unique<SyncService>(
      app.ordersRepo,
      std::move(outbox),
      std::move(hostClient));

  app.scraperSvc = std::make_unique<ScraperService>();
  auto applyLoginPreference = [&app]() {
    const auto selectedAccount = app.appSettings->selectedMyAcgAccount();
    if (app.appSettings->autoLoginEnabled() && selectedAccount.has_value()) {
      app.scraperSvc->setPreferredLoginMode(
          true,
          selectedAccount->name,
          selectedAccount->account,
          selectedAccount->password);
      return;
    }

    app.scraperSvc->setPreferredLoginMode(false, QString(), QString(), QString());
  };

  applyLoginPreference();
  app.scraperSvc->startConfiguredBrowser();

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
  QObject::connect(app.appSettings.get(), &AppSettings::myAcgAccountsChanged,
                   app.scraperSvc.get(), applyLoginPreference);
  QObject::connect(app.appSettings.get(), &AppSettings::autoLoginSettingsChanged,
                   app.scraperSvc.get(), applyLoginPreference);

  app.dashboardVM->connectToOrdersVM(app.ordersVM.get());

  return app;
}
