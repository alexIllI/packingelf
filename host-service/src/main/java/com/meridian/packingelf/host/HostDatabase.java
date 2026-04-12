package com.meridian.packingelf.host;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

final class HostDatabase {
    private Path dbPath;

    HostDatabase() {
        this.dbPath = null;
    }

    Connection open() throws SQLException, IOException {
        SQLException lastSqlException = null;
        IOException lastIoException = null;

        for (Path candidate : candidatePaths()) {
            try {
                Files.createDirectories(candidate.getParent());
                Connection connection = DriverManager.getConnection("jdbc:sqlite:" + candidate);
                dbPath = candidate;
                try (Statement statement = connection.createStatement()) {
                    statement.execute("PRAGMA journal_mode=WAL");
                    statement.execute("PRAGMA foreign_keys=ON");
                }
                migrate(connection);
                return connection;
            } catch (SQLException ex) {
                lastSqlException = ex;
            } catch (IOException ex) {
                lastIoException = ex;
            }
        }

        if (lastIoException != null) {
            throw lastIoException;
        }
        if (lastSqlException != null) {
            throw lastSqlException;
        }

        throw new IOException("Unable to determine a writable database path");
    }

    private List<Path> candidatePaths() {
        List<Path> candidates = new ArrayList<>();

        String localAppData = System.getenv("LOCALAPPDATA");
        if (localAppData != null && !localAppData.isBlank()) {
            candidates.add(Path.of(localAppData, "Meridian", "PackingElfHost", "packingelf-host.db"));
        }

        String userHome = System.getProperty("user.home");
        if (userHome != null && !userHome.isBlank()) {
            candidates.add(Path.of(userHome, "AppData", "Local", "Meridian", "PackingElfHost", "packingelf-host.db"));
            candidates.add(Path.of(userHome, ".packingelf-host", "packingelf-host.db"));
        }

        candidates.add(Path.of("host-data", "packingelf-host.db"));
        return candidates;
    }

    Path dbPath() {
        return dbPath;
    }

    private void migrate(Connection connection) throws SQLException {
        try (Statement statement = connection.createStatement()) {
            statement.execute("""
                CREATE TABLE IF NOT EXISTS host_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )
                """);
            statement.execute("""
                CREATE TABLE IF NOT EXISTS orders (
                    id TEXT PRIMARY KEY,
                    order_number TEXT NOT NULL UNIQUE,
                    invoice_number TEXT NOT NULL,
                    order_date TEXT NOT NULL,
                    buyer_name TEXT NOT NULL,
                    total_amount INTEGER NOT NULL DEFAULT 0,
                    order_status TEXT NOT NULL,
                    using_coupon INTEGER NOT NULL DEFAULT 0,
                    created_by_client_id TEXT NOT NULL,
                    updated_by_client_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    deleted_at TEXT,
                    server_revision INTEGER NOT NULL DEFAULT 0
                )
                """);
            statement.execute("""
                CREATE TABLE IF NOT EXISTS paired_clients (
                    client_id TEXT PRIMARY KEY,
                    client_name TEXT NOT NULL,
                    token_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    last_known_host_revision INTEGER NOT NULL DEFAULT 0
                )
                """);
            statement.execute("""
                CREATE TABLE IF NOT EXISTS applied_mutations (
                    mutation_id TEXT PRIMARY KEY,
                    client_id TEXT NOT NULL,
                    entity_type TEXT NOT NULL,
                    entity_key TEXT NOT NULL,
                    operation TEXT NOT NULL,
                    received_at TEXT NOT NULL,
                    applied_revision INTEGER,
                    status TEXT NOT NULL,
                    error_message TEXT
                )
                """);
            statement.execute("""
                CREATE TABLE IF NOT EXISTS change_log (
                    server_revision INTEGER PRIMARY KEY AUTOINCREMENT,
                    entity_type TEXT NOT NULL,
                    entity_key TEXT NOT NULL,
                    change_type TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    changed_at TEXT NOT NULL
                )
                """);
        }

        addColumnIfMissing(connection, "orders", "total_amount", "INTEGER NOT NULL DEFAULT 0");
    }

    private void addColumnIfMissing(Connection connection,
                                    String tableName,
                                    String columnName,
                                    String definition) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();
        try (ResultSet columns = metaData.getColumns(null, null, tableName, columnName)) {
            if (columns.next()) {
                return;
            }
        }

        try (Statement statement = connection.createStatement()) {
            statement.execute("ALTER TABLE " + tableName + " ADD COLUMN " + columnName + " " + definition);
        }
    }
}
