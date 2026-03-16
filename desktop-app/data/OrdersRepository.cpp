// ─────────────────────────────────────────────────────────────
// OrdersRepository.cpp
// Implementation of CRUD operations for the `orders` table.
//
// All methods use parameterized queries (bindValue) to prevent
// SQL injection. Error messages are logged via qWarning().
// ─────────────────────────────────────────────────────────────
#include "OrdersRepository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QDateTime>
#include <QDebug>

OrdersRepository::OrdersRepository(QSqlDatabase& db)
    : m_db(db)
{
}

// ─── Helper: map a query row to an Order struct ───
// This reads column values by name (not index) so it's
// resilient to column reordering in the schema.
Order OrdersRepository::rowToOrder(const QSqlQuery& q) const
{
    Order o;
    o.id             = q.value(QStringLiteral("id")).toString();
    o.orderNumber    = q.value(QStringLiteral("order_number")).toString();
    o.invoiceNumber  = q.value(QStringLiteral("invoice_number")).toString();
    o.orderDate      = q.value(QStringLiteral("order_date")).toString();
    o.buyerName      = q.value(QStringLiteral("buyer_name")).toString();
    o.status         = q.value(QStringLiteral("status")).toString();
    o.usingCoupon    = q.value(QStringLiteral("using_coupon")).toBool();
    o.createdBy      = q.value(QStringLiteral("created_by")).toString();
    o.createdAt      = q.value(QStringLiteral("created_at")).toString();
    o.updatedAt      = q.value(QStringLiteral("updated_at")).toString();
    return o;
}

// ─── Fetch all orders, newest first ───
// Used by OrdersViewModel::refresh() to populate the full list.
QVector<Order> OrdersRepository::fetchAll() const
{
    QVector<Order> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT * FROM orders ORDER BY created_at DESC"));
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchAll failed:" << q.lastError().text();
        return results;
    }
    while (q.next())
        results.append(rowToOrder(q));
    return results;
}

// ─── Fetch by date range ───
// Used by the HistoryPage to filter orders by created_at date.
// Both `from` and `to` are inclusive (>= and <=).
QVector<Order> OrdersRepository::fetchByDateRange(const QString& from, const QString& to) const
{
    QVector<Order> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM orders WHERE created_at >= :from AND created_at <= :to "
        "ORDER BY created_at DESC"));
    q.bindValue(QStringLiteral(":from"), from);
    q.bindValue(QStringLiteral(":to"), to);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchByDateRange failed:" << q.lastError().text();
        return results;
    }
    while (q.next())
        results.append(rowToOrder(q));
    return results;
}

// ─── Fetch single order by order_number ───
// Used to check for duplicates before insertion, or to look up
// a specific order from the search box on the PrintingPage.
std::optional<Order> OrdersRepository::fetchByOrderNumber(const QString& orderNumber) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT * FROM orders WHERE order_number = :num LIMIT 1"));
    q.bindValue(QStringLiteral(":num"), orderNumber);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchByOrderNumber failed:" << q.lastError().text();
        return std::nullopt;
    }
    if (q.next())
        return rowToOrder(q);
    return std::nullopt;  // Not found
}

// ─── Insert a new order ───
// Called by OrdersViewModel::createOrder() after the user clicks
// "列印" (print) on the PrintingPage. At this point, only
// orderNumber and invoiceNumber are known — the scraper fills
// in buyerName, orderDate, and usingCoupon later.
bool OrdersRepository::insert(const Order& order)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO orders (id, order_number, invoice_number, order_date, "
        "buyer_name, status, using_coupon, created_by, created_at, updated_at) "
        "VALUES (:id, :orderNumber, :invoiceNumber, :orderDate, "
        ":buyerName, :status, :usingCoupon, :createdBy, :createdAt, :updatedAt)"));

    q.bindValue(QStringLiteral(":id"),            order.id);
    q.bindValue(QStringLiteral(":orderNumber"),   order.orderNumber);
    q.bindValue(QStringLiteral(":invoiceNumber"), order.invoiceNumber);
    q.bindValue(QStringLiteral(":orderDate"),     order.orderDate);
    q.bindValue(QStringLiteral(":buyerName"),     order.buyerName);
    q.bindValue(QStringLiteral(":status"),        order.status);
    q.bindValue(QStringLiteral(":usingCoupon"),   order.usingCoupon ? 1 : 0);
    q.bindValue(QStringLiteral(":createdBy"),     order.createdBy);
    q.bindValue(QStringLiteral(":createdAt"),     order.createdAt);
    q.bindValue(QStringLiteral(":updatedAt"),     order.updatedAt);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] insert failed:" << q.lastError().text();
        return false;
    }
    return true;
}

// ─── Update status ───
// Changes only the status column (e.g. "printed" → "shipped").
// Also bumps updated_at to the current UTC time.
bool OrdersRepository::updateStatus(const QString& id, const QString& status)
{
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE orders SET status = :status, updated_at = :now WHERE id = :id"));
    q.bindValue(QStringLiteral(":status"), status);
    q.bindValue(QStringLiteral(":now"),    now);
    q.bindValue(QStringLiteral(":id"),     id);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] updateStatus failed:" << q.lastError().text();
        return false;
    }
    // numRowsAffected() returns 0 if no row matched the WHERE clause
    return q.numRowsAffected() > 0;
}

// ─── Update from scraper results ───
// After the web scraper finishes processing an order, this method
// is called to fill in the fields that weren't available at creation
// time: buyer_name, order_date, using_coupon, and possibly a new status.
bool OrdersRepository::updateFromScraper(const QString& id,
                                          const QString& buyerName,
                                          const QString& orderDate,
                                          bool usingCoupon,
                                          const QString& status)
{
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE orders SET buyer_name = :buyer, order_date = :date, "
        "using_coupon = :coupon, status = :status, updated_at = :now "
        "WHERE id = :id"));
    q.bindValue(QStringLiteral(":buyer"),  buyerName);
    q.bindValue(QStringLiteral(":date"),   orderDate);
    q.bindValue(QStringLiteral(":coupon"), usingCoupon ? 1 : 0);
    q.bindValue(QStringLiteral(":status"), status);
    q.bindValue(QStringLiteral(":now"),    now);
    q.bindValue(QStringLiteral(":id"),     id);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] updateFromScraper failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

// ─── Delete ───
// Permanently removes an order from the database.
// Called when user clicks "刪除" (delete) on the PrintingPage.
bool OrdersRepository::remove(const QString& id)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM orders WHERE id = :id"));
    q.bindValue(QStringLiteral(":id"), id);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] remove failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

// ─── Count all ───
// Used by DashboardViewModel to display total order count on HomePage.
int OrdersRepository::countAll() const
{
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("SELECT COUNT(*) FROM orders"));
    return q.next() ? q.value(0).toInt() : 0;
}

// ─── Count today's orders ───
// Uses SQLite's date() function to compare just the date portion
// of created_at against today's date. Used for "今日貨單數量" on HomePage.
int OrdersRepository::countToday() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM orders WHERE date(created_at) = date('now')"));
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}

// ─── Count by status ───
// Used by DashboardViewModel to count orders in a specific state.
// Example: countByStatus("printed") gives the "pending" count.
int OrdersRepository::countByStatus(const QString& status) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT COUNT(*) FROM orders WHERE status = :s"));
    q.bindValue(QStringLiteral(":s"), status);
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}
