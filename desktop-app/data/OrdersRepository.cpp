#include "OrdersRepository.h"

#include <QDateTime>
#include <QHostInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>
#include <QDebug>

namespace {
QString nowIsoUtc()
{
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}

QString envOrDefault(const char* name, const QString& fallback)
{
    const QString value = QProcessEnvironment::systemEnvironment().value(QString::fromLatin1(name));
    return value.isEmpty() ? fallback : value;
}
}

OrdersRepository::OrdersRepository(QSqlDatabase& db)
    : m_db(db)
{
}

Order OrdersRepository::rowToOrder(const QSqlQuery& q) const
{
    Order o;
    o.id                = q.value(QStringLiteral("id")).toString();
    o.orderNumber       = q.value(QStringLiteral("order_number")).toString();
    o.invoiceNumber     = q.value(QStringLiteral("invoice_number")).toString();
    o.orderDate         = q.value(QStringLiteral("order_date")).toString();
    o.buyerName         = q.value(QStringLiteral("buyer_name")).toString();
    o.totalAmount       = q.value(QStringLiteral("total_amount")).toLongLong();
    o.orderStatus       = q.value(QStringLiteral("order_status")).toString();
    o.usingCoupon       = q.value(QStringLiteral("using_coupon")).toBool();
    o.createdByClientId = q.value(QStringLiteral("created_by_client_id")).toString();
    o.updatedByClientId = q.value(QStringLiteral("updated_by_client_id")).toString();
    o.createdAt         = q.value(QStringLiteral("created_at")).toString();
    o.updatedAt         = q.value(QStringLiteral("updated_at")).toString();
    o.deletedAt         = q.value(QStringLiteral("deleted_at")).toString();
    o.serverRevision    = q.value(QStringLiteral("server_revision")).toLongLong();
    return o;
}

ScrapeSubmission OrdersRepository::rowToSubmission(const QSqlQuery& q) const
{
    ScrapeSubmission submission;
    submission.submissionId = q.value(QStringLiteral("submission_id")).toString();
    submission.orderNumber  = q.value(QStringLiteral("order_number")).toString();
    submission.invoiceNumber = q.value(QStringLiteral("invoice_number")).toString();
    submission.state        = q.value(QStringLiteral("state")).toString();
    submission.errorMessage = q.value(QStringLiteral("error_message")).toString();
    submission.createdAt    = q.value(QStringLiteral("created_at")).toString();
    submission.updatedAt    = q.value(QStringLiteral("updated_at")).toString();
    return submission;
}

PendingOrder OrdersRepository::rowToPendingOrder(const QSqlQuery& q) const
{
    PendingOrder pending;
    pending.id = q.value(QStringLiteral("id")).toString();
    pending.orderNumber = q.value(QStringLiteral("order_number")).toString();
    pending.remark = q.value(QStringLiteral("remark")).toString();
    pending.createdAt = q.value(QStringLiteral("created_at")).toString();
    pending.updatedAt = q.value(QStringLiteral("updated_at")).toString();
    return pending;
}

QVector<Order> OrdersRepository::fetchAll() const
{
    QVector<Order> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM orders "
        "WHERE deleted_at IS NULL OR deleted_at = '' "
        "ORDER BY created_at DESC"));
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchAll failed:" << q.lastError().text();
        return results;
    }

    while (q.next())
        results.append(rowToOrder(q));
    return results;
}

QVector<Order> OrdersRepository::fetchByDateRange(const QString& from, const QString& to) const
{
    QVector<Order> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM orders "
        "WHERE (deleted_at IS NULL OR deleted_at = '') "
        "AND created_at >= :from AND created_at <= :to "
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

std::optional<Order> OrdersRepository::fetchByOrderNumber(const QString& orderNumber) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM orders "
        "WHERE order_number = :orderNumber "
        "AND (deleted_at IS NULL OR deleted_at = '') "
        "LIMIT 1"));
    q.bindValue(QStringLiteral(":orderNumber"), orderNumber);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchByOrderNumber failed:" << q.lastError().text();
        return std::nullopt;
    }

    if (q.next())
        return rowToOrder(q);
    return std::nullopt;
}

