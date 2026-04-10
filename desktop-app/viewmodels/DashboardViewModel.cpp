#include "DashboardViewModel.h"
#include "OrdersRepository.h"
#include "OrdersViewModel.h"

DashboardViewModel::DashboardViewModel(std::shared_ptr<OrdersRepository> repo,
                                       QObject* parent)
    : QObject(parent)
    , m_repo(std::move(repo))
{
    refresh();
}

void DashboardViewModel::refresh()
{
    m_totalOrders = m_repo->countAll();
    m_todayProcessed = m_repo->countToday();
    m_pendingOrders = m_repo->countPendingSubmissions();
    m_errorCount = 0;

    emit metricsChanged();
}

void DashboardViewModel::connectToOrdersVM(OrdersViewModel* vm)
{
    if (!vm)
        return;

    connect(vm, &OrdersViewModel::countChanged, this, &DashboardViewModel::refresh);
    connect(vm, &OrdersViewModel::pendingCountChanged, this, &DashboardViewModel::refresh);
    connect(vm, &OrdersViewModel::orderCreated, this, &DashboardViewModel::refresh);
    connect(vm, &OrdersViewModel::orderRemoved, this, &DashboardViewModel::refresh);
}
