// ─────────────────────────────────────────────────────────────
// Database.cpp
// Implementation of the local SQLite database manager.
//
// On open():
//   1. Determines the storage directory via QStandardPaths
//   2. Creates the directory if it doesn't exist
//   3. Opens the SQLite database (creates file if missing)
//   4. Enables WAL (Write-Ahead Logging) for better read perf
//   5. Enables foreign key enforcement
//   6. Runs any pending schema migrations
//
// Migration system:
//   - A `schema_version` table tracks the current version
//   - Each migration block checks `if (currentVersion < N)`
//   - After applying, it bumps the version number
//   - This makes it safe to run open() multiple times
// ─────────────────────────────────────────────────────────────
#include "Database.h"

#include <QCoreApplication>
#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDebug>

bool Database::open()
{
    // QStandardPaths::AppDataLocation gives us an OS-appropriate directory.
    // On Windows this is typically: C:/Users/<user>/AppData/Local/<AppName>/
    // We need setOrganizationName + setApplicationName in main.cpp for this
    // to resolve to a meaningful path (see main.cpp).
    const QString dataDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    // Ensure the directory exists (mkpath creates all intermediate dirs)
    QDir().mkpath(dataDir);

    m_path = dataDir + QStringLiteral("/packingelf.db");
    qDebug() << "[Database] Opening SQLite at:" << m_path;

    // "QSQLITE" is Qt's built-in SQLite driver — no external deps needed.
    // addDatabase() registers this connection as the default connection.
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));
    m_db.setDatabaseName(m_path);

    if (!m_db.open()) {
        qWarning() << "[Database] Failed to open:" << m_db.lastError().text();
        return false;
    }

    // WAL mode allows multiple readers while one writer is active.
    // This is important for future multi-threaded access (e.g., sync engine).
    QSqlQuery walQuery(m_db);
    walQuery.exec(QStringLiteral("PRAGMA journal_mode=WAL"));

    // SQLite foreign keys are OFF by default — we must enable them per-connection.
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

    // ─── Step 1: Create the schema_version tracking table ───
    // This table holds a single row with the current schema version number.
    if (!q.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS schema_version ("
            "  version INTEGER NOT NULL DEFAULT 0"
            ")"))) {
        qWarning() << "[Database] schema_version create failed:" << q.lastError().text();
        return false;
    }

    // Read the current version (or insert the initial row if table is empty)
    q.exec(QStringLiteral("SELECT version FROM schema_version"));
    int currentVersion = 0;
    if (q.next()) {
        currentVersion = q.value(0).toInt();
    } else {
        // First time running — insert version 0
        q.exec(QStringLiteral("INSERT INTO schema_version (version) VALUES (0)"));
    }

    qDebug() << "[Database] Current schema version:" << currentVersion;

    // ─── Migration v0 → v1: Create the orders table ───
    // This is the core table for storing order data.
    // Each order has:
    //   - id:             UUID primary key (generated in C++)
    //   - order_number:   e.g. "PG02491384" (prefix + 5-digit suffix)
    //   - invoice_number: e.g. "AB1234567"
    //   - order_date:     date from web scraper (may be empty initially)
    //   - buyer_name:     name from web scraper (may be empty initially)
    //   - status:         printed | shipped | returned | closed
    //   - using_coupon:   0 or 1 (from web scraper)
    //   - created_by:     username who created this record
    //   - created_at:     ISO 8601 timestamp of creation
    //   - updated_at:     ISO 8601 timestamp of last update
    if (currentVersion < 1) {
        qDebug() << "[Database] Migrating to v1: creating orders table";

        const bool ok = q.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS orders ("
            "  id             TEXT PRIMARY KEY,"
            "  order_number   TEXT NOT NULL,"
            "  invoice_number TEXT NOT NULL,"
            "  order_date     TEXT,"
            "  buyer_name     TEXT,"
            "  status         TEXT NOT NULL DEFAULT 'printed',"
            "  using_coupon   INTEGER NOT NULL DEFAULT 0,"
            "  created_by     TEXT NOT NULL DEFAULT '',"
            "  created_at     TEXT NOT NULL,"
            "  updated_at     TEXT NOT NULL"
            ")"));

        if (!ok) {
            qWarning() << "[Database] orders table creation failed:" << q.lastError().text();
            return false;
        }

        // Index on order_number for fast lookups when searching by order number
        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number)"));

        // Index on created_at for fast date-range queries (history page filtering)
        q.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)"));

        // Bump the schema version so this migration won't run again
        q.exec(QStringLiteral("UPDATE schema_version SET version = 1"));
        currentVersion = 1;
    }

    // Future migrations go here:
    // if (currentVersion < 2) { ... bump to 2 }

    qDebug() << "[Database] Migration complete. Version:" << currentVersion;
    return true;
}
