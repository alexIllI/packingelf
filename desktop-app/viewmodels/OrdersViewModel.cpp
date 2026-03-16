// ─────────────────────────────────────────────────────────────
// OrdersViewModel.cpp
// Implementation of the QML list model for orders.
//
// Key patterns used:
//   - beginInsertRows/endInsertRows: tells QML's view to animate
//     the new row sliding in (instead of resetting the whole list)
//   - beginRemoveRows/endRemoveRows: same for deletions
//   - beginResetModel/endResetModel: used in refresh() to reload all
//   - dataChanged signal: used in updateOrderStatus() to update a cell
//
// The model keeps an in-memory QVector<Order> that mirrors the DB.
// This avoids hitting SQLite on every UI scroll/repaint.
// ─────────────────────────────────────────────────────────────
#include "OrdersViewModel.h"

#include <QDateTime>
#include <QUuid>
#include <QDebug>

OrdersViewModel::OrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                                   QObject* parent)
    : QAbstractListModel(parent)
    , m_repo(std::move(repo))
{
    // Load existing orders from DB on construction
    refresh();
}

// ─── QAbstractListModel: How many rows? ───
int OrdersViewModel::rowCount(const QModelIndex& parent) const
{
    // For flat list models, parent.isValid() should return 0
    // (we don't have a tree structure)
    if (parent.isValid()) return 0;
    return static_cast<int>(m_orders.size());
}

// ─── QAbstractListModel: What data at this row/role? ───
// QML's CustomTable calls this automatically for each visible cell.
// The `role` parameter determines which field to return.
QVariant OrdersViewModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_orders.size())
        return {};

    const Order& o = m_orders.at(index.row());

    switch (role) {
    case IdRole:            return o.id;
    case OrderNumberRole:   return o.orderNumber;
    case InvoiceNumberRole: return o.invoiceNumber;
    case OrderDateRole:     return o.orderDate;
    case BuyerNameRole:     return o.buyerName;
    case StatusRole:        return o.status;
    // Convert bool to "yes"/"no" string for display in the table
    case UsingCouponRole:   return o.usingCoupon ? QStringLiteral("yes") : QStringLiteral("no");
    case CreatedByRole:     return o.createdBy;
    case CreatedAtRole:     return o.createdAt;
    case UpdatedAtRole:     return o.updatedAt;
    default:                return {};
    }
}

// ─── QAbstractListModel: Map role enums to QML role name strings ───
// These names MUST match the "role" property in CustomTable's column
// definitions in QML. For example, if QML has:
//   { title: "日期", role: "date", width: 0.15 }
// then we need a role mapped to "date" here.
QHash<int, QByteArray> OrdersViewModel::roleNames() const
{
    return {
        { IdRole,            "id" },
        { OrderNumberRole,   "orderNumber" },      // matches QML: role: "orderNumber"
        { InvoiceNumberRole, "invoiceNumber" },     // matches QML: role: "invoiceNumber"
        { OrderDateRole,     "date" },              // matches QML: role: "date"
        { BuyerNameRole,     "accountName" },       // matches QML: role: "accountName"
        { StatusRole,        "status" },            // matches QML: role: "status"
        { UsingCouponRole,   "usingCoupon" },       // matches QML: role: "usingCoupon"
        { CreatedByRole,     "createdBy" },
        { CreatedAtRole,     "createdAt" },
        { UpdatedAtRole,     "updatedAt" }
    };
}

// ─── Create a new order ───
// Called from QML: OrdersVM.createOrder("PG02491384", "AB1234567")
// This is triggered when the user clicks "列印" on PrintingPage.
// 
// Flow:
//   1. Validate inputs (both must be non-empty)
//   2. Generate UUID + timestamp
//   3. Insert into SQLite via repository
//   4. Prepend to in-memory list (newest at top)
//   5. Notify QML views and DashboardViewModel
//   6. Return the new order's UUID
QString OrdersViewModel::createOrder(const QString& orderNumber,
                                      const QString& invoiceNumber)
{
    // Guard: don't create empty orders
    if (orderNumber.isEmpty() || invoiceNumber.isEmpty()) {
        qWarning() << "[OrdersVM] createOrder: missing order/invoice number";
        return {};
    }

    // Build the Order struct with the data we have now.
    // Fields like buyerName, orderDate, usingCoupon are empty —
    // they'll be filled in later by updateFromScraper() (Phase 2).
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    Order order;
    order.id            = QUuid::createUuid().toString(QUuid::WithoutBraces);
    order.orderNumber   = orderNumber;
    order.invoiceNumber = invoiceNumber;
    order.status        = QStringLiteral("printed");  // Initial status
    order.createdAt     = now;
    order.updatedAt     = now;

    // Persist to SQLite
    if (!m_repo->insert(order)) {
        return {};
    }

    // Update the in-memory model:
    // beginInsertRows tells QML "I'm about to add a row at index 0"
    // so it can animate the insertion smoothly.
    beginInsertRows(QModelIndex(), 0, 0);
    m_orders.prepend(order);  // Newest first
    endInsertRows();

    // Notify listeners
    emit countChanged();
    emit orderCreated(order.id);  // DashboardViewModel listens to this

    qDebug() << "[OrdersVM] Created order:" << order.orderNumber
             << "id:" << order.id;
    return order.id;
}

// ─── Remove an order by row index ───
// Called from QML when user selects a row and clicks "刪除" (delete).
bool OrdersViewModel::removeOrder(int row)
{
    // Bounds check
    if (row < 0 || row >= m_orders.size())
        return false;

    const QString id = m_orders.at(row).id;

    // Delete from SQLite first — if this fails, don't touch the model
    if (!m_repo->remove(id))
        return false;

    // Remove from in-memory model with proper QML notification
    beginRemoveRows(QModelIndex(), row, row);
    m_orders.removeAt(row);
    endRemoveRows();

    emit countChanged();
    emit orderRemoved(id);  // DashboardViewModel listens to this

    qDebug() << "[OrdersVM] Removed order at row:" << row << "id:" << id;
    return true;
}

// ─── Update status of an order ───
// E.g., after scraper confirms shipping, change "printed" → "shipped"
bool OrdersViewModel::updateOrderStatus(int row, const QString& newStatus)
{
    if (row < 0 || row >= m_orders.size())
        return false;

    const QString id = m_orders.at(row).id;

    // Update in SQLite
    if (!m_repo->updateStatus(id, newStatus))
        return false;

    // Update the in-memory copy
    m_orders[row].status = newStatus;
    m_orders[row].updatedAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    // Tell QML "the data at this specific row changed for these roles"
    // This avoids resetting the whole list — only the affected cell repaints.
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx, { StatusRole, UpdatedAtRole });

    qDebug() << "[OrdersVM] Updated order" << id << "status to:" << newStatus;
    return true;
}

// ─── Reload everything from the database ───
// beginResetModel/endResetModel tells QML to throw away its internal
// caches and re-query all data from the model. More expensive than
// incremental updates, but guaranteed to be correct.
void OrdersViewModel::refresh()
{
    beginResetModel();
    m_orders = m_repo->fetchAll();
    endResetModel();
    emit countChanged();

    qDebug() << "[OrdersVM] Refreshed. Total orders:" << m_orders.size();
}
