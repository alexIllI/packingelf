#pragma once

#include <QObject>
#include <memory>

class Database;
class OrdersRepository;

class AppSupportService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(QString logDirectoryPath READ logDirectoryPath NOTIFY logPathsChanged)
    Q_PROPERTY(QString currentLogFilePath READ currentLogFilePath NOTIFY logPathsChanged)
    Q_PROPERTY(bool localDbHealthy READ localDbHealthy NOTIFY localDbStatusChanged)
    Q_PROPERTY(QString localDbStatusText READ localDbStatusText NOTIFY localDbStatusChanged)

public:
    AppSupportService(Database* database,
                      std::shared_ptr<OrdersRepository> repo,
                      QObject* parent = nullptr);

    QString databasePath() const;
    QString logDirectoryPath() const;
    QString currentLogFilePath() const;
    bool localDbHealthy() const;
    QString localDbStatusText() const;

    Q_INVOKABLE void testLocalDatabase();
    Q_INVOKABLE bool openLogFolder();
    Q_INVOKABLE bool openCurrentLogFile();
    Q_INVOKABLE bool openDatabaseFolder();

signals:
    void localDbStatusChanged();
    void logPathsChanged();

private:
    bool openPath(const QString& path, bool selectParentFolder = false);

    Database* m_database = nullptr;
    std::shared_ptr<OrdersRepository> m_repo;
    bool m_localDbHealthy = false;
    QString m_localDbStatusText;
};
