#include "OutboxStore.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QDebug>

namespace {
QString nowIsoUtc()
{
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}
}

OutboxStore::OutboxStore(QSqlDatabase db, QObject* parent)
    : QObject(parent)
    , m_db(std::move(db))
{
}

QString OutboxStore::enqueueMutation(const QString& clientId,
                                     const QString& entityType,
                                     const QString& entityKey,
                                     const QString& operation,
                                     const QString& payloadJson)
{
    const QString mutationId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString now = nowIsoUtc();

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO outbox ("
        " mutation_id, client_id, entity_type, entity_key, operation, payload_json,"
        " status, attempt_count, next_attempt_at, last_error, created_at, updated_at"
        ") VALUES ("
        " :mutationId, :clientId, :entityType, :entityKey, :operation, :payloadJson,"
        " 'pending', 0, :nextAttemptAt, '', :createdAt, :updatedAt"
        ")"));
    q.bindValue(QStringLiteral(":mutationId"), mutationId);
    q.bindValue(QStringLiteral(":clientId"), clientId);
    q.bindValue(QStringLiteral(":entityType"), entityType);
    q.bindValue(QStringLiteral(":entityKey"), entityKey);
    q.bindValue(QStringLiteral(":operation"), operation);
    q.bindValue(QStringLiteral(":payloadJson"), payloadJson);
    q.bindValue(QStringLiteral(":nextAttemptAt"), now);
    q.bindValue(QStringLiteral(":createdAt"), now);
    q.bindValue(QStringLiteral(":updatedAt"), now);

    if (!q.exec()) {
        qWarning() << "[OutboxStore] enqueueMutation failed:" << q.lastError().text();
        return {};
    }

    emit pendingCountChanged();
    return mutationId;
}

QString OutboxStore::enqueueUpsertOrder(const Order& order, const QString& clientId)
{
    const QJsonObject payload{
        { QStringLiteral("id"), order.id },
        { QStringLiteral("order_number"), order.orderNumber },
        { QStringLiteral("invoice_number"), order.invoiceNumber },
        { QStringLiteral("order_date"), order.orderDate },
        { QStringLiteral("buyer_name"), order.buyerName },
        { QStringLiteral("order_status"), order.orderStatus },
        { QStringLiteral("using_coupon"), order.usingCoupon },
        { QStringLiteral("created_by_client_id"), order.createdByClientId },
        { QStringLiteral("updated_by_client_id"), order.updatedByClientId },
        { QStringLiteral("created_at"), order.createdAt },
        { QStringLiteral("updated_at"), order.updatedAt },
        { QStringLiteral("deleted_at"), order.deletedAt },
    };

    return enqueueMutation(
        clientId,
        QStringLiteral("order"),
        order.orderNumber,
        QStringLiteral("upsert_order"),
        QString::fromUtf8(QJsonDocument(payload).toJson(QJsonDocument::Compact)));
}

QString OutboxStore::enqueueDeleteOrder(const QString& orderNumber, const QString& clientId)
{
    const QJsonObject payload{
        { QStringLiteral("order_number"), orderNumber },
        { QStringLiteral("deleted_at"), nowIsoUtc() },
        { QStringLiteral("updated_by_client_id"), clientId },
    };

    return enqueueMutation(
        clientId,
        QStringLiteral("order"),
        orderNumber,
        QStringLiteral("delete_order"),
        QString::fromUtf8(QJsonDocument(payload).toJson(QJsonDocument::Compact)));
}

QVector<OutboxMutation> OutboxStore::pendingMutations(int limit) const
{
    QVector<OutboxMutation> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM outbox "
        "WHERE status IN ('pending', 'failed') AND next_attempt_at <= :now "
        "ORDER BY created_at ASC LIMIT :limit"));
    q.bindValue(QStringLiteral(":now"), nowIsoUtc());
    q.bindValue(QStringLiteral(":limit"), limit);

    if (!q.exec()) {
        qWarning() << "[OutboxStore] pendingMutations failed:" << q.lastError().text();
        return results;
    }

    while (q.next()) {
        OutboxMutation mutation;
        mutation.mutationId = q.value(QStringLiteral("mutation_id")).toString();
        mutation.clientId = q.value(QStringLiteral("client_id")).toString();
        mutation.entityType = q.value(QStringLiteral("entity_type")).toString();
        mutation.entityKey = q.value(QStringLiteral("entity_key")).toString();
        mutation.operation = q.value(QStringLiteral("operation")).toString();
        mutation.payloadJson = q.value(QStringLiteral("payload_json")).toString();
        mutation.status = q.value(QStringLiteral("status")).toString();
        mutation.attemptCount = q.value(QStringLiteral("attempt_count")).toInt();
        mutation.nextAttemptAt = q.value(QStringLiteral("next_attempt_at")).toString();
        mutation.lastError = q.value(QStringLiteral("last_error")).toString();
        mutation.createdAt = q.value(QStringLiteral("created_at")).toString();
        mutation.updatedAt = q.value(QStringLiteral("updated_at")).toString();
        results.append(mutation);
    }

    return results;
}

bool OutboxStore::markAcknowledged(const QStringList& mutationIds)
{
    if (mutationIds.isEmpty())
        return true;

    QSqlQuery q(m_db);
    if (!m_db.transaction()) {
        qWarning() << "[OutboxStore] failed to start transaction for ack";
        return false;
    }

    q.prepare(QStringLiteral(
        "UPDATE outbox SET status = 'acked', updated_at = :updatedAt WHERE mutation_id = :mutationId"));
    const QString now = nowIsoUtc();
    for (const QString& mutationId : mutationIds) {
        q.bindValue(QStringLiteral(":updatedAt"), now);
        q.bindValue(QStringLiteral(":mutationId"), mutationId);
        if (!q.exec()) {
            m_db.rollback();
            qWarning() << "[OutboxStore] markAcknowledged failed:" << q.lastError().text();
            return false;
        }
    }

    if (!m_db.commit()) {
        qWarning() << "[OutboxStore] ack commit failed:" << m_db.lastError().text();
        return false;
    }

    emit pendingCountChanged();
    return true;
}

bool OutboxStore::markFailed(const QString& mutationId,
                             const QString& errorMessage,
                             int retryDelaySeconds)
{
    const QString nextAttempt = QDateTime::currentDateTimeUtc()
        .addSecs(retryDelaySeconds)
        .toString(Qt::ISODate);
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE outbox "
        "SET status = 'failed', attempt_count = attempt_count + 1, "
        "last_error = :lastError, next_attempt_at = :nextAttemptAt, updated_at = :updatedAt "
        "WHERE mutation_id = :mutationId"));
    q.bindValue(QStringLiteral(":lastError"), errorMessage);
    q.bindValue(QStringLiteral(":nextAttemptAt"), nextAttempt);
    q.bindValue(QStringLiteral(":updatedAt"), nowIsoUtc());
    q.bindValue(QStringLiteral(":mutationId"), mutationId);

    if (!q.exec()) {
        qWarning() << "[OutboxStore] markFailed failed:" << q.lastError().text();
        return false;
    }

    emit pendingCountChanged();
    return true;
}

int OutboxStore::pendingCount() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM outbox WHERE status IN ('pending', 'failed')"));
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}
