package com.meridian.packingelf.host;

import javafx.application.Application;
import javafx.beans.binding.Bindings;
import javafx.collections.transformation.FilteredList;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextField;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class HostApplication extends Application {
    private HostRuntime runtime;

    @Override
    public void start(Stage stage) throws Exception {
        runtime = new HostRuntime();
        runtime.start();

        Label title = new Label("PackingElf Host");
        title.setStyle("-fx-font-size: 20px; -fx-font-weight: bold;");

        Label apiLabel = new Label("API: " + runtime.baseUrl());
        Label tokenLabel = new Label("Pairing token: " + runtime.pairingToken());
        Label dbLabel = new Label("DB: " + runtime.dbPath());

        TextField searchField = new TextField();
        searchField.setPromptText("Search order number or buyer");

        TableView<HostOrder> table = new TableView<>();
        table.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY_FLEX_LAST_COLUMN);
        table.getColumns().add(column("Order #", HostOrder::orderNumber));
        table.getColumns().add(column("Invoice", HostOrder::invoiceNumber));
        table.getColumns().add(column("Buyer", HostOrder::buyerName));
        table.getColumns().add(column("Date", HostOrder::orderDate));
        table.getColumns().add(column("Status", HostOrder::orderStatus));
        table.getColumns().add(column("Client", HostOrder::updatedByClientId));

        FilteredList<HostOrder> filtered = new FilteredList<>(runtime.orders(), order -> true);
        searchField.textProperty().addListener((obs, oldValue, newValue) -> {
            String search = newValue == null ? "" : newValue.trim().toLowerCase();
            filtered.setPredicate(order ->
                search.isEmpty()
                    || order.orderNumber().toLowerCase().contains(search)
                    || order.buyerName().toLowerCase().contains(search));
        });
        table.setItems(filtered);

        Label countLabel = new Label();
        countLabel.textProperty().bind(Bindings.size(filtered).asString("Visible orders: %d"));

        GridPane details = new GridPane();
        details.setHgap(12);
        details.setVgap(8);
        details.add(new Label("API base URL"), 0, 0);
        details.add(apiLabel, 1, 0);
        details.add(new Label("Pairing token"), 0, 1);
        details.add(tokenLabel, 1, 1);
        details.add(new Label("Database"), 0, 2);
        details.add(dbLabel, 1, 2);

        VBox top = new VBox(10, title, details, searchField, countLabel);
        top.setPadding(new Insets(16));

        BorderPane root = new BorderPane();
        root.setTop(top);
        root.setCenter(table);
        BorderPane.setMargin(table, new Insets(0, 16, 16, 16));

        Scene scene = new Scene(root, 1100, 720);
        stage.setTitle("PackingElf Host");
        stage.setScene(scene);
        stage.show();
    }

    @Override
    public void stop() throws Exception {
        if (runtime != null) {
            runtime.close();
        }
    }

    private TableColumn<HostOrder, String> column(String title,
                                                  java.util.function.Function<HostOrder, String> getter) {
        TableColumn<HostOrder, String> column = new TableColumn<>(title);
        column.setCellValueFactory(cell -> new javafx.beans.property.SimpleStringProperty(getter.apply(cell.getValue())));
        return column;
    }
}
