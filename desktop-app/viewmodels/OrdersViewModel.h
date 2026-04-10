#pragma once

#include <QAbstractListModel>
#include <QVector>
#include <memory>

#include "OrdersRepository.h"
#include "OutboxStore.h"
#include "ScraperService.h"

class OrdersViewModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        OrderNumberRole,
        InvoiceNumberRole,
        OrderDateRole,
        BuyerNameRole,
        StatusRole,
        UsingCouponRole,
        CreatedByRole,
        UpdatedByRole,
        CreatedAtRole,
        UpdatedAtRole
    };

    explicit OrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                             OutboxStore* outbox,
                             QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int pendingCount() const;

    Q_INVOKABLE QString submitForScrape(const QString& orderNumber,
                                        const QString& invoiceNumber);
    Q_INVOKABLE bool removeOrder(int row);
    Q_INVOKABLE void refresh();

signals:
    void countChanged();
    void pendingCountChanged();
    void orderCreated(const QString& id);
    void orderRemoved(const QString& id);

public slots:
    void handleScraperFinished(const QString& submissionId, const ScraperResult& result);
    void handleScraperFailed(const QString& submissionId, const QString& reason);

private:
    std::optional<QString> normalizeStatus(const QString& scraperStatus) const;
    void emitModelChanged();

    std::shared_ptr<OrdersRepository> m_repo;
    OutboxStore* m_outbox;
    QVector<Order> m_orders;
};
