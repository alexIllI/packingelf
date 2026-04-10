#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QStringList>
#include <QVector>

#include "OrdersRepository.h"

struct OutboxMutation {
    QString mutationId;
    QString clientId;
    QString entityType;
    QString entityKey;
    QString operation;
    QString payloadJson;
    QString status;
    int attemptCount = 0;
    QString nextAttemptAt;
    QString lastError;
    QString createdAt;
    QString updatedAt;
};

class OutboxStore : public QObject {
    Q_OBJECT

public:
    explicit OutboxStore(QSqlDatabase db, QObject* parent = nullptr);

    QString enqueueUpsertOrder(const Order& order, const QString& clientId);
    QString enqueueDeleteOrder(const QString& orderNumber, const QString& clientId);

    QVector<OutboxMutation> pendingMutations(int limit = 25) const;
    bool markAcknowledged(const QStringList& mutationIds);
    bool markFailed(const QString& mutationId,
                    const QString& errorMessage,
                    int retryDelaySeconds = 30);

    int pendingCount() const;

signals:
    void pendingCountChanged();

private:
    QString enqueueMutation(const QString& clientId,
                            const QString& entityType,
                            const QString& entityKey,
                            const QString& operation,
                            const QString& payloadJson);

    QSqlDatabase m_db;
};
