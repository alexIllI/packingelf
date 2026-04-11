#pragma once

#include <QObject>
#include <QTimer>
#include <memory>

#include "HostClient.h"
#include "OutboxStore.h"

class OrdersRepository;

class SyncService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hostOnline READ hostOnline NOTIFY statusChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)
    Q_PROPERTY(int pendingOutboxCount READ pendingOutboxCount NOTIFY statusChanged)
    Q_PROPERTY(QString hostBaseUrl READ hostBaseUrl NOTIFY statusChanged)

public:
    SyncService(std::shared_ptr<OrdersRepository> repo,
                std::unique_ptr<OutboxStore> outbox,
                std::unique_ptr<HostClient> hostClient,
                QObject* parent = nullptr);

    bool hostOnline() const;
    QString statusText() const { return m_statusText; }
    int pendingOutboxCount() const;
    QString hostBaseUrl() const;
    OutboxStore* outbox() const { return m_outbox.get(); }

    Q_INVOKABLE void testConnection();
    Q_INVOKABLE void triggerSync();

signals:
    void statusChanged();
    void ordersChanged();
    void connectionTestFinished(bool ok, const QString& message);
    void syncCycleFinished(bool ok, const QString& message);

private:
    void onPairingFinished(bool ok, qint64 initialRevision, const QString& message);
    void onMutationsPushed(const QStringList& acceptedIds,
                           qint64 latestRevision,
                           const QString& message);
    void onChangesReceived(const QJsonArray& changes,
                           qint64 latestRevision,
                           const QString& message);
    void applyRemoteChanges(const QJsonArray& changes);
    void finishCycle(const QString& message);

    std::shared_ptr<OrdersRepository> m_repo;
    std::unique_ptr<OutboxStore> m_outbox;
    std::unique_ptr<HostClient> m_hostClient;
    QTimer m_timer;
    QString m_statusText;
    bool m_cycleInFlight = false;
};
