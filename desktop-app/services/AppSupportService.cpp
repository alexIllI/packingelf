#include "AppSupportService.h"

#include "AppLog.h"
#include "Database.h"
#include "OrdersRepository.h"

#include <QDebug>
#include <QDesktopServices>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QUrl>

AppSupportService::AppSupportService(Database* database,
                                     std::shared_ptr<OrdersRepository> repo,
                                     QObject* parent)
    : QObject(parent)
    , m_database(database)
    , m_repo(std::move(repo))
{
    testLocalDatabase();
}

QString AppSupportService::databasePath() const
{
    return m_database ? m_database->databasePath() : QString();
}

QString AppSupportService::logDirectoryPath() const
{
    return AppLog::logDirectoryPath();
}

QString AppSupportService::currentLogFilePath() const
{
    return AppLog::currentLogFilePath();
}

bool AppSupportService::localDbHealthy() const
{
    return m_localDbHealthy;
}

QString AppSupportService::localDbStatusText() const
{
    return m_localDbStatusText;
}

void AppSupportService::testLocalDatabase()
{
    bool ok = false;
    QString statusText;

    if (!m_database) {
        statusText = QStringLiteral("找不到本機資料庫物件");
    } else if (!m_database->db().isOpen()) {
        statusText = QStringLiteral("本機資料庫尚未開啟");
    } else {
        QSqlQuery query(m_database->db());
        ok = query.exec(QStringLiteral("SELECT 1")) && query.next();
        if (ok) {
            statusText = QStringLiteral("本機資料庫連線正常");
        } else {
            statusText = query.lastError().text();
            if (statusText.isEmpty())
                statusText = QStringLiteral("本機資料庫檢查失敗");
        }
    }

    m_localDbHealthy = ok;
    m_localDbStatusText = statusText;
    emit localDbStatusChanged();

    qInfo() << "[AppSupport] Local database test:" << statusText;
}

bool AppSupportService::openLogFolder()
{
    return openPath(logDirectoryPath(), false);
}

bool AppSupportService::openCurrentLogFile()
{
    return openPath(currentLogFilePath(), false);
}

bool AppSupportService::openDatabaseFolder()
{
    return openPath(databasePath(), true);
}

bool AppSupportService::openPath(const QString& path, bool selectParentFolder)
{
    if (path.trimmed().isEmpty())
        return false;

    QFileInfo info(path);
    const QString target = selectParentFolder && info.exists()
        ? info.absolutePath()
        : path;

    const bool ok = QDesktopServices::openUrl(QUrl::fromLocalFile(target));
    qInfo() << "[AppSupport] Open path" << target << "->" << ok;
    return ok;
}
