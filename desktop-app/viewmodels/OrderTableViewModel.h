#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <memory>

#include "OrdersRepository.h"

class OrderTableViewModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        OrderNumberRole,
        InvoiceNumberRole,
        OrderDateRole,
        BuyerNameRole,
        TotalAmountRole,
        StatusRole,
        UsingCouponRole,
        CreatedByRole,
        UpdatedByRole,
        CreatedAtRole,
        UpdatedAtRole
    };

    explicit OrderTableViewModel(std::shared_ptr<OrdersRepository> repo,
                                 QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString orderNumberAt(int row) const;
    Q_INVOKABLE int findRow(const QString& query) const;
    Q_INVOKABLE void applyFilters(const QString& statusFilter,
                                  const QString& searchQuery,
                                  const QString& fromDate,
                                  const QString& toDate);
    Q_INVOKABLE void setStatusFilter(const QString& statusFilter);
    Q_INVOKABLE void setRecentHoursFilter(int hours);
    Q_INVOKABLE void clearFilters();
    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    bool matchesFilters(const Order& order) const;
    QString normalizedStatus(const QString& status) const;

    std::shared_ptr<OrdersRepository> m_repo;
    QVector<Order> m_orders;
    QString m_statusFilter;
    QString m_searchQuery;
    QString m_fromDate;
    QString m_toDate;
    int m_recentHours = -1;
};
