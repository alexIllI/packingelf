// ─────────────────────────────────────────────────────────────
// Database.h
// Manages the local SQLite database connection and schema.
//
// This class is responsible for:
//   1. Opening/creating the SQLite database file on disk
//   2. Running schema migrations (creating/upgrading tables)
//   3. Providing the QSqlDatabase handle to repositories
//
// The database file is stored in the OS-specific app data
// directory (e.g. C:/Users/<user>/AppData/Local/Meridian/PackingElf/).
//
// Usage:
//   Database db;
//   if (db.open()) {
//       auto& sqlDb = db.db();  // use this for queries
//   }
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QSqlDatabase>
#include <QString>

class Database {
public:
    // Opens (or creates) the SQLite database at the default app data location.
    // This also runs any pending schema migrations.
    // Returns true if the database was opened and migrated successfully.
    bool open();

    // Returns the underlying QSqlDatabase connection handle.
    // Repositories use this to execute SQL queries.
    QSqlDatabase& db();

    // Returns the full file path to the .db file (useful for debugging).
    QString databasePath() const;

private:
    // Creates/upgrades tables to the latest schema version.
    // Uses a `schema_version` table to track which migrations
    // have already been applied (avoids re-running them).
    bool migrate();

    QSqlDatabase m_db;   // The Qt SQL database connection
    QString m_path;      // Full path to the .db file on disk
};
