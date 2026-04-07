// ─────────────────────────────────────────────────────────────
// wiring.cpp
// Creates and connects all application layers in the correct order.
//
// This is the "composition root" — the one place where we decide
// how all the objects are created and wired together. This makes
// it easy to swap implementations for testing or reconfigure.
//
// Creation order:
//   Database → OrdersRepository → OrdersVM + DashboardVM → connect signals
// ─────────────────────────────────────────────────────────────
#include "wiring.h"

WiredApp wireEverything()
{
    WiredApp app;

    // ─── Step 1: Open the local SQLite database ───
    // This creates the .db file and runs migrations if needed.
    app.database = std::make_unique<Database>();
    if (!app.database->open()) {
        qWarning() << "[Wiring] Database failed to open!";
        return app;  // Return early — other objects can't work without DB
    }

    // ─── Step 2: Create the repository ───
    // shared_ptr because both ViewModels need to access it.
    app.ordersRepo = std::make_shared<OrdersRepository>(app.database->db());

    // ─── Step 3: Create the ViewModels ───
    // OrdersViewModel loads all orders from DB in its constructor.
    // DashboardViewModel queries aggregate counts in its constructor.
    app.ordersVM    = std::make_unique<OrdersViewModel>(app.ordersRepo);
    app.dashboardVM = std::make_unique<DashboardViewModel>(app.ordersRepo);

    // ─── Step 4: Create the ScraperService and auto-start the browser ───
    // The daemon launches Chromium, logs in, and navigates to My Store.
    // The Qt app stays fully responsive during the 30–90 second startup.
    //
    // accountName = "" → --manual-login mode (user types credentials)
    // accountName = "子午計畫" → reads from encrypted account store (production)
    //
    // After setup, change the empty string to the account name and rebuild.
    app.scraperSvc = std::make_unique<ScraperService>();
    app.scraperSvc->startBrowser(QStringLiteral(""));  // "" = manual-login

    // ─── Step 5: Connect signals ───
    // When OrdersVM creates/removes an order, DashboardVM auto-refreshes.
    app.dashboardVM->connectToOrdersVM(app.ordersVM.get());

    return app;
}

