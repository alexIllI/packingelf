package com.meridian.packingelf.host;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executors;

final class HostApiServer {
    private final HostRepository repository;
    private final ObjectMapper objectMapper;
    private final int port;
    private HttpServer server;

    HostApiServer(HostRepository repository, ObjectMapper objectMapper, int port) {
        this.repository = repository;
        this.objectMapper = objectMapper;
        this.port = port;
    }

    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/api/v1/health", withJson(this::handleHealth));
        server.createContext("/api/v1/pair", withJson(this::handlePair));
        server.createContext("/api/v1/mutations/batch", withJson(this::handleMutations));
        server.createContext("/api/v1/changes", withJson(this::handleChanges));
        server.setExecutor(Executors.newCachedThreadPool());
        server.start();
    }

    void stop() {
        if (server != null) {
            server.stop(0);
        }
    }

    private HttpHandler withJson(JsonHandler handler) {
        return exchange -> {
            try {
                handler.handle(exchange);
            } catch (HttpErrorException ex) {
                ObjectNode error = objectMapper.createObjectNode();
                error.put("ok", false);
                error.put("message", ex.getMessage());
                writeJson(exchange, ex.statusCode, error);
            } catch (SecurityException ex) {
                ObjectNode error = objectMapper.createObjectNode();
                error.put("ok", false);
                error.put("message", ex.getMessage());
                writeJson(exchange, 401, error);
            } catch (IllegalArgumentException ex) {
                ObjectNode error = objectMapper.createObjectNode();
                error.put("ok", false);
                error.put("message", ex.getMessage());
                writeJson(exchange, 400, error);
            } catch (Exception ex) {
                ObjectNode error = objectMapper.createObjectNode();
                error.put("ok", false);
                error.put("message", ex.getMessage());
                writeJson(exchange, 500, error);
            } finally {
                exchange.close();
            }
        };
    }

    private void handleHealth(HttpExchange exchange) throws IOException, SQLException {
        requireMethod(exchange, "GET");

        ObjectNode response = objectMapper.createObjectNode();
        response.put("ok", true);
        response.put("message", "PackingElf Host online");
        response.put("latest_revision", repository.latestRevision());
        response.put("active_order_count", repository.activeOrderCount());
        response.put("paired_client_count", repository.pairedClientCount());
        response.put("port", port);
        writeJson(exchange, 200, response);
    }

    private void handlePair(HttpExchange exchange) throws IOException, SQLException {
        requireMethod(exchange, "POST");

        JsonNode body = readBody(exchange);
        String token = exchange.getRequestHeaders().getFirst("X-Pairing-Token");
        repository.pairClient(body.path("client_id").asText(), body.path("client_name").asText(), token);

        ObjectNode response = objectMapper.createObjectNode();
        response.put("ok", true);
        response.put("message", "Client paired");
        response.put("initial_revision", repository.latestRevision());
        writeJson(exchange, 200, response);
    }

    private void handleMutations(HttpExchange exchange) throws IOException, SQLException {
        requireMethod(exchange, "POST");

        JsonNode body = readBody(exchange);
        String token = exchange.getRequestHeaders().getFirst("X-Pairing-Token");

        HostRepository.BatchResult result = repository.applyMutations(token, body.path("mutations"));
        ObjectNode response = objectMapper.createObjectNode();
        response.put("ok", true);
        response.put("message", "Mutations applied");
        response.put("latest_revision", result.latestRevision());
        ArrayNode accepted = response.putArray("accepted_mutation_ids");
        for (String mutationId : result.acceptedMutationIds()) {
            accepted.add(mutationId);
        }
        writeJson(exchange, 200, response);
    }

    private void handleChanges(HttpExchange exchange) throws IOException, SQLException {
        requireMethod(exchange, "GET");

        Map<String, String> query = parseQuery(exchange.getRequestURI());
        long sinceRevision = Long.parseLong(query.getOrDefault("since_revision", "0"));
        int limit = Integer.parseInt(query.getOrDefault("limit", "200"));
        String token = exchange.getRequestHeaders().getFirst("X-Pairing-Token");
        String clientId = exchange.getRequestHeaders().getFirst("X-Client-Id");

        ArrayNode changes = repository.changesSince(clientId, token, sinceRevision, limit);
        ObjectNode response = objectMapper.createObjectNode();
        response.put("ok", true);
        response.put("message", "Changes fetched");
        response.put("latest_revision", repository.latestRevision());
        response.set("changes", changes);
        writeJson(exchange, 200, response);
    }

    private JsonNode readBody(HttpExchange exchange) throws IOException {
        try (InputStream input = exchange.getRequestBody()) {
            if (input == null) {
                return objectMapper.createObjectNode();
            }
            return objectMapper.readTree(input);
        }
    }

    private void writeJson(HttpExchange exchange, int statusCode, JsonNode response) throws IOException {
        byte[] payload = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(response);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(statusCode, payload.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(payload);
        }
    }

    private Map<String, String> parseQuery(URI uri) {
        Map<String, String> values = new HashMap<>();
        String rawQuery = uri.getRawQuery();
        if (rawQuery == null || rawQuery.isBlank()) {
            return values;
        }

        for (String pair : rawQuery.split("&")) {
            String[] parts = pair.split("=", 2);
            String key = URLDecoder.decode(parts[0], StandardCharsets.UTF_8);
            String value = parts.length > 1
                ? URLDecoder.decode(parts[1], StandardCharsets.UTF_8)
                : "";
            values.put(key, value);
        }
        return values;
    }

    private void requireMethod(HttpExchange exchange, String expectedMethod) {
        if (!expectedMethod.equalsIgnoreCase(exchange.getRequestMethod())) {
            throw new HttpErrorException(405, "Method not allowed");
        }
    }

    @FunctionalInterface
    private interface JsonHandler {
        void handle(HttpExchange exchange) throws Exception;
    }

    private static final class HttpErrorException extends RuntimeException {
        private final int statusCode;

        private HttpErrorException(int statusCode, String message) {
            super(message);
            this.statusCode = statusCode;
        }
    }
}
