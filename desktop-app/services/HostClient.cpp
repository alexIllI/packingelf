#include "HostClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

namespace {
QString replyMessage(QNetworkReply* reply)
{
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString errorText = reply->errorString().trimmed();
    const QString bodyText = QString::fromUtf8(reply->readAll()).trimmed();

    if (statusCode > 0 && !bodyText.isEmpty())
        return QStringLiteral("HTTP %1 - %2").arg(statusCode).arg(bodyText);
    if (statusCode > 0 && !errorText.isEmpty())
        return QStringLiteral("HTTP %1 - %2").arg(statusCode).arg(errorText);
    if (!bodyText.isEmpty())
        return bodyText;
    if (!errorText.isEmpty())
        return errorText;
    return QStringLiteral("Unknown network error");
}
}

HostClient::HostClient(QObject* parent)
    : QObject(parent)
{
}

void HostClient::setBaseUrl(const QString& baseUrl)
{
    const QString normalized = baseUrl.trimmed().endsWith(QLatin1Char('/'))
        ? baseUrl.trimmed().chopped(1)
        : baseUrl.trimmed();
    if (m_baseUrl == normalized)
        return;

    m_baseUrl = normalized;
    emit baseUrlChanged();
}

void HostClient::setPairingToken(const QString& pairingToken)
{
    m_pairingToken = pairingToken.trimmed();
}

void HostClient::setClientIdentity(const QString& clientId, const QString& clientName)
{
    m_clientId = clientId;
    m_clientName = clientName;
}

void HostClient::setOnline(bool online, const QString& message)
{
    if (m_online != online) {
        m_online = online;
        emit onlineChanged();
    }
    if (!message.isEmpty())
        setLastError(message);
}

void HostClient::setLastError(const QString& error)
{
    if (m_lastError == error)
        return;

    m_lastError = error;
    emit lastErrorChanged();
}

QNetworkRequest HostClient::makeRequest(const QString& path) const
{
    const QUrl url(m_baseUrl + path);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("X-Pairing-Token", m_pairingToken.toUtf8());
    request.setRawHeader("X-Client-Id", m_clientId.toUtf8());
    return request;
}

void HostClient::testConnection()
{
    if (m_baseUrl.isEmpty()) {
        const QString message = QStringLiteral("Host URL is not configured");
        qWarning() << "[HostClient] Connection test skipped:" << message;
        setOnline(false, message);
        emit healthCheckFinished(false, message);
        return;
    }

    qInfo() << "[HostClient] Testing host connection:" << m_baseUrl;
    QNetworkReply* reply = m_network.get(makeRequest(QStringLiteral("/api/v1/health")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = replyMessage(reply);
            qWarning() << "[HostClient] Connection test failed:" << m_baseUrl << message;
            setOnline(false, message);
            emit healthCheckFinished(false, message);
            reply->deleteLater();
            return;
        }

        const QByteArray body = reply->readAll();
        const QJsonObject obj = QJsonDocument::fromJson(body).object();
        const QString message = obj.value(QStringLiteral("message")).toString();
        qInfo() << "[HostClient] Connection test succeeded:" << m_baseUrl
                << (message.isEmpty() ? QStringLiteral("Host reachable") : message);
        setOnline(true);
        emit healthCheckFinished(true, message.isEmpty() ? QStringLiteral("Host reachable") : message);
        reply->deleteLater();
    });
}

