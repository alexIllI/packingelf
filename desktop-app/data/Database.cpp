#include "Database.h"

#include <QCoreApplication>
#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QDebug>

namespace {
bool execOrWarn(QSqlQuery& query, const QString& sql, const char* context)
{
    if (query.exec(sql))
        return true;

    qWarning() << "[Database]" << context << "failed:" << query.lastError().text();
    return false;
}

bool tableHasColumn(QSqlDatabase& db, const QString& tableName, const QString& columnName)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA table_info(%1)").arg(tableName)))
        return false;

    while (q.next()) {
        if (q.value(1).toString() == columnName)
            return true;
    }
    return false;
}
}

bool Database::open()
{
    const QString dataDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    QDir().mkpath(dataDir);

    m_path = dataDir + QStringLiteral("/packingelf.db");
    qDebug() << "[Database] Opening SQLite at:" << m_path;

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));
    m_db.setDatabaseName(m_path);

    if (!m_db.open()) {
        qWarning() << "[Database] Failed to open:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery walQuery(m_db);
    walQuery.exec(QStringLiteral("PRAGMA journal_mode=WAL"));

    QSqlQuery fkQuery(m_db);
    fkQuery.exec(QStringLiteral("PRAGMA foreign_keys=ON"));

    return migrate();
}

QSqlDatabase& Database::db()
{
    return m_db;
}

QString Database::databasePath() const
{
    return m_path;
}

bool Database::migrate()
{
    QSqlQuery q(m_db);

    if (!execOrWarn(q, QStringLiteral(
            "CREATE TABLE IF NOT EXISTS schema_version ("
            " version INTEGER NOT NULL DEFAULT 0"
            ")"), "schema_version create")) {
        return false;
    }

    q.exec(QStringLiteral("SELECT version FROM schema_version"));
    int currentVersion = 0;
    if (q.next()) {
        currentVersion = q.value(0).toInt();
    } else {
        q.exec(QStringLiteral("INSERT INTO schema_version (version) VALUES (0)"));
    }

    if (currentVersion < 1) {
        if (!execOrWarn(q, QStringLiteral(
                "CREATE TABLE IF NOT EXISTS orders ("
                " id TEXT PRIMARY KEY,"
                " order_number TEXT NOT NULL,"
                " invoice_number TEXT NOT NULL,"
                " order_date TEXT,"
                " buyer_name TEXT,"
                " status TEXT NOT NULL DEFAULT 'printed',"
                " using_coupon INTEGER NOT NULL DEFAULT 0,"
                " created_by TEXT NOT NULL DEFAULT '',"
                " created_at TEXT NOT NULL,"
                " updated_at TEXT NOT NULL"
                ")"), "legacy orders create")) {
            return false;
        }
        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number)"));
        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)"));
        q.exec(QStringLiteral("UPDATE schema_version SET version = 1"));
        currentVersion = 1;
    }

    if (currentVersion < 2) {
        if (tableHasColumn(m_db, QStringLiteral("orders"), QStringLiteral("status"))
            && !tableHasColumn(m_db, QStringLiteral("orders"), QStringLiteral("order_status"))) {
            if (!execOrWarn(q, QStringLiteral(
                    "ALTER TABLE orders RENAME TO orders_legacy_v1"), "orders rename")) {
                return false;
            }
        }

        if (!execOrWarn(q, QStringLiteral(
                "CREATE TABLE IF NOT EXISTS orders ("
                " id TEXT PRIMARY KEY,"
                " order_number TEXT NOT NULL UNIQUE,"
                " invoice_number TEXT NOT NULL,"
                " order_date TEXT NOT NULL,"
                " buyer_name TEXT NOT NULL,"
                " order_status TEXT NOT NULL,"
                " using_coupon INTEGER NOT NULL DEFAULT 0,"
                " created_by_client_id TEXT NOT NULL,"
                " updated_by_client_id TEXT NOT NULL,"
                " created_at TEXT NOT NULL,"
                " updated_at TEXT NOT NULL,"
                " deleted_at TEXT,"
                " server_revision INTEGER NOT NULL DEFAULT 0"
                ")"), "orders v2 create")) {
            return false;
        }

        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)"));
        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_server_revision ON orders(server_revision)"));

        if (tableHasColumn(m_db, QStringLiteral("orders_legacy_v1"), QStringLiteral("status"))) {
            if (!execOrWarn(q, QStringLiteral(
                    "INSERT OR IGNORE INTO orders ("
                    " id, order_number, invoice_number, order_date, buyer_name, order_status,"
                    " using_coupon, created_by_client_id, updated_by_client_id, created_at, updated_at, deleted_at, server_revision"
                    ") "
                    "SELECT "
                    " id, order_number, invoice_number, order_date, buyer_name, lower(status),"
                    " using_coupon, "
                    " CASE WHEN created_by IS NULL OR created_by = '' THEN 'legacy-client' ELSE created_by END,"
                    " CASE WHEN created_by IS NULL OR created_by = '' THEN 'legacy-client' ELSE created_by END,"
                    " created_at, updated_at, NULL, 0 "
                    "FROM orders_legacy_v1 "
                    "WHERE lower(status) IN ('success', 'canceled', 'returned') "
                    "AND COALESCE(order_date, '') <> '' "
                    "AND COALESCE(buyer_name, '') <> ''"), "orders legacy migrate")) {
                return false;
            }
        }

        if (!execOrWarn(q, QStringLiteral(
                "CREATE TABLE IF NOT EXISTS scrape_submissions ("
                " submission_id TEXT PRIMARY KEY,"
                " order_number TEXT NOT NULL,"
                " invoice_number TEXT NOT NULL,"
                " state TEXT NOT NULL,"
                " error_message TEXT,"
                " created_at TEXT NOT NULL,"
                " updated_at TEXT NOT NULL"
                ")"), "scrape_submissions create")) {
            return false;
        }

        if (!execOrWarn(q, QStringLiteral(
                "CREATE TABLE IF NOT EXISTS outbox ("
                " mutation_id TEXT PRIMARY KEY,"
                " client_id TEXT NOT NULL,"
                " entity_type TEXT NOT NULL,"
                " entity_key TEXT NOT NULL,"
                " operation TEXT NOT NULL,"
                " payload_json TEXT NOT NULL,"
                " status TEXT NOT NULL,"
                " attempt_count INTEGER NOT NULL DEFAULT 0,"
                " next_attempt_at TEXT NOT NULL,"
                " last_error TEXT,"
                " created_at TEXT NOT NULL,"
                " updated_at TEXT NOT NULL"
                ")"), "outbox create")) {
            return false;
        }

        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_outbox_status_next_attempt "
            "ON outbox(status, next_attempt_at)"));

        if (!execOrWarn(q, QStringLiteral(
                "CREATE TABLE IF NOT EXISTS sync_state ("
                " id INTEGER PRIMARY KEY CHECK (id = 1),"
                " client_id TEXT NOT NULL,"
                " client_name TEXT NOT NULL,"
                " host_base_url TEXT NOT NULL,"
                " pairing_token TEXT NOT NULL,"
                " last_pulled_revision INTEGER NOT NULL DEFAULT 0,"
                " last_discovery_at TEXT"
                ")"), "sync_state create")) {
            return false;
        }

        q.exec(QStringLiteral("UPDATE schema_version SET version = 2"));
        currentVersion = 2;
    }

    qDebug() << "[Database] Migration complete. Version:" << currentVersion;
    return true;
}