bool OrdersRepository::upsertOrder(const Order& order)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO orders ("
        " id, order_number, invoice_number, order_date, buyer_name, total_amount, order_status,"
        " using_coupon, created_by_client_id, updated_by_client_id,"
        " created_at, updated_at, deleted_at, server_revision"
        ") VALUES ("
        " :id, :orderNumber, :invoiceNumber, :orderDate, :buyerName, :totalAmount, :orderStatus,"
        " :usingCoupon, :createdByClientId, :updatedByClientId,"
        " :createdAt, :updatedAt, :deletedAt, :serverRevision"
        ") "
        "ON CONFLICT(order_number) DO UPDATE SET "
        " invoice_number = excluded.invoice_number,"
        " order_date = excluded.order_date,"
        " buyer_name = excluded.buyer_name,"
        " total_amount = excluded.total_amount,"
        " order_status = excluded.order_status,"
        " using_coupon = excluded.using_coupon,"
        " updated_by_client_id = excluded.updated_by_client_id,"
        " updated_at = excluded.updated_at,"
        " deleted_at = excluded.deleted_at,"
        " server_revision = excluded.server_revision"));

    q.bindValue(QStringLiteral(":id"), order.id);
    q.bindValue(QStringLiteral(":orderNumber"), order.orderNumber);
    q.bindValue(QStringLiteral(":invoiceNumber"), order.invoiceNumber);
    q.bindValue(QStringLiteral(":orderDate"), order.orderDate);
    q.bindValue(QStringLiteral(":buyerName"), order.buyerName);
    q.bindValue(QStringLiteral(":totalAmount"), order.totalAmount);
    q.bindValue(QStringLiteral(":orderStatus"), order.orderStatus);
    q.bindValue(QStringLiteral(":usingCoupon"), order.usingCoupon ? 1 : 0);
    q.bindValue(QStringLiteral(":createdByClientId"), order.createdByClientId);
    q.bindValue(QStringLiteral(":updatedByClientId"), order.updatedByClientId);
    q.bindValue(QStringLiteral(":createdAt"), order.createdAt);
    q.bindValue(QStringLiteral(":updatedAt"), order.updatedAt);
    q.bindValue(QStringLiteral(":deletedAt"), order.deletedAt);
    q.bindValue(QStringLiteral(":serverRevision"), order.serverRevision);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] upsertOrder failed:" << q.lastError().text();
        return false;
    }
    return true;
}

bool OrdersRepository::softDelete(const QString& id, const QString& updatedByClientId)
{
    const QString deletedAt = nowIsoUtc();
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE orders SET deleted_at = :deletedAt, updated_at = :updatedAt, "
        "updated_by_client_id = :updatedByClientId "
        "WHERE id = :id"));
    q.bindValue(QStringLiteral(":deletedAt"), deletedAt);
    q.bindValue(QStringLiteral(":updatedAt"), deletedAt);
    q.bindValue(QStringLiteral(":updatedByClientId"), updatedByClientId);
    q.bindValue(QStringLiteral(":id"), id);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] softDelete failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool OrdersRepository::applyRemoteDelete(const QString& orderNumber,
                                         const QString& deletedAt,
                                         const QString& updatedByClientId,
                                         qint64 serverRevision)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE orders SET deleted_at = :deletedAt, updated_at = :updatedAt, "
        "updated_by_client_id = :updatedByClientId, server_revision = :serverRevision "
        "WHERE order_number = :orderNumber"));
    q.bindValue(QStringLiteral(":deletedAt"), deletedAt);
    q.bindValue(QStringLiteral(":updatedAt"), deletedAt);
    q.bindValue(QStringLiteral(":updatedByClientId"), updatedByClientId);
    q.bindValue(QStringLiteral(":serverRevision"), serverRevision);
    q.bindValue(QStringLiteral(":orderNumber"), orderNumber);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] applyRemoteDelete failed:" << q.lastError().text();
        return false;
    }
    return true;
}

