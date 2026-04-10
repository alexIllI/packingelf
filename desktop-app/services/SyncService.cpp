#include "SyncService.h"

#include "OrdersRepository.h"

#include <QJsonDocument>
#include <QJsonObject>

SyncService::SyncService(std::shared_ptr<OrdersRepository> repo,
                         std::unique_ptr<OutboxStore> outbox,
                         std::unique_ptr<HostClient> hostClient,
                         QObject* parent)
    : QObject(parent)
    , m_repo(std::move(repo))
    , m_outbox(std::move(outbox))
    , m_hostClient(std::move(hostClient))
{
    const SyncConfig config = m_repo->syncConfig();
    m_hostClient->setBaseUrl(config.hostBaseUrl);
    m_hostClient->setPairingToken(config.pairingToken);
    m_hostClient->setClientIdentity(config.clientId, config.clientName);

    connect(&m_timer, &QTimer::timeout, this, &SyncService::triggerSync);
    m_timer.setInterval(5000);
    m_timer.start();

    connect(m_outbox.get(), &OutboxStore::pendingCountChanged, this, [this]() {
        emit statusChanged();
    });
    connect(m_hostClient.get(), &HostClient::healthCheckFinished, this, [this](bool ok, const QString& message) {
        m_statusText = ok ? QStringLiteral("Host reachable") : message;
        emit statusChanged();
    });
    connect(m_hostClient.get(), &HostClient::pairingFinished, this, &SyncService::onPairingFinished);
    connect(m_hostClient.get(), &HostClient::mutationsPushed, this, &SyncService::onMutationsPushed);
    connect(m_hostClient.get(), &HostClient::changesReceived, this, &SyncService::onChangesReceived);
}

bool SyncService::hostOnline() const
{
    return m_hostClient->online();
}

int SyncService::pendingOutboxCount() const
{
    return m_outbox ? m_outbox->pendingCount() : 0;
}

QString SyncService::hostBaseUrl() const
{
    return m_hostClient ? m_hostClient->baseUrl() : QString();
}

void SyncService::testConnection()
{
    if (!m_hostClient)
        return;

    m_statusText = QStringLiteral("Testing host connection...");
    emit statusChanged();
    m_hostClient->testConnection();
}

void SyncService::triggerSync()
{
    if (!m_hostClient || !m_outbox || !m_repo || m_cycleInFlight)
        return;

    if (m_hostClient->baseUrl().isEmpty()) {
        m_statusText = QStringLiteral("Host sync is not configured");
        emit statusChanged();
        return;
    }

    m_cycleInFlight = true;
    m_statusText = QStringLiteral("Pairing with host...");
    emit statusChanged();
    m_hostClient->pair();
}

void SyncService::onPairingFinished(bool ok, qint64 initialRevision, const QString& message)
{
    if (!ok) {
        finishCycle(message.isEmpty() ? QStringLiteral("Pairing failed") : message);
        return;
    }

    SyncConfig config = m_repo->syncConfig();
    if (config.lastPulledRevision == 0 && initialRevision > 0) {
        config.lastPulledRevision = initialRevision;
        m_repo->saveSyncConfig(config);
    }

    const QVector<OutboxMutation> pending = m_outbox->pendingMutations();
    if (!pending.isEmpty()) {
        m_statusText = QStringLiteral("Pushing queued mutations...");
        emit statusChanged();
        m_hostClient->pushMutations(pending);
        return;
    }

    m_statusText = QStringLiteral("Fetching remote changes...");
    emit statusChanged();
    m_hostClient->fetchChanges(m_repo->syncConfig().lastPulledRevision);
}

void SyncService::onMutationsPushed(const QStringList& acceptedIds,
                                    qint64 latestRevision,
                                    const QString& message)
{
    const QVector<OutboxMutation> currentPending = m_outbox->pendingMutations(50);
    if (!acceptedIds.isEmpty())
        m_outbox->markAcknowledged(acceptedIds);

    if (!message.isEmpty()) {
        for (const OutboxMutation& mutation : currentPending) {
            if (!acceptedIds.contains(mutation.mutationId))
                m_outbox->markFailed(mutation.mutationId, message);
        }
    }

    if (latestRevision > 0)
        m_repo->updateLastPulledRevision(latestRevision);

    m_statusText = message.isEmpty()
        ? QStringLiteral("Fetching remote changes...")
        : message;
    emit statusChanged();
    m_hostClient->fetchChanges(m_repo->syncConfig().lastPulledRevision);
}

void SyncService::onChangesReceived(const QJsonArray& changes,
                                    qint64 latestRevision,
                                    const QString& message)
{
    if (!changes.isEmpty())
        applyRemoteChanges(changes);

    if (latestRevision > 0)
        m_repo->updateLastPulledRevision(latestRevision);

    if (!changes.isEmpty())
        emit ordersChanged();

    finishCycle(message.isEmpty() ? QStringLiteral("Sync complete") : message);
}

void SyncService::applyRemoteChanges(const QJsonArray& changes)
{
    for (const QJsonValue& value : changes) {
        const QJsonObject change = value.toObject();
        const QString changeType = change.value(QStringLiteral("change_type")).toString();
        const QJsonObject payload = change.value(QStringLiteral("payload")).toObject();
        const qint64 serverRevision = change.value(QStringLiteral("server_revision")).toInteger(0);

        if (changeType == QStringLiteral("upsert_order")) {
            Order order;
            order.id = payload.value(QStringLiteral("id")).toString();
            order.orderNumber = payload.value(QStringLiteral("order_number")).toString();
            order.invoiceNumber = payload.value(QStringLiteral("invoice_number")).toString();
            order.orderDate = payload.value(QStringLiteral("order_date")).toString();
            order.buyerName = payload.value(QStringLiteral("buyer_name")).toString();
            order.orderStatus = payload.value(QStringLiteral("order_status")).toString();
            order.usingCoupon = payload.value(QStringLiteral("using_coupon")).toBool(false);
            order.createdByClientId = payload.value(QStringLiteral("created_by_client_id")).toString();
            order.updatedByClientId = payload.value(QStringLiteral("updated_by_client_id")).toString();
            order.createdAt = payload.value(QStringLiteral("created_at")).toString();
            order.updatedAt = payload.value(QStringLiteral("updated_at")).toString();
            order.deletedAt = payload.value(QStringLiteral("deleted_at")).toString();
            order.serverRevision = serverRevision;
            m_repo->upsertOrder(order);
        } else if (changeType == QStringLiteral("delete_order")) {
            m_repo->applyRemoteDelete(
                payload.value(QStringLiteral("order_number")).toString(),
                payload.value(QStringLiteral("deleted_at")).toString(),
                payload.value(QStringLiteral("updated_by_client_id")).toString(),
                serverRevision);
        }
    }
}

void SyncService::finishCycle(const QString& message)
{
    m_cycleInFlight = false;
    m_statusText = message;
    emit statusChanged();
}
