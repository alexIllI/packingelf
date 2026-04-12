#pragma once

#include <QSqlDatabase>
#include <QString>
#include <QVector>

#include <optional>

struct Order {
    QString id;
    QString orderNumber;
    QString invoiceNumber;
    QString orderDate;
    QString buyerName;
    qint64 totalAmount = 0;
    QString orderStatus;
    bool usingCoupon = false;
    QString createdByClientId;
    QString updatedByClientId;
    QString createdAt;
    QString updatedAt;
    QString deletedAt;
    qint64 serverRevision = 0;
};

struct ScrapeSubmission {
    QString submissionId;
    QString orderNumber;
    QString invoiceNumber;
    QString state;
    QString errorMessage;
    QString createdAt;
    QString updatedAt;
};

struct SyncConfig {
    QString clientId;
    QString clientName;
    QString hostBaseUrl;
    QString pairingToken;
    qint64 lastPulledRevision = 0;
    QString lastDiscoveryAt;
};

struct PendingOrder {
    QString id;
    QString orderNumber;
    QString remark;
    QString createdAt;
    QString updatedAt;
};

class OrdersRepository {
public:
    explicit OrdersRepository(QSqlDatabase& db);

    QVector<Order> fetchAll() const;
    QVector<Order> fetchByDateRange(const QString& from, const QString& to) const;
    std::optional<Order> fetchByOrderNumber(const QString& orderNumber) const;

    bool upsertOrder(const Order& order);
    bool softDelete(const QString& id, const QString& updatedByClientId);
    bool applyRemoteDelete(const QString& orderNumber,
                           const QString& deletedAt,
                           const QString& updatedByClientId,
                           qint64 serverRevision);

    std::optional<ScrapeSubmission> createSubmission(const QString& orderNumber,
                                                     const QString& invoiceNumber);
    std::optional<ScrapeSubmission> fetchSubmission(const QString& submissionId) const;
    bool updateSubmissionState(const QString& submissionId,
                               const QString& state,
                               const QString& errorMessage = QString());
    bool deleteSubmission(const QString& submissionId);

    QVector<PendingOrder> fetchPendingOrders() const;
    std::optional<PendingOrder> createPendingOrder(const QString& orderNumber,
                                                   const QString& remark);
    bool deletePendingOrder(const QString& id);

    int countAll() const;
    int countToday() const;
    int countPendingSubmissions() const;

    SyncConfig syncConfig() const;
    bool saveSyncConfig(const SyncConfig& config);
    bool updateLastPulledRevision(qint64 revision);

private:
    Order rowToOrder(const class QSqlQuery& q) const;
    ScrapeSubmission rowToSubmission(const class QSqlQuery& q) const;
    PendingOrder rowToPendingOrder(const class QSqlQuery& q) const;
    std::optional<SyncConfig> readSyncConfig() const;

    QSqlDatabase& m_db;
};
