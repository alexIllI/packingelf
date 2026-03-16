// ─────────────────────────────────────────────────────────────
// DashboardViewModel.cpp
// Implementation of the dashboard metrics ViewModel.
//
// refresh() queries aggregate counts from OrdersRepository:
//   - countAll()              → totalOrders
//   - countToday()            → todayProcessed
//   - countByStatus("printed") → pendingOrders
//   - errorCount              → hardcoded 0 (Phase 2)
//
// connectToOrdersVM() wires up signal/slot connections so that
// whenever OrdersViewModel emits orderCreated or orderRemoved,
// this ViewModel automatically calls refresh() to update counts.
// ─────────────────────────────────────────────────────────────
#include "DashboardViewModel.h"
#include "OrdersRepository.h"
#include "OrdersViewModel.h"

#include <QDebug>

DashboardViewModel::DashboardViewModel(std::shared_ptr<OrdersRepository> repo,
                                         QObject* parent)
    : QObject(parent)
    , m_repo(std::move(repo))
{
    // Load initial metric values from the database
    refresh();
}

void DashboardViewModel::refresh()
{
    // Query aggregate counts from SQLite
    m_totalOrders    = m_repo->countAll();
    m_todayProcessed = m_repo->countToday();

    // "Pending" orders = orders still in "printed" state (not yet shipped/closed).
    // This maps to the HomePage's "待處理貨單" metric card.
    m_pendingOrders  = m_repo->countByStatus(QStringLiteral("printed"));

    // Error count is always 0 for now.
    // Phase 2: this will track orders where the web scraper failed.
    m_errorCount     = 0;

    // Tell QML that all metric properties have new values.
    // Any QML binding like `DashboardVM.totalOrders` will automatically re-read.
    emit metricsChanged();

    qDebug() << "[DashboardVM] Refreshed — total:" << m_totalOrders
             << "today:" << m_todayProcessed
             << "pending:" << m_pendingOrders;
}

// ─── Connect to OrdersViewModel signals ───
// This is called once during wiring (wireEverything).
// After this, DashboardViewModel auto-refreshes when orders change.
void DashboardViewModel::connectToOrdersVM(OrdersViewModel* vm)
{
    if (!vm) return;

    // When a new order is created → refresh counts
    connect(vm, &OrdersViewModel::orderCreated,  this, &DashboardViewModel::refresh);

    // When an order is deleted → refresh counts
    connect(vm, &OrdersViewModel::orderRemoved,  this, &DashboardViewModel::refresh);
}
