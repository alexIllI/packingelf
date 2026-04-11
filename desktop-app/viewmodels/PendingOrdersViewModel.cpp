#include "PendingOrdersViewModel.h"

PendingOrdersViewModel::PendingOrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                                               QObject* parent)
    : QAbstractListModel(parent)
    , m_repo(std::move(repo))
{
    refresh();
}

int PendingOrdersViewModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_pendingOrders.size());
}

QVariant PendingOrdersViewModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_pendingOrders.size())
        return {};

    const PendingOrder& pending = m_pendingOrders.at(index.row());
    switch (role) {
    case IdRole: return pending.id;
    case OrderNumberRole: return pending.orderNumber;
    case RemarkRole: return pending.remark;
    case DateRole: return pending.createdAt;
    case CreatedAtRole: return pending.createdAt;
    case UpdatedAtRole: return pending.updatedAt;
    default: return {};
    }
}

QHash<int, QByteArray> PendingOrdersViewModel::roleNames() const
{
    return {
        { IdRole, "id" },
        { OrderNumberRole, "orderNumber" },
        { RemarkRole, "remark" },
        { DateRole, "date" },
        { CreatedAtRole, "createdAt" },
        { UpdatedAtRole, "updatedAt" }
    };
}

QString PendingOrdersViewModel::addPendingOrder(const QString& orderNumber, const QString& remark)
{
    const QString normalizedOrderNumber = orderNumber.trimmed().toUpper();
    if (normalizedOrderNumber.isEmpty())
        return QStringLiteral("請輸入待處理貨單號碼。");

    if (!m_repo->createPendingOrder(normalizedOrderNumber, remark.trimmed()).has_value())
        return QStringLiteral("儲存待處理貨單失敗，請稍後再試。");

    refresh();
    return {};
}

bool PendingOrdersViewModel::removePendingOrder(int row)
{
    if (row < 0 || row >= m_pendingOrders.size())
        return false;

    if (!m_repo->deletePendingOrder(m_pendingOrders.at(row).id))
        return false;

    beginRemoveRows(QModelIndex(), row, row);
    m_pendingOrders.removeAt(row);
    endRemoveRows();
    emit countChanged();
    return true;
}

QString PendingOrdersViewModel::orderNumberAt(int row) const
{
    if (row < 0 || row >= m_pendingOrders.size())
        return {};
    return m_pendingOrders.at(row).orderNumber;
}

QString PendingOrdersViewModel::pendingIdAt(int row) const
{
    if (row < 0 || row >= m_pendingOrders.size())
        return {};
    return m_pendingOrders.at(row).id;
}

void PendingOrdersViewModel::refresh()
{
    beginResetModel();
    m_pendingOrders = m_repo->fetchPendingOrders();
    endResetModel();
    emit countChanged();
}
