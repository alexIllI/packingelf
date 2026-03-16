// ─────────────────────────────────────────────────────────────
// OrdersRepository.h
// Data access layer for the `orders` table.
//
// This class provides CRUD operations and aggregate queries
// for order records in the local SQLite database.
//
// Design decisions:
//   - This is a plain C++ class (not a QObject), so it can be
//     shared between multiple ViewModels via shared_ptr.
//   - All methods take/return value types (Order struct, QString)
//     which makes them easy to test and thread-safe to copy.
//   - The `Order` struct mirrors the database columns exactly.
//
// Usage:
//   OrdersRepository repo(db);
//   repo.insert(order);
//   auto all = repo.fetchAll();
//   int count = repo.countToday();
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QSqlDatabase>
#include <QString>
#include <QVector>
#include <optional>

// ─── Order data struct ───
// Represents a single row in the `orders` table.
// Fields that come from the web scraper (orderDate, buyerName,
// usingCoupon) may be empty when the order is first created
// and will be populated later when the scraper finishes.
struct Order {
    QString id;              // UUID, generated in OrdersViewModel::createOrder()
    QString orderNumber;     // e.g. "PG02491384" (prefix + 5-digit suffix)
    QString invoiceNumber;   // e.g. "AB1234567", entered by user
    QString orderDate;       // ISO date string from scraper (may be empty)
    QString buyerName;       // Buyer's name from scraper (may be empty)
    QString status;          // One of: printed | shipped | returned | closed
    bool    usingCoupon = false;  // Whether buyer used a coupon (from scraper)
    QString createdBy;       // Username who created this record (Phase 2)
    QString createdAt;       // ISO 8601 timestamp of when this record was created
    QString updatedAt;       // ISO 8601 timestamp of last modification
};

// ─── CRUD operations on the orders table ───
class OrdersRepository {
public:
    // Constructor takes a reference to the database connection.
    // The Database object must outlive the repository.
    explicit OrdersRepository(QSqlDatabase& db);

    // ─── Read operations ───

    // Fetch all orders from the database, sorted newest first (by created_at).
    QVector<Order> fetchAll() const;

    // Fetch orders within a date range (inclusive, by created_at column).
    // Used by the HistoryPage filter controls.
    QVector<Order> fetchByDateRange(const QString& from, const QString& to) const;

    // Fetch a single order by its order_number.
    // Returns std::nullopt if no order with that number exists.
    std::optional<Order> fetchByOrderNumber(const QString& orderNumber) const;

    // ─── Write operations ───

    // Insert a new order into the database. Returns true on success.
    bool insert(const Order& order);

    // Update only the status field of an existing order.
    // Also updates the updated_at timestamp. Returns true on success.
    bool updateStatus(const QString& id, const QString& status);

    // Update fields that come from the web scraper after an order is created.
    // This is called when the scraper finishes fetching buyer info, date, etc.
    bool updateFromScraper(const QString& id,
                           const QString& buyerName,
                           const QString& orderDate,
                           bool usingCoupon,
                           const QString& status);

    // Delete an order by its UUID. Returns true if a row was actually deleted.
    bool remove(const QString& id);

    // ─── Aggregate queries (used by DashboardViewModel) ───

    int countAll() const;                            // Total number of orders
    int countToday() const;                          // Orders created today
    int countByStatus(const QString& status) const;  // Orders with a specific status

private:
    // Helper: converts a positioned QSqlQuery row into an Order struct.
    Order rowToOrder(const class QSqlQuery& q) const;

    QSqlDatabase& m_db;  // Reference to the shared database connection
};
