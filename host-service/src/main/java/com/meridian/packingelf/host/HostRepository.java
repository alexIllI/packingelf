package com.meridian.packingelf.host;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

final class HostRepository {
    private static final String DEFAULT_TOKEN = "dev-token";

    private final Connection connection;
    private final ObjectMapper objectMapper;

    HostRepository(Connection connection, ObjectMapper objectMapper) throws SQLException {
        this.connection = connection;
        this.objectMapper = objectMapper;
        ensurePairingToken();
    }

    synchronized String pairingToken() throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
            "SELECT value FROM host_settings WHERE key = 'pairing_token'")) {
            ResultSet rs = statement.executeQuery();
            return rs.next() ? rs.getString(1) : DEFAULT_TOKEN;
        }
    }

    synchronized void setPairingToken(String pairingToken) throws SQLException {
        String normalized = Objects.requireNonNullElse(pairingToken, DEFAULT_TOKEN).trim();
        upsertSetting("pairing_token", normalized.isBlank() ? DEFAULT_TOKEN : normalized);
    }

    synchronized long latestRevision() throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
            "SELECT COALESCE(MAX(server_revision), 0) FROM change_log")) {
            ResultSet rs = statement.executeQuery();
            return rs.next() ? rs.getLong(1) : 0L;
        }
    }

    synchronized void pairClient(String clientId, String clientName, String pairingToken) throws SQLException {
        validateToken(pairingToken);
        if (clientId == null || clientId.isBlank()) {
            throw new IllegalArgumentException("Client id is required");
        }

        String now = Instant.now().toString();
        try (PreparedStatement statement = connection.prepareStatement("""
            INSERT INTO paired_clients (
                client_id, client_name, token_hash, created_at, last_seen_at, last_known_host_revision
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(client_id) DO UPDATE SET
                client_name = excluded.client_name,
                token_hash = excluded.token_hash,
                last_seen_at = excluded.last_seen_at,
                last_known_host_revision = excluded.last_known_host_revision
            """)) {
            statement.setString(1, clientId);
            statement.setString(2, clientName);
            statement.setString(3, hashToken(pairingToken));
            statement.setString(4, now);
            statement.setString(5, now);
            statement.setLong(6, latestRevision());
            statement.executeUpdate();
        }
    }

    synchronized BatchResult applyMutations(String pairingToken, JsonNode mutations) throws SQLException {
        validateToken(pairingToken);
        if (!mutations.isArray()) {
            throw new IllegalArgumentException("Mutations payload must be an array");
        }

        List<String> acceptedIds = new ArrayList<>();
        long latestRevision = latestRevision();
        String activeClientId = "";

        for (JsonNode mutation : mutations) {
            String mutationId = mutation.path("mutation_id").asText();
            String clientId = mutation.path("client_id").asText();
            String entityType = mutation.path("entity_type").asText();
            String entityKey = mutation.path("entity_key").asText();
            String operation = mutation.path("operation").asText();
            JsonNode payload = mutation.path("payload");

            if (mutationId.isBlank()) {
                throw new IllegalArgumentException("mutation_id is required");
            }
            if (clientId.isBlank()) {
                throw new IllegalArgumentException("client_id is required");
            }
            if (entityKey.isBlank()) {
                throw new IllegalArgumentException("entity_key is required");
            }
            if (entityType.isBlank()) {
                throw new IllegalArgumentException("entity_type is required");
            }
            activeClientId = clientId;

            if (isMutationApplied(mutationId)) {
                acceptedIds.add(mutationId);
                continue;
            }

            long revision = switch (operation) {
                case "upsert_order" -> applyUpsert(clientId, entityKey, payload);
                case "delete_order" -> applyDelete(clientId, entityKey, payload);
                default -> throw new SQLException("Unsupported operation: " + operation);
            };

            try (PreparedStatement statement = connection.prepareStatement("""
                INSERT INTO applied_mutations (
                    mutation_id, client_id, entity_type, entity_key, operation,
                    received_at, applied_revision, status, error_message
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'applied', '')
                """)) {
                statement.setString(1, mutationId);
                statement.setString(2, clientId);
                statement.setString(3, entityType);
                statement.setString(4, entityKey);
                statement.setString(5, operation);
                statement.setString(6, Instant.now().toString());
                statement.setLong(7, revision);
                statement.executeUpdate();
            }

            acceptedIds.add(mutationId);
            latestRevision = Math.max(latestRevision, revision);
        }

        if (!activeClientId.isBlank()) {
            touchClient(activeClientId, latestRevision);
        }

        return new BatchResult(acceptedIds, latestRevision);
    }

    synchronized ArrayNode changesSince(String clientId, String pairingToken, long sinceRevision, int limit) throws SQLException {
        validateToken(pairingToken);
        ArrayNode changes = objectMapper.createArrayNode();
        int safeLimit = Math.max(1, Math.min(limit, 500));
        try (PreparedStatement statement = connection.prepareStatement("""
            SELECT server_revision, entity_type, entity_key, change_type, payload_json, changed_at
            FROM change_log
            WHERE server_revision > ?
            ORDER BY server_revision ASC
            LIMIT ?
            """)) {
            statement.setLong(1, sinceRevision);
            statement.setInt(2, safeLimit);
            ResultSet rs = statement.executeQuery();
            while (rs.next()) {
                ObjectNode node = changes.addObject();
                node.put("server_revision", rs.getLong("server_revision"));
                node.put("entity_type", rs.getString("entity_type"));
                node.put("entity_key", rs.getString("entity_key"));
                node.put("change_type", rs.getString("change_type"));
                try {
                    node.set("payload", objectMapper.readTree(rs.getString("payload_json")));
                } catch (Exception ex) {
                    node.putObject("payload").put("error", ex.getMessage());
                }
                node.put("changed_at", rs.getString("changed_at"));
            }
        }

        if (clientId != null && !clientId.isBlank()) {
            touchClient(clientId, latestRevision());
        }
        return changes;
    }

    synchronized List<HostOrder> loadOrders(String searchTerm) throws SQLException {
        List<HostOrder> orders = new ArrayList<>();
        String sql = """
            SELECT *
            FROM orders
            WHERE (deleted_at IS NULL OR deleted_at = '')
              AND (? = '' OR order_number LIKE ? OR buyer_name LIKE ? OR invoice_number LIKE ?)
            ORDER BY updated_at DESC
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            String filter = searchTerm == null ? "" : searchTerm.trim();
            String like = "%" + filter + "%";
            statement.setString(1, filter);
            statement.setString(2, like);
            statement.setString(3, like);
            statement.setString(4, like);
            ResultSet rs = statement.executeQuery();
            while (rs.next()) {
                orders.add(new HostOrder(
                    rs.getString("id"),
                    rs.getString("order_number"),
                    rs.getString("invoice_number"),
                    rs.getString("buyer_name"),
                    rs.getString("order_date"),
                    rs.getLong("total_amount"),
                    rs.getString("order_status"),
                    rs.getInt("using_coupon") != 0,
                    rs.getString("created_by_client_id"),
                    rs.getString("updated_by_client_id"),
                    rs.getString("created_at"),
                    rs.getString("updated_at"),
                    rs.getString("deleted_at"),
                    rs.getLong("server_revision")
                ));
            }
        }
        return orders;
    }

    synchronized List<HostOrder> loadOrdersForDate(LocalDate date) throws SQLException {
        return loadOrdersForDateRange(date, date);
    }

    synchronized List<HostOrder> loadOrdersForDateRange(LocalDate fromDate, LocalDate toDate) throws SQLException {
        List<HostOrder> orders = new ArrayList<>();
        String sql = """
            SELECT *
            FROM orders
            WHERE (deleted_at IS NULL OR deleted_at = '')
              AND substr(created_at, 1, 10) >= ?
              AND substr(created_at, 1, 10) <= ?
            ORDER BY created_at ASC, order_number ASC
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, fromDate.toString());
            statement.setString(2, toDate.toString());
            ResultSet rs = statement.executeQuery();
            while (rs.next()) {
                orders.add(new HostOrder(
                    rs.getString("id"),
                    rs.getString("order_number"),
                    rs.getString("invoice_number"),
                    rs.getString("buyer_name"),
                    rs.getString("order_date"),
                    rs.getLong("total_amount"),
                    rs.getString("order_status"),
                    rs.getInt("using_coupon") != 0,
                    rs.getString("created_by_client_id"),
                    rs.getString("updated_by_client_id"),
                    rs.getString("created_at"),
                    rs.getString("updated_at"),
                    rs.getString("deleted_at"),
                    rs.getLong("server_revision")
                ));
            }
        }
        return orders;
    }

    synchronized List<HostClientInfo> loadClients() throws SQLException {
        List<HostClientInfo> clients = new ArrayList<>();
        try (PreparedStatement statement = connection.prepareStatement("""
            SELECT client_id, client_name, created_at, last_seen_at, last_known_host_revision
            FROM paired_clients
            ORDER BY last_seen_at DESC, client_name ASC
            """)) {
            ResultSet rs = statement.executeQuery();
            while (rs.next()) {
                clients.add(new HostClientInfo(
                    rs.getString("client_id"),
                    rs.getString("client_name"),
                    rs.getString("created_at"),
                    rs.getString("last_seen_at"),
                    rs.getLong("last_known_host_revision")
                ));
            }
        }
        return clients;
    }

    synchronized int activeOrderCount() throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
            SELECT COUNT(*)
            FROM orders
            WHERE deleted_at IS NULL OR deleted_at = ''
            """)) {
            ResultSet rs = statement.executeQuery();
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    synchronized int pairedClientCount() throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
            "SELECT COUNT(*) FROM paired_clients")) {
            ResultSet rs = statement.executeQuery();
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    private void ensurePairingToken() throws SQLException {
        if (pairingToken().isBlank()) {
            setPairingToken(DEFAULT_TOKEN);
        }
    }

    private void validateToken(String pairingToken) throws SQLException {
        String expected = pairingToken();
        String provided = pairingToken == null ? "" : pairingToken.trim();
        if (expected.isBlank() || !expected.equals(provided)) {
            throw new SecurityException("Invalid pairing token");
        }
    }

    private void touchClient(String clientId, long lastKnownHostRevision) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
            UPDATE paired_clients
            SET last_seen_at = ?, last_known_host_revision = ?
            WHERE client_id = ?
            """)) {
            statement.setString(1, Instant.now().toString());
            statement.setLong(2, lastKnownHostRevision);
            statement.setString(3, clientId);
            statement.executeUpdate();
        }
    }

    private boolean isMutationApplied(String mutationId) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
            "SELECT 1 FROM applied_mutations WHERE mutation_id = ?")) {
            statement.setString(1, mutationId);
            ResultSet rs = statement.executeQuery();
            return rs.next();
        }
    }

    private long applyUpsert(String clientId, String entityKey, JsonNode payload) throws SQLException {
        String id = text(payload, "id", UUID.randomUUID().toString());
        String orderNumber = text(payload, "order_number", entityKey);
        String invoiceNumber = text(payload, "invoice_number", "");
        String orderDate = text(payload, "order_date", "");
        String buyerName = text(payload, "buyer_name", "");
        long totalAmount = payload.path("total_amount").asLong(0);
        String orderStatus = text(payload, "order_status", "");
        boolean usingCoupon = payload.path("using_coupon").asBoolean(false);
        String createdBy = text(payload, "created_by_client_id", clientId);
        String updatedBy = text(payload, "updated_by_client_id", clientId);
        String createdAt = text(payload, "created_at", Instant.now().toString());
        String updatedAt = text(payload, "updated_at", Instant.now().toString());
        String deletedAt = payload.path("deleted_at").isMissingNode() ? null : payload.path("deleted_at").asText(null);

        try (PreparedStatement statement = connection.prepareStatement("""
            INSERT INTO orders (
                id, order_number, invoice_number, order_date, buyer_name, total_amount, order_status,
                using_coupon, created_by_client_id, updated_by_client_id, created_at, updated_at, deleted_at, server_revision
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(order_number) DO UPDATE SET
                invoice_number = excluded.invoice_number,
                order_date = excluded.order_date,
                buyer_name = excluded.buyer_name,
                total_amount = excluded.total_amount,
                order_status = excluded.order_status,
                using_coupon = excluded.using_coupon,
                updated_by_client_id = excluded.updated_by_client_id,
                updated_at = excluded.updated_at,
                deleted_at = excluded.deleted_at
            """)) {
            statement.setString(1, id);
            statement.setString(2, orderNumber);
            statement.setString(3, invoiceNumber);
            statement.setString(4, orderDate);
            statement.setString(5, buyerName);
            statement.setLong(6, totalAmount);
            statement.setString(7, orderStatus);
            statement.setInt(8, usingCoupon ? 1 : 0);
            statement.setString(9, createdBy);
            statement.setString(10, updatedBy);
            statement.setString(11, createdAt);
            statement.setString(12, updatedAt);
            statement.setString(13, deletedAt);
            statement.executeUpdate();
        }

        long revision = insertChange("order", orderNumber, "upsert_order", payload);
        try (PreparedStatement statement = connection.prepareStatement(
            "UPDATE orders SET server_revision = ? WHERE order_number = ?")) {
            statement.setLong(1, revision);
            statement.setString(2, orderNumber);
            statement.executeUpdate();
        }
        return revision;
    }

    private long applyDelete(String clientId, String entityKey, JsonNode payload) throws SQLException {
        String deletedAt = text(payload, "deleted_at", Instant.now().toString());
        String updatedBy = text(payload, "updated_by_client_id", clientId);
        try (PreparedStatement statement = connection.prepareStatement("""
            UPDATE orders
            SET deleted_at = ?, updated_at = ?, updated_by_client_id = ?
            WHERE order_number = ?
            """)) {
            statement.setString(1, deletedAt);
            statement.setString(2, deletedAt);
            statement.setString(3, updatedBy);
            statement.setString(4, entityKey);
            statement.executeUpdate();
        }

        long revision = insertChange("order", entityKey, "delete_order", payload);
        try (PreparedStatement statement = connection.prepareStatement(
            "UPDATE orders SET server_revision = ? WHERE order_number = ?")) {
            statement.setLong(1, revision);
            statement.setString(2, entityKey);
            statement.executeUpdate();
        }
        return revision;
    }

    private long insertChange(String entityType, String entityKey, String changeType, JsonNode payload) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
            INSERT INTO change_log (entity_type, entity_key, change_type, payload_json, changed_at)
            VALUES (?, ?, ?, ?, ?)
            """, Statement.RETURN_GENERATED_KEYS)) {
            statement.setString(1, entityType);
            statement.setString(2, entityKey);
            statement.setString(3, changeType);
            statement.setString(4, payload.toString());
            statement.setString(5, Instant.now().toString());
            statement.executeUpdate();

            ResultSet keys = statement.getGeneratedKeys();
            if (!keys.next()) {
                throw new SQLException("Failed to allocate server revision");
            }
            return keys.getLong(1);
        }
    }

    private void upsertSetting(String key, String value) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
            INSERT INTO host_settings (key, value)
            VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """)) {
            statement.setString(1, key);
            statement.setString(2, value);
            statement.executeUpdate();
        }
    }

    private static String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return Base64.getEncoder().encodeToString(digest.digest(token.getBytes()));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException(ex);
        }
    }

    private static String text(JsonNode node, String fieldName, String fallback) {
        JsonNode field = node.path(fieldName);
        return field.isMissingNode() || field.isNull() || field.asText().isBlank()
            ? fallback
            : field.asText();
    }

    record BatchResult(List<String> acceptedMutationIds, long latestRevision) {
    }
}
