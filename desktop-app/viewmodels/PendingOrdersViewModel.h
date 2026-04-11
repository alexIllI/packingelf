#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <memory>

#include "OrdersRepository.h"

class PendingOrdersViewModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        OrderNumberRole,
        RemarkRole,
        DateRole,
        CreatedAtRole,
        UpdatedAtRole
    };

    explicit PendingOrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                                    QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString addPendingOrder(const QString& orderNumber, const QString& remark);
    Q_INVOKABLE bool removePendingOrder(int row);
    Q_INVOKABLE QString orderNumberAt(int row) const;
    Q_INVOKABLE QString pendingIdAt(int row) const;
    Q_INVOKABLE void refresh();

signals:
    void countChanged();

private:
    std::shared_ptr<OrdersRepository> m_repo;
    QVector<PendingOrder> m_pendingOrders;
};
