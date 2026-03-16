// ─────────────────────────────────────────────────────────────
// DashboardViewModel.h
// Provides aggregate metrics for the HomePage dashboard.
//
// The HomePage displays several "MetricCard" components that
// show counts like total orders, today's processed, pending, etc.
// This ViewModel queries the OrdersRepository for these counts
// and exposes them as Q_PROPERTY values that QML can bind to.
//
// Auto-refresh:
//   When connected to OrdersViewModel via connectToOrdersVM(),
//   this ViewModel automatically recalculates metrics whenever
//   an order is created or removed. No manual refresh needed.
//
// QML usage:
//   DashboardVM.totalOrders    → 42
//   DashboardVM.todayProcessed → 7
//   DashboardVM.pendingOrders  → 3
//   DashboardVM.errorCount     → 0  (hardcoded, Phase 2)
//   DashboardVM.localDbOnline  → true
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QObject>
#include <memory>

// Forward declarations (headers included in .cpp)
class OrdersRepository;
class OrdersViewModel;

class DashboardViewModel : public QObject {
    Q_OBJECT

    // ─── QML-bindable properties ───
    // Each Q_PROPERTY automatically notifies QML when metricsChanged() fires.
    Q_PROPERTY(int totalOrders   READ totalOrders   NOTIFY metricsChanged)
    Q_PROPERTY(int todayProcessed READ todayProcessed NOTIFY metricsChanged)
    Q_PROPERTY(int pendingOrders READ pendingOrders NOTIFY metricsChanged)
    Q_PROPERTY(int errorCount    READ errorCount    NOTIFY metricsChanged)
    Q_PROPERTY(bool localDbOnline READ localDbOnline NOTIFY statusChanged)

public:
    explicit DashboardViewModel(std::shared_ptr<OrdersRepository> repo,
                                 QObject* parent = nullptr);

    // ─── Property getters ───
    int totalOrders()    const { return m_totalOrders; }
    int todayProcessed() const { return m_todayProcessed; }
    int pendingOrders()  const { return m_pendingOrders; }
    int errorCount()     const { return m_errorCount; }
    bool localDbOnline() const { return m_localDbOnline; }

    // Recalculate all metrics from the database.
    // Can be called from QML: DashboardVM.refresh()
    Q_INVOKABLE void refresh();

    // Connect signal/slot: when OrdersViewModel creates/removes an order,
    // this ViewModel auto-refreshes its counts.
    void connectToOrdersVM(OrdersViewModel* vm);

signals:
    void metricsChanged();  // Emitted when any count changes
    void statusChanged();   // Emitted when online/offline status changes

private:
    std::shared_ptr<OrdersRepository> m_repo;

    // Cached metric values (updated on refresh)
    int  m_totalOrders    = 0;
    int  m_todayProcessed = 0;
    int  m_pendingOrders  = 0;
    int  m_errorCount     = 0;      // Always 0 for now (Phase 2: scraper errors)
    bool m_localDbOnline  = true;   // Always true for now (Phase 2: health check)
};
