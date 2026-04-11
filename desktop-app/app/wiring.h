// ─────────────────────────────────────────────────────────────
// wiring.h
// Application dependency wiring / composition root.
//
// This defines the WiredApp struct which holds all the core
// application objects, and the wireEverything() factory function
// that creates and connects them in the correct order.
//
// Object creation order (dependency graph):
//   1. Database       — must be opened before anything else
//   2. OrdersRepository — needs the DB connection
//   3. OrdersViewModel  — needs the repository (shared_ptr)
//   4. DashboardViewModel — needs the repository + connects to OrdersVM
//
// Ownership:
//   - Database, OrdersVM, DashboardVM are owned via unique_ptr
//   - OrdersRepository is owned via shared_ptr because it's
//     shared between both ViewModels
//
// Usage (in main.cpp):
//   auto wired = wireEverything();
//   engine.rootContext()->setContextProperty("OrdersVM", wired.ordersVM.get());
// ─────────────────────────────────────────────────────────────
#pragma once

#include <memory>

// Include full headers (not forward declarations) because
// unique_ptr needs the complete type to call the destructor.
#include "DashboardViewModel.h"
#include "AppSettings.h"
#include "AppSupportService.h"
#include "Database.h"
#include "OrdersRepository.h"
#include "OrderTableViewModel.h"
#include "OrdersViewModel.h"
#include "PendingOrdersViewModel.h"
#include "ScraperService.h"
#include "SyncService.h"

// Holds all wired-up application objects.
// This struct is returned by wireEverything() and kept alive
// for the entire application lifetime (owned by main()).
struct WiredApp {
  std::unique_ptr<AppSettings> appSettings;         // User config stored in AppData
  std::unique_ptr<AppSupportService> appSupportSvc; // Logging and local diagnostics
  std::unique_ptr<Database> database;              // Local SQLite connection
  std::shared_ptr<OrdersRepository> ordersRepo;    // CRUD operations (shared)
  std::unique_ptr<OrdersViewModel> ordersVM;       // QML list model for orders
  std::unique_ptr<OrderTableViewModel> printingOrdersTableVM; // Filtered list model for printing table
  std::unique_ptr<OrderTableViewModel> historyOrdersTableVM;  // Filtered list model for history table
  std::unique_ptr<PendingOrdersViewModel> pendingOrdersVM; // QML list model for local pending orders
  std::unique_ptr<DashboardViewModel> dashboardVM; // QML metrics for HomePage
  std::unique_ptr<ScraperService>
      scraperSvc; // Launches scraper.exe via QProcess
  std::unique_ptr<SyncService> syncSvc; // Handles host pairing, outbox push, and pull sync
};

// Creates and connects all application layers.
// If the database fails to open, returns a WiredApp with null members.
WiredApp wireEverything();