std::optional<ScrapeSubmission> OrdersRepository::createSubmission(const QString& orderNumber,
                                                                   const QString& invoiceNumber)
{
    ScrapeSubmission submission;
    submission.submissionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    submission.orderNumber = orderNumber;
    submission.invoiceNumber = invoiceNumber;
    submission.state = QStringLiteral("queued");
    submission.createdAt = nowIsoUtc();
    submission.updatedAt = submission.createdAt;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO scrape_submissions ("
        " submission_id, order_number, invoice_number, state, error_message, created_at, updated_at"
        ") VALUES ("
        " :submissionId, :orderNumber, :invoiceNumber, :state, :errorMessage, :createdAt, :updatedAt"
        ")"));
    q.bindValue(QStringLiteral(":submissionId"), submission.submissionId);
    q.bindValue(QStringLiteral(":orderNumber"), submission.orderNumber);
    q.bindValue(QStringLiteral(":invoiceNumber"), submission.invoiceNumber);
    q.bindValue(QStringLiteral(":state"), submission.state);
    q.bindValue(QStringLiteral(":errorMessage"), submission.errorMessage);
    q.bindValue(QStringLiteral(":createdAt"), submission.createdAt);
    q.bindValue(QStringLiteral(":updatedAt"), submission.updatedAt);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] createSubmission failed:" << q.lastError().text();
        return std::nullopt;
    }

    return submission;
}

std::optional<ScrapeSubmission> OrdersRepository::fetchSubmission(const QString& submissionId) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM scrape_submissions WHERE submission_id = :submissionId LIMIT 1"));
    q.bindValue(QStringLiteral(":submissionId"), submissionId);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchSubmission failed:" << q.lastError().text();
        return std::nullopt;
    }

    if (q.next())
        return rowToSubmission(q);
    return std::nullopt;
}

bool OrdersRepository::updateSubmissionState(const QString& submissionId,
                                             const QString& state,
                                             const QString& errorMessage)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE scrape_submissions "
        "SET state = :state, error_message = :errorMessage, updated_at = :updatedAt "
        "WHERE submission_id = :submissionId"));
    q.bindValue(QStringLiteral(":state"), state);
    q.bindValue(QStringLiteral(":errorMessage"), errorMessage);
    q.bindValue(QStringLiteral(":updatedAt"), nowIsoUtc());
    q.bindValue(QStringLiteral(":submissionId"), submissionId);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] updateSubmissionState failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool OrdersRepository::deleteSubmission(const QString& submissionId)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM scrape_submissions WHERE submission_id = :submissionId"));
    q.bindValue(QStringLiteral(":submissionId"), submissionId);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] deleteSubmission failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVector<PendingOrder> OrdersRepository::fetchPendingOrders() const
{
    QVector<PendingOrder> results;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM pending_orders ORDER BY created_at DESC"));
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] fetchPendingOrders failed:" << q.lastError().text();
        return results;
    }

    while (q.next())
        results.append(rowToPendingOrder(q));
    return results;
}

std::optional<PendingOrder> OrdersRepository::createPendingOrder(const QString& orderNumber,
                                                                 const QString& remark)
{
    PendingOrder pending;
    pending.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    pending.orderNumber = orderNumber;
    pending.remark = remark;
    pending.createdAt = nowIsoUtc();
    pending.updatedAt = pending.createdAt;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO pending_orders ("
        " id, order_number, remark, created_at, updated_at"
        ") VALUES ("
        " :id, :orderNumber, :remark, :createdAt, :updatedAt"
        ") "
        "ON CONFLICT(order_number) DO UPDATE SET "
        " remark = excluded.remark,"
        " updated_at = excluded.updated_at"));
    q.bindValue(QStringLiteral(":id"), pending.id);
    q.bindValue(QStringLiteral(":orderNumber"), pending.orderNumber);
    q.bindValue(QStringLiteral(":remark"), pending.remark);
    q.bindValue(QStringLiteral(":createdAt"), pending.createdAt);
    q.bindValue(QStringLiteral(":updatedAt"), pending.updatedAt);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] createPendingOrder failed:" << q.lastError().text();
        return std::nullopt;
    }

    QSqlQuery fetch(m_db);
    fetch.prepare(QStringLiteral(
        "SELECT * FROM pending_orders WHERE order_number = :orderNumber LIMIT 1"));
    fetch.bindValue(QStringLiteral(":orderNumber"), pending.orderNumber);
    if (!fetch.exec()) {
        qWarning() << "[OrdersRepo] createPendingOrder fetch failed:" << fetch.lastError().text();
        return std::nullopt;
    }

    if (fetch.next())
        return rowToPendingOrder(fetch);
    return pending;
}

