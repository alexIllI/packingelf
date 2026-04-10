#pragma once

#include <QObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QString>

#include "OutboxStore.h"

class HostClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit HostClient(QObject* parent = nullptr);

    QString baseUrl() const { return m_baseUrl; }
    bool online() const { return m_online; }
    QString lastError() const { return m_lastError; }

    void setBaseUrl(const QString& baseUrl);
    void setPairingToken(const QString& pairingToken);
    void setClientIdentity(const QString& clientId, const QString& clientName);

    Q_INVOKABLE void testConnection();
    void pair();
    void pushMutations(const QVector<OutboxMutation>& mutations);
    void fetchChanges(qint64 sinceRevision, int limit = 200);

signals:
    void baseUrlChanged();
    void onlineChanged();
    void lastErrorChanged();

    void healthCheckFinished(bool ok, const QString& message);
    void pairingFinished(bool ok, qint64 initialRevision, const QString& message);
    void mutationsPushed(const QStringList& acceptedIds, qint64 latestRevision, const QString& message);
    void changesReceived(const QJsonArray& changes, qint64 latestRevision, const QString& message);

private:
    void setOnline(bool online, const QString& message = QString());
    void setLastError(const QString& error);

    QNetworkRequest makeRequest(const QString& path) const;

    QNetworkAccessManager m_network;
    QString m_baseUrl;
    QString m_pairingToken;
    QString m_clientId;
    QString m_clientName;
    bool m_online = false;
    QString m_lastError;
};
