// ─────────────────────────────────────────────────────────────
// OrdersViewModel.h
// QML-facing list model for order data.
//
// This is a QAbstractListModel, which means QML's ListView and
// our CustomTable component can use it directly as a `model`.
// Each row in the model corresponds to one Order in the database.
//
// The role names (defined in roleNames()) match the column "role"
// properties used in the QML CustomTable column definitions:
//   C++ Role           → QML role name → QML table column
//   OrderDateRole      → "date"        → 日期
//   BuyerNameRole      → "accountName" → 帳號名稱
//   OrderNumberRole    → "orderNumber" → 貨單號碼
//   etc.
//
// QML calls Q_INVOKABLE methods directly, for example:
//   OrdersVM.createOrder("PG02491384", "AB1234567")
//   OrdersVM.removeOrder(2)
//   OrdersVM.refresh()
//
// When data changes, this model emits:
//   - Standard model signals (beginInsertRows, etc.) for UI updates
//   - orderCreated/orderRemoved signals for DashboardViewModel
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <memory>

#include "OrdersRepository.h"

class OrdersViewModel : public QAbstractListModel {
    Q_OBJECT

    // Expose the total row count as a QML-bindable property.
    // HomePage can read this via: OrdersVM.count
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    // Custom roles for data() — each maps to a field in the Order struct.
    // Qt::UserRole + 1 avoids collision with Qt's built-in roles.
    enum Roles {
        IdRole = Qt::UserRole + 1,
        OrderNumberRole,
        InvoiceNumberRole,
        OrderDateRole,
        BuyerNameRole,
        StatusRole,
        UsingCouponRole,
        CreatedByRole,
        CreatedAtRole,
        UpdatedAtRole
    };

    // Constructor takes a shared pointer to the repository.
    // This is shared with DashboardViewModel so both can query the same DB.
    explicit OrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                              QObject* parent = nullptr);

    // ─── QAbstractListModel interface (required overrides) ───
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ─── QML-callable actions ───

    // Create a new order with the given order number and invoice number.
    // Generates a UUID, inserts into DB, prepends to the model, and
    // emits orderCreated. Returns the generated UUID, or "" on failure.
    Q_INVOKABLE QString createOrder(const QString& orderNumber,
                                     const QString& invoiceNumber);

    // Remove the order at the given row index from the DB and model.
    // Returns true on success. Emits orderRemoved.
    Q_INVOKABLE bool removeOrder(int row);

    // Update the status of the order at the given row index.
    // E.g., updateOrderStatus(0, "shipped")
    Q_INVOKABLE bool updateOrderStatus(int row, const QString& newStatus);

    // Reload all data from the database into the model.
    // Called on startup and can be called manually to force-refresh.
    Q_INVOKABLE void refresh();

signals:
    void countChanged();                   // Emitted when rowCount changes
    void orderCreated(const QString& id);  // Emitted after successful insert
    void orderRemoved(const QString& id);  // Emitted after successful delete

private:
    std::shared_ptr<OrdersRepository> m_repo;  // Database access layer
    QVector<Order> m_orders;                    // In-memory cache of all orders
};