bool OrdersRepository::deletePendingOrder(const QString& id)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("DELETE FROM pending_orders WHERE id = :id"));
    q.bindValue(QStringLiteral(":id"), id);
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] deletePendingOrder failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

int OrdersRepository::countAll() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM orders WHERE deleted_at IS NULL OR deleted_at = ''"));
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}

int OrdersRepository::countToday() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM orders "
        "WHERE (deleted_at IS NULL OR deleted_at = '') "
        "AND date(created_at) = date('now')"));
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}

int OrdersRepository::countPendingSubmissions() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM scrape_submissions "
        "WHERE state IN ('queued', 'scraping')"));
    q.exec();
    return q.next() ? q.value(0).toInt() : 0;
}

std::optional<SyncConfig> OrdersRepository::readSyncConfig() const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT * FROM sync_state WHERE id = 1"));
    if (!q.exec()) {
        qWarning() << "[OrdersRepo] readSyncConfig failed:" << q.lastError().text();
        return std::nullopt;
    }

    if (!q.next())
        return std::nullopt;

    SyncConfig config;
    config.clientId = q.value(QStringLiteral("client_id")).toString();
    config.clientName = q.value(QStringLiteral("client_name")).toString();
    config.hostBaseUrl = q.value(QStringLiteral("host_base_url")).toString();
    config.pairingToken = q.value(QStringLiteral("pairing_token")).toString();
    config.lastPulledRevision = q.value(QStringLiteral("last_pulled_revision")).toLongLong();
    config.lastDiscoveryAt = q.value(QStringLiteral("last_discovery_at")).toString();
    return config;
}

SyncConfig OrdersRepository::syncConfig() const
{
    auto existing = readSyncConfig();
    if (existing.has_value())
        return *existing;

    SyncConfig config;
    config.clientId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    config.clientName = QHostInfo::localHostName();
    if (config.clientName.isEmpty())
        config.clientName = QStringLiteral("packingelf-client");
    config.hostBaseUrl = envOrDefault("PACKINGELF_HOST_URL", QStringLiteral("http://127.0.0.1:48080"));
    config.pairingToken = envOrDefault("PACKINGELF_PAIRING_TOKEN", QStringLiteral("dev-token"));
    config.lastPulledRevision = 0;
    config.lastDiscoveryAt = QString();

    const_cast<OrdersRepository*>(this)->saveSyncConfig(config);
    return config;
}

bool OrdersRepository::saveSyncConfig(const SyncConfig& config)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO sync_state ("
        " id, client_id, client_name, host_base_url, pairing_token, last_pulled_revision, last_discovery_at"
        ") VALUES ("
        " 1, :clientId, :clientName, :hostBaseUrl, :pairingToken, :lastPulledRevision, :lastDiscoveryAt"
        ") "
        "ON CONFLICT(id) DO UPDATE SET "
        " client_id = excluded.client_id,"
        " client_name = excluded.client_name,"
        " host_base_url = excluded.host_base_url,"
        " pairing_token = excluded.pairing_token,"
        " last_pulled_revision = excluded.last_pulled_revision,"
        " last_discovery_at = excluded.last_discovery_at"));
    q.bindValue(QStringLiteral(":clientId"), config.clientId);
    q.bindValue(QStringLiteral(":clientName"), config.clientName);
    q.bindValue(QStringLiteral(":hostBaseUrl"), config.hostBaseUrl);
    q.bindValue(QStringLiteral(":pairingToken"), config.pairingToken);
    q.bindValue(QStringLiteral(":lastPulledRevision"), config.lastPulledRevision);
    q.bindValue(QStringLiteral(":lastDiscoveryAt"), config.lastDiscoveryAt);

    if (!q.exec()) {
        qWarning() << "[OrdersRepo] saveSyncConfig failed:" << q.lastError().text();
        return false;
    }
    return true;
}

bool OrdersRepository::updateLastPulledRevision(qint64 revision)
{
    SyncConfig config = syncConfig();
    config.lastPulledRevision = revision;
    return saveSyncConfig(config);
}
