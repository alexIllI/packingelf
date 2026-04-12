package com.meridian.packingelf.host;

import com.fasterxml.jackson.databind.ObjectMapper;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;

import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

final class HostRuntime implements AutoCloseable {
    static final int PORT = 48080;

    private final HostDatabase database;
    private final Connection connection;
    private final HostRepository repository;
    private final HostApiServer apiServer;
    private final MdnsAdvertiser mdnsAdvertiser;
    private final HostExportService exportService;
    private final ObservableList<HostOrder> orders = FXCollections.observableArrayList();
    private final ObservableList<HostClientInfo> clients = FXCollections.observableArrayList();

    HostRuntime() throws IOException, SQLException {
        ObjectMapper mapper = new ObjectMapper();
        this.database = new HostDatabase();
        this.connection = database.open();
        this.repository = new HostRepository(connection, mapper);
        this.apiServer = new HostApiServer(repository, mapper, PORT);
        this.mdnsAdvertiser = new MdnsAdvertiser("packingelf-host", PORT);
        this.exportService = new HostExportService(Path.of(dataDirectoryPath(), "exports"));
    }

    void start() throws IOException, SQLException {
        apiServer.start();
        mdnsAdvertiser.start();
        refreshData("");
    }

    ObservableList<HostOrder> orders() {
        return orders;
    }

    ObservableList<HostClientInfo> clients() {
        return clients;
    }

    void refreshOrders(String searchTerm) throws SQLException {
        List<HostOrder> latestOrders = repository.loadOrders(searchTerm);
        orders.setAll(latestOrders);
    }

    void refreshClients() throws SQLException {
        clients.setAll(repository.loadClients());
    }

    void refreshData(String searchTerm) throws SQLException {
        refreshOrders(searchTerm);
        refreshClients();
    }

    String pairingToken() throws SQLException {
        return repository.pairingToken();
    }

    void setPairingToken(String pairingToken) throws SQLException {
        repository.setPairingToken(pairingToken);
    }

    String generatedPairingToken() {
        return java.util.UUID.randomUUID().toString().replace("-", "");
    }

    String baseUrl() {
        try {
            return "http://" + InetAddress.getLocalHost().getHostName() + ":" + PORT;
        } catch (UnknownHostException ex) {
            return "http://127.0.0.1:" + PORT;
        }
    }

    String hostName() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException ex) {
            return "127.0.0.1";
        }
    }

    String advertisedName() {
        return mdnsAdvertiser.serviceName();
    }

    String dbPath() {
        return database.dbPath().toString();
    }

    String dataDirectoryPath() {
        return database.dbPath().getParent().toString();
    }

    String exportDirectoryPath() {
        return exportService.exportDirectory().toString();
    }

    int activeOrderCount() throws SQLException {
        return repository.activeOrderCount();
    }

    int pairedClientCount() throws SQLException {
        return repository.pairedClientCount();
    }

    long latestRevision() throws SQLException {
        return repository.latestRevision();
    }

    Path exportDay(LocalDate date) throws Exception {
        return exportService.exportDay(date, repository.loadOrdersForDate(date));
    }

    List<Path> exportRange(LocalDate fromDate, LocalDate toDate) throws Exception {
        return exportService.exportRange(fromDate, toDate, repository);
    }

    Path exportMonth(YearMonth month) throws Exception {
        return exportService.exportMonth(month, repository.loadOrdersForDateRange(
            month.atDay(1),
            month.atEndOfMonth()
        ));
    }

    @Override
    public void close() throws Exception {
        apiServer.stop();
        mdnsAdvertiser.close();
        connection.close();
    }
}
