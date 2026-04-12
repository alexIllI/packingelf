#include "OrderTableViewModel.h"

#include <QDate>
#include <QDateTime>

namespace {
QDate parseDateOnly(const QString& value)
{
    if (value.trimmed().isEmpty())
        return {};

    const QString datePart = value.left(10);
    const QDate isoDate = QDate::fromString(datePart, Qt::ISODate);
    if (isoDate.isValid())
        return isoDate;

    return QDate::fromString(datePart, QStringLiteral("yyyy/M/d"));
}

QDateTime parseIsoDateTime(const QString& value)
{
    if (value.trimmed().isEmpty())
        return {};

    QDateTime parsed = QDateTime::fromString(value, Qt::ISODate);
    if (parsed.isValid())
        return parsed;

    parsed = QDateTime::fromString(value, Qt::ISODateWithMs);
    if (parsed.isValid())
        return parsed;

    return {};
}
}

OrderTableViewModel::OrderTableViewModel(std::shared_ptr<OrdersRepository> repo,
                                         QObject* parent)
    : QAbstractListModel(parent)
    , m_repo(std::move(repo))
{
    refresh();
}

int OrderTableViewModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_orders.size());
}

QVariant OrderTableViewModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_orders.size())
        return {};

    const Order& order = m_orders.at(index.row());
    switch (role) {
    case IdRole:            return order.id;
    case OrderNumberRole:   return order.orderNumber;
    case InvoiceNumberRole: return order.invoiceNumber;
    case OrderDateRole:     return order.orderDate;
    case BuyerNameRole:     return order.buyerName;
    case TotalAmountRole:   return order.totalAmount;
    case StatusRole:
        if (normalizedStatus(order.orderStatus) == QStringLiteral("success"))
            return QStringLiteral("成功");
        if (normalizedStatus(order.orderStatus) == QStringLiteral("closed"))
            return QStringLiteral("關轉");
        if (normalizedStatus(order.orderStatus) == QStringLiteral("canceled"))
            return QStringLiteral("取消");
        return order.orderStatus;
    case UsingCouponRole:   return order.usingCoupon ? QStringLiteral("有") : QStringLiteral("無");
    case CreatedByRole:     return order.createdByClientId;
    case UpdatedByRole:     return order.updatedByClientId;
    case CreatedAtRole:     return order.createdAt;
    case UpdatedAtRole:     return order.updatedAt;
    default:                return {};
    }
}

QHash<int, QByteArray> OrderTableViewModel::roleNames() const
{
    return {
        { IdRole, "id" },
        { OrderNumberRole, "orderNumber" },
        { InvoiceNumberRole, "invoiceNumber" },
        { OrderDateRole, "date" },
        { BuyerNameRole, "accountName" },
        { TotalAmountRole, "totalAmount" },
        { StatusRole, "status" },
        { UsingCouponRole, "usingCoupon" },
        { CreatedByRole, "createdBy" },
        { UpdatedByRole, "updatedBy" },
        { CreatedAtRole, "createdAt" },
        { UpdatedAtRole, "updatedAt" }
    };
}

QString OrderTableViewModel::orderNumberAt(int row) const
{
    if (row < 0 || row >= m_orders.size())
        return {};

    return m_orders.at(row).orderNumber;
}

int OrderTableViewModel::findRow(const QString& query) const
{
    const QString needle = query.trimmed();
    if (needle.isEmpty())
        return -1;

    for (int row = 0; row < m_orders.size(); ++row) {
        const Order& order = m_orders.at(row);
        const QString haystack = order.orderNumber + QStringLiteral(" ") + order.invoiceNumber;
        if (haystack.contains(needle, Qt::CaseInsensitive))
            return row;
    }

    return -1;
}

void OrderTableViewModel::applyFilters(const QString& statusFilter,
                                       const QString& searchQuery,
                                       const QString& fromDate,
                                       const QString& toDate)
{
    m_statusFilter = normalizedStatus(statusFilter);
    m_searchQuery = searchQuery.trimmed();
    m_fromDate = fromDate.trimmed();
    m_toDate = toDate.trimmed();
    refresh();
}

void OrderTableViewModel::setStatusFilter(const QString& statusFilter)
{
    m_statusFilter = normalizedStatus(statusFilter);
    refresh();
}

void OrderTableViewModel::setRecentHoursFilter(int hours)
{
    m_recentHours = hours;
    refresh();
}

void OrderTableViewModel::clearFilters()
{
    m_statusFilter.clear();
    m_searchQuery.clear();
    m_fromDate.clear();
    m_toDate.clear();
    refresh();
}

void OrderTableViewModel::refresh()
{
    const QVector<Order> source = m_repo->fetchAll();
    QVector<Order> filtered;
    filtered.reserve(source.size());

    for (const auto& order : source) {
        if (matchesFilters(order))
            filtered.append(order);
    }

    beginResetModel();
    m_orders = filtered;
    endResetModel();
    emit countChanged();
}

bool OrderTableViewModel::matchesFilters(const Order& order) const
{
    if (m_recentHours > 0) {
        const QDateTime createdAt = parseIsoDateTime(order.createdAt);
        if (!createdAt.isValid())
            return false;

        const QDateTime threshold = QDateTime::currentDateTimeUtc().addSecs(-(m_recentHours * 3600));
        if (createdAt.toUTC() < threshold)
            return false;
    }

    if (!m_statusFilter.isEmpty() && m_statusFilter != QStringLiteral("all")) {
        if (normalizedStatus(order.orderStatus) != m_statusFilter)
            return false;
    }

    if (!m_searchQuery.isEmpty()) {
        const QString haystack = order.orderNumber + QStringLiteral(" ") + order.invoiceNumber;
        if (!haystack.contains(m_searchQuery, Qt::CaseInsensitive))
            return false;
    }

    const QDate orderDate = parseDateOnly(order.orderDate);
    const QDate fromDate = parseDateOnly(m_fromDate);
    const QDate toDate = parseDateOnly(m_toDate);

    if (fromDate.isValid() && orderDate.isValid() && orderDate < fromDate)
        return false;
    if (toDate.isValid() && orderDate.isValid() && orderDate > toDate)
        return false;

    if ((fromDate.isValid() || toDate.isValid()) && !orderDate.isValid())
        return false;

    return true;
}

QString OrderTableViewModel::normalizedStatus(const QString& status) const
{
    const QString normalized = status.trimmed().toLower();
    if (normalized == QStringLiteral("成功"))
        return QStringLiteral("success");
    if (normalized == QStringLiteral("取消"))
        return QStringLiteral("canceled");
    if (normalized == QStringLiteral("關轉"))
        return QStringLiteral("closed");
    if (normalized == QStringLiteral("全部"))
        return QStringLiteral("all");
    return normalized;
}
