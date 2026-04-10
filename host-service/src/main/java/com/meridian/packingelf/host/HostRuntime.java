package com.meridian.packingelf.host;

import com.fasterxml.jackson.databind.ObjectMapper;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;

import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;

final class HostRuntime implements AutoCloseable {
    static final int PORT = 48080;

    private final HostDatabase database;
    private final Connection connection;
    private final HostRepository repository;
    private final HostApiServer apiServer;
    private final MdnsAdvertiser mdnsAdvertiser;
    private final ObservableList<HostOrder> orders = FXCollections.observableArrayList();

    HostRuntime() throws IOException, SQLException {
        ObjectMapper mapper = new ObjectMapper();
        this.database = new HostDatabase();
        this.connection = database.open();
        this.repository = new HostRepository(connection, mapper);
        this.apiServer = new HostApiServer(repository, mapper, PORT);
        this.mdnsAdvertiser = new MdnsAdvertiser("packingelf-host", PORT);
    }

    void start() throws IOException, SQLException {
        apiServer.start();
        mdnsAdvertiser.start();
        refreshOrders("");
    }

    ObservableList<HostOrder> orders() {
        return orders;
    }

    void refreshOrders(String searchTerm) throws SQLException {
        List<HostOrder> latestOrders = repository.loadOrders(searchTerm);
        orders.setAll(latestOrders);
    }

    String pairingToken() throws SQLException {
        return repository.pairingToken();
    }

    String baseUrl() {
        try {
            return "http://" + InetAddress.getLocalHost().getHostName() + ":" + PORT;
        } catch (UnknownHostException ex) {
            return "http://127.0.0.1:" + PORT;
        }
    }

    String dbPath() {
        return database.dbPath().toString();
    }

    @Override
    public void close() throws Exception {
        apiServer.stop();
        mdnsAdvertiser.close();
        connection.close();
    }
}