void HostClient::pair()
{
    if (m_baseUrl.isEmpty()) {
        emit pairingFinished(false, 0, QStringLiteral("Host URL is not configured"));
        return;
    }

    const QJsonObject payload{
        { QStringLiteral("client_id"), m_clientId },
        { QStringLiteral("client_name"), m_clientName },
    };

    QNetworkReply* reply = m_network.post(
        makeRequest(QStringLiteral("/api/v1/pair")),
        QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray body = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = replyMessage(reply);
            qWarning() << "[HostClient] Pairing failed:" << m_baseUrl << message;
            setOnline(false, message);
            emit pairingFinished(false, 0, message);
            reply->deleteLater();
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(body).object();
        const bool ok = obj.value(QStringLiteral("ok")).toBool(false);
        const QString message = obj.value(QStringLiteral("message")).toString();
        const qint64 initialRevision = obj.value(QStringLiteral("initial_revision")).toInteger(0);
        qInfo() << "[HostClient] Pairing result:" << ok << message << "revision" << initialRevision;
        setOnline(ok, message);
        emit pairingFinished(ok, initialRevision, message);
        reply->deleteLater();
    });
}

void HostClient::pushMutations(const QVector<OutboxMutation>& mutations)
{
    if (mutations.isEmpty()) {
        emit mutationsPushed({}, 0, QStringLiteral("No pending mutations"));
        return;
    }

    QJsonArray payloadMutations;
    for (const OutboxMutation& mutation : mutations) {
        const QJsonObject payloadObject = QJsonDocument::fromJson(mutation.payloadJson.toUtf8()).object();
        payloadMutations.append(QJsonObject{
            { QStringLiteral("mutation_id"), mutation.mutationId },
            { QStringLiteral("client_id"), mutation.clientId },
            { QStringLiteral("entity_type"), mutation.entityType },
            { QStringLiteral("entity_key"), mutation.entityKey },
            { QStringLiteral("operation"), mutation.operation },
            { QStringLiteral("payload"), payloadObject },
            { QStringLiteral("client_created_at"), mutation.createdAt },
        });
    }

    const QJsonObject payload{
        { QStringLiteral("client_id"), m_clientId },
        { QStringLiteral("mutations"), payloadMutations },
    };

    QNetworkReply* reply = m_network.post(
        makeRequest(QStringLiteral("/api/v1/mutations/batch")),
        QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray body = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = replyMessage(reply);
            qWarning() << "[HostClient] Push mutations failed:" << m_baseUrl << message;
            setOnline(false, message);
            emit mutationsPushed({}, 0, message);
            reply->deleteLater();
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(body).object();
        QStringList acceptedIds;
        for (const QJsonValue& value : obj.value(QStringLiteral("accepted_mutation_ids")).toArray())
            acceptedIds.append(value.toString());
        const qint64 latestRevision = obj.value(QStringLiteral("latest_revision")).toInteger(0);
        const QString message = obj.value(QStringLiteral("message")).toString();
        qInfo() << "[HostClient] Mutations pushed:" << acceptedIds.size()
                << "latest revision" << latestRevision << message;
        setOnline(true);
        emit mutationsPushed(acceptedIds, latestRevision, message);
        reply->deleteLater();
    });
}

void HostClient::fetchChanges(qint64 sinceRevision, int limit)
{
    QUrl url(m_baseUrl + QStringLiteral("/api/v1/changes"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("since_revision"), QString::number(sinceRevision));
    query.addQueryItem(QStringLiteral("limit"), QString::number(limit));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setRawHeader("X-Pairing-Token", m_pairingToken.toUtf8());
    request.setRawHeader("X-Client-Id", m_clientId.toUtf8());

    QNetworkReply* reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QByteArray body = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = replyMessage(reply);
            qWarning() << "[HostClient] Fetch changes failed:" << m_baseUrl << message;
            setOnline(false, message);
            emit changesReceived({}, 0, message);
            reply->deleteLater();
            return;
        }

        const QJsonObject obj = QJsonDocument::fromJson(body).object();
        const QJsonArray changes = obj.value(QStringLiteral("changes")).toArray();
        const qint64 latestRevision = obj.value(QStringLiteral("latest_revision")).toInteger(0);
        const QString message = obj.value(QStringLiteral("message")).toString();
        qInfo() << "[HostClient] Changes received:" << changes.size()
                << "latest revision" << latestRevision << message;
        setOnline(true);
        emit changesReceived(changes, latestRevision, message);
        reply->deleteLater();
    });
}
