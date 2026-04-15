package com.meridian.packingelf.host;

import javafx.animation.Animation;
import javafx.animation.KeyFrame;
import javafx.animation.Timeline;
import javafx.application.Application;
import javafx.beans.binding.Bindings;
import javafx.beans.property.ObjectProperty;
import javafx.beans.property.SimpleLongProperty;
import javafx.beans.property.SimpleObjectProperty;
import javafx.beans.property.SimpleStringProperty;
import javafx.collections.transformation.FilteredList;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.DatePicker;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TableColumn;
import javafx.scene.control.TableView;
import javafx.scene.control.TextField;
import javafx.scene.input.Clipboard;
import javafx.scene.input.ClipboardContent;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;
import javafx.util.Duration;

import java.awt.Desktop;
import java.io.File;
import java.net.URL;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class HostApplication extends Application {
    private static final DateTimeFormatter REFRESH_TIME_FORMAT =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private HostRuntime runtime;
    private Timeline autoRefresh;

    private final ObjectProperty<HostPage> activePage = new SimpleObjectProperty<>(HostPage.OVERVIEW);
    private final Map<HostPage, Button> pageButtons = new LinkedHashMap<>();
    private final Map<HostPage, Node> pageViews = new LinkedHashMap<>();
    private final Map<HostPage, Runnable> pageRefreshers = new LinkedHashMap<>();

    @Override
    public void start(Stage stage) throws Exception {
        runtime = new HostRuntime();
        runtime.start();

        Label title = new Label("包貨小精靈 Host");
        title.getStyleClass().add("header-title");

        Label subtitle = new Label("管理中央資料庫、配對碼與同步中的 client。");
        subtitle.getStyleClass().add("header-subtitle");

        HBox segmentBar = new HBox(10);
        segmentBar.getStyleClass().add("segment-bar");
        segmentBar.getChildren().addAll(
            createPageButton(HostPage.OVERVIEW, "總覽"),
            createPageButton(HostPage.ORDERS, "貨單"),
            createPageButton(HostPage.CLIENTS, "Client"),
            createPageButton(HostPage.EXPORTS, "匯出")
        );

        StackPane contentStack = new StackPane();
        contentStack.getStyleClass().add("content-stack");
        pageViews.put(HostPage.OVERVIEW, buildOverviewPage());
        pageViews.put(HostPage.ORDERS, buildOrdersPage());
        pageViews.put(HostPage.CLIENTS, buildClientsPage());
        pageViews.put(HostPage.EXPORTS, buildExportsPage());
        contentStack.getChildren().addAll(pageViews.values());

        activePage.addListener((obs, oldPage, newPage) -> updateActivePage());
        updateActivePage();

        VBox content = new VBox(18,
            new VBox(6, title, subtitle),
            segmentBar,
            contentStack
        );
        VBox.setVgrow(contentStack, Priority.ALWAYS);
        content.setPadding(new Insets(20));

        BorderPane root = new BorderPane(content);
        root.getStyleClass().add("app-root");

        Scene scene = new Scene(root, 1320, 900);
        URL stylesheet = HostApplication.class.getResource("/host.css");
        if (stylesheet != null) {
            scene.getStylesheets().add(stylesheet.toExternalForm());
        }

        stage.setTitle("包貨小精靈 Host");
        stage.setScene(scene);
        stage.show();

        autoRefresh = new Timeline(new KeyFrame(Duration.seconds(5), event -> refreshAll(false)));
        autoRefresh.setCycleCount(Animation.INDEFINITE);
        autoRefresh.play();
        refreshAll(false);
    }

    @Override
    public void stop() throws Exception {
        if (autoRefresh != null) {
            autoRefresh.stop();
        }
        if (runtime != null) {
            runtime.close();
        }
    }

    private Button createPageButton(HostPage page, String text) {
        Button button = new Button(text);
        button.getStyleClass().add("segment-button");
        button.setOnAction(event -> activePage.set(page));
        pageButtons.put(page, button);
        return button;
    }

    private void updateActivePage() {
        for (Map.Entry<HostPage, Button> entry : pageButtons.entrySet()) {
            Button button = entry.getValue();
            button.getStyleClass().remove("segment-button-active");
            if (entry.getKey() == activePage.get()) {
                button.getStyleClass().add("segment-button-active");
            }
        }

        for (Map.Entry<HostPage, Node> entry : pageViews.entrySet()) {
            boolean isActive = entry.getKey() == activePage.get();
            entry.getValue().setVisible(isActive);
            entry.getValue().setManaged(isActive);
        }
    }

    private Node buildOverviewPage() {
        Label serviceStatus = statusPill("啟動中", "warning");
        Label databaseStatus = statusPill("正常", "success");
        Label syncStatus = statusPill("檢查中", "warning");

        Label totalOrdersValue = metricValue();
        Label pairedClientsValue = metricValue();
        Label latestRevisionValue = metricValue();
        Label todayOrdersValue = metricValue();
        Label hostNameValue = detailValue(true);
        Label baseUrlValue = detailValue(true);
        Label mdnsNameValue = detailValue(false);
        Label dbPathValue = detailValue(true);
        Label exportPathValue = detailValue(true);
        Label lastRefreshValue = detailValue(false);

        TextField tokenField = new TextField();
        tokenField.setPromptText("輸入配對碼");
        tokenField.getStyleClass().add("host-input");

        Button saveTokenButton = primaryButton("儲存配對碼");
        Button regenerateTokenButton = secondaryButton("重新產生");
        Button refreshButton = secondaryButton("重新整理");
        Button copyBaseUrlButton = secondaryButton("複製主機網址");
        Button openDataFolderButton = secondaryButton("開啟資料夾");
        Button openExportFolderButton = secondaryButton("開啟匯出資料夾");

        saveTokenButton.setOnAction(event -> {
            try {
                runtime.setPairingToken(tokenField.getText());
                tokenField.setText(runtime.pairingToken());
                showInfo("配對碼已更新", "新的配對碼已經儲存，client 之後請改用新配對碼。");
                refreshAll(false);
            } catch (Exception ex) {
                showError("儲存失敗", ex.getMessage());
            }
        });

        regenerateTokenButton.setOnAction(event -> tokenField.setText(runtime.generatedPairingToken()));
        refreshButton.setOnAction(event -> refreshAll(true));
        copyBaseUrlButton.setOnAction(event -> {
            ClipboardContent content = new ClipboardContent();
            content.putString(baseUrlValue.getText());
            Clipboard.getSystemClipboard().setContent(content);
            showInfo("已複製", "主機資料庫網址已複製到剪貼簿。");
        });
        openDataFolderButton.setOnAction(event -> openPath(runtime.dataDirectoryPath()));
        openExportFolderButton.setOnAction(event -> openPath(runtime.exportDirectoryPath()));

        pageRefreshers.put(HostPage.OVERVIEW, () -> {
            try {
                totalOrdersValue.setText(String.valueOf(runtime.activeOrderCount()));
                pairedClientsValue.setText(String.valueOf(runtime.pairedClientCount()));
                latestRevisionValue.setText(String.valueOf(runtime.latestRevision()));
                todayOrdersValue.setText(String.valueOf(runtime.orders().stream()
                    .filter(order -> order.createdAt() != null && order.createdAt().startsWith(LocalDate.now().toString()))
                    .count()));

                hostNameValue.setText(runtime.hostName());
                baseUrlValue.setText(runtime.baseUrl());
                mdnsNameValue.setText(runtime.advertisedName());
                dbPathValue.setText(runtime.dbPath());
                exportPathValue.setText(runtime.exportDirectoryPath());
                lastRefreshValue.setText(LocalDateTime.now().format(REFRESH_TIME_FORMAT));
                tokenField.setText(runtime.pairingToken());

                setStatusPill(serviceStatus, "正常", "success");
                setStatusPill(databaseStatus, "正常", "success");
                setStatusPill(syncStatus, runtime.pairedClientCount() > 0 ? "已配對" : "等待配對", runtime.pairedClientCount() > 0 ? "success" : "warning");
            } catch (Exception ex) {
                setStatusPill(serviceStatus, "錯誤", "danger");
                setStatusPill(databaseStatus, "錯誤", "danger");
                setStatusPill(syncStatus, "錯誤", "danger");
            }
        });

        FlowPane metrics = new FlowPane();
        metrics.setHgap(16);
        metrics.setVgap(16);
        metrics.getChildren().addAll(
            metricCard("中央貨單", totalOrdersValue, "筆"),
            metricCard("已配對 client", pairedClientsValue, "台"),
            metricCard("最新修訂", latestRevisionValue, "次"),
            metricCard("今日新增", todayOrdersValue, "筆")
        );

        VBox statusCard = card(
            "主機總覽",
            "這台主機負責接收 client 同步的貨單，並將資料保存到中央資料庫。",
            metrics,
            new FlowPane(14, 14,
                statusMiniCard("服務狀態", serviceStatus),
                statusMiniCard("中央資料庫", databaseStatus),
                statusMiniCard("同步狀態", syncStatus)
            ),
            detailGrid(
                detailRow("主機名稱", hostNameValue),
                detailRow("主機網址", baseUrlValue),
                detailRow("mDNS 名稱", mdnsNameValue),
                detailRow("資料庫路徑", dbPathValue),
                detailRow("匯出資料夾", exportPathValue),
                detailRow("最後更新", lastRefreshValue)
            ),
            actionRow(refreshButton, copyBaseUrlButton, openDataFolderButton, openExportFolderButton)
        );

        VBox tokenCard = card(
            "配對設定",
            "client 需要使用這組配對碼連到 host。若需要更換，只要儲存新配對碼即可。",
            labeledInput("配對碼", tokenField),
            actionRow(saveTokenButton, regenerateTokenButton)
        );

        VBox content = new VBox(18, statusCard, tokenCard);
        return wrapPage(content);
    }

    private Node buildOrdersPage() {
        TextField searchField = new TextField();
        searchField.setPromptText("搜尋貨單號碼、發票號碼、買家或總金額");
        searchField.getStyleClass().add("host-input");

        TableView<HostOrder> ordersTable = buildOrdersTable();
        FilteredList<HostOrder> filteredOrders = new FilteredList<>(runtime.orders(), order -> true);
        searchField.textProperty().addListener((obs, oldValue, newValue) -> {
            String search = newValue == null ? "" : newValue.trim().toLowerCase();
            filteredOrders.setPredicate(order -> search.isBlank()
                || safe(order.orderNumber()).toLowerCase().contains(search)
                || safe(order.invoiceNumber()).toLowerCase().contains(search)
                || safe(order.buyerName()).toLowerCase().contains(search)
                || String.valueOf(order.totalAmount()).contains(search)
                || normalizeStatus(order.orderStatus()).contains(search));
        });
        ordersTable.setItems(filteredOrders);

        Label countLabel = new Label();
        countLabel.getStyleClass().add("section-description");
        countLabel.textProperty().bind(Bindings.size(filteredOrders).asString("顯示 %d 筆貨單"));

        Button refreshButton = secondaryButton("重新整理");
        refreshButton.setOnAction(event -> refreshAll(true));

        VBox content = new VBox(18,
            card(
                "貨單列表",
                "查看所有已同步到主機的貨單資料，可依貨單號碼、發票號碼、買家、狀態或總金額搜尋。",
                row(searchField, countLabel, spacer(), refreshButton),
                ordersTable
            )
        );
        VBox.setVgrow(ordersTable, Priority.ALWAYS);

        pageRefreshers.put(HostPage.ORDERS, () -> { });
        return wrapPage(content);
    }

    private Node buildClientsPage() {
        TableView<HostClientInfo> clientsTable = buildClientsTable();
        clientsTable.setItems(runtime.clients());

        Label countLabel = new Label();
        countLabel.getStyleClass().add("section-description");
        countLabel.textProperty().bind(Bindings.size(runtime.clients()).asString("目前共有 %d 台 client"));

        Button refreshButton = secondaryButton("重新整理");
        refreshButton.setOnAction(event -> refreshAll(true));

        VBox content = new VBox(18,
            card(
                "Client 列表",
                "查看目前已配對的 client、最後上線時間，以及同步到哪個修訂版本。",
                row(countLabel, spacer(), refreshButton),
                clientsTable
            )
        );
        VBox.setVgrow(clientsTable, Priority.ALWAYS);

        pageRefreshers.put(HostPage.CLIENTS, () -> { });
        return wrapPage(content);
    }

    private Node buildExportsPage() {
        DatePicker dayPicker = new DatePicker(LocalDate.now());
        DatePicker rangeStartPicker = new DatePicker(LocalDate.now());
        DatePicker rangeEndPicker = new DatePicker(LocalDate.now());
        DatePicker monthPicker = new DatePicker(LocalDate.now());

        styleDatePicker(dayPicker);
        styleDatePicker(rangeStartPicker);
        styleDatePicker(rangeEndPicker);
        styleDatePicker(monthPicker);

        Label exportPathLabel = detailValue(true);
        exportPathLabel.setText(runtime.exportDirectoryPath());

        Button exportDayButton = primaryButton("匯出當日");
        Button exportRangeButton = primaryButton("匯出區間");
        Button exportMonthButton = primaryButton("匯出月份");
        Button openExportFolderButton = secondaryButton("開啟匯出資料夾");

        exportDayButton.setOnAction(event -> {
            LocalDate date = dayPicker.getValue();
            if (date == null) {
                showError("缺少日期", "請先選擇要匯出的日期。");
                return;
            }
            try {
                Path filePath = runtime.exportDay(date);
                showInfo("匯出完成", "已匯出 1 份 Excel。\n" + filePath);
            } catch (Exception ex) {
                showError("匯出失敗", ex.getMessage());
            }
        });

        exportRangeButton.setOnAction(event -> {
            LocalDate startDate = rangeStartPicker.getValue();
            LocalDate endDate = rangeEndPicker.getValue();
            if (startDate == null || endDate == null) {
                showError("缺少日期", "請先選擇開始與結束日期。");
                return;
            }
            if (endDate.isBefore(startDate)) {
                showError("日期錯誤", "結束日期不能早於開始日期。");
                return;
            }
            try {
                List<Path> files = runtime.exportRange(startDate, endDate);
                showInfo("匯出完成", "已匯出 " + files.size() + " 份 Excel 到資料夾。\n" + runtime.exportDirectoryPath());
            } catch (Exception ex) {
                showError("匯出失敗", ex.getMessage());
            }
        });

        exportMonthButton.setOnAction(event -> {
            LocalDate selectedDate = monthPicker.getValue();
            if (selectedDate == null) {
                showError("缺少月份", "請先選擇任一個該月份內的日期。");
                return;
            }
            try {
                YearMonth month = YearMonth.from(selectedDate);
                Path filePath = runtime.exportMonth(month);
                showInfo("匯出完成", "已匯出 " + month + " 的 Excel。\n" + filePath);
            } catch (Exception ex) {
                showError("匯出失敗", ex.getMessage());
            }
        });

        openExportFolderButton.setOnAction(event -> openPath(runtime.exportDirectoryPath()));

        VBox content = new VBox(18,
            card(
                "資料匯出",
                "可以依單日、日期區間或整個月份匯出 Excel。日期區間會依每天各自產出一份檔案。",
                exportOptionCard(
                    "匯出單日",
                    "選擇某一天後，匯出該日的所有貨單紀錄。",
                    row(labeledInput("日期", dayPicker), exportDayButton)
                ),
                exportOptionCard(
                    "匯出日期區間",
                    "例如 3/1 到 3/5，會產出 5 份各自對應日期的 Excel。",
                    row(
                        labeledInput("開始日期", rangeStartPicker),
                        labeledInput("結束日期", rangeEndPicker),
                        exportRangeButton
                    )
                ),
                exportOptionCard(
                    "匯出整月",
                    "選擇該月份內任一日期，即可匯出整個月份為一份 Excel。",
                    row(labeledInput("月份", monthPicker), exportMonthButton)
                ),
                card(
                    "匯出資料夾",
                    "所有匯出的檔案都會放在同一個資料夾，方便整理與傳送。",
                    detailGrid(detailRow("資料夾位置", exportPathLabel)),
                    actionRow(openExportFolderButton)
                )
            )
        );

        pageRefreshers.put(HostPage.EXPORTS, () -> exportPathLabel.setText(runtime.exportDirectoryPath()));
        return wrapPage(content);
    }

    private Node wrapPage(Node content) {
        ScrollPane scrollPane = new ScrollPane(content);
        scrollPane.getStyleClass().add("page-scroll");
        scrollPane.setFitToWidth(true);
        scrollPane.setPannable(true);
        scrollPane.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        VBox.setVgrow(scrollPane, Priority.ALWAYS);
        return scrollPane;
    }

    private void refreshAll(boolean notifyOnFailure) {
        try {
            runtime.refreshData("");
            for (Runnable refreshAction : pageRefreshers.values()) {
                refreshAction.run();
            }
        } catch (Exception ex) {
            if (notifyOnFailure) {
                showError("重新整理失敗", ex.getMessage());
            }
        }
    }

    private TableView<HostOrder> buildOrdersTable() {
        TableView<HostOrder> table = new TableView<>();
        table.getStyleClass().add("host-table");
        table.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY_FLEX_LAST_COLUMN);
        table.setPlaceholder(sectionDescription("目前沒有可顯示的貨單資料。"));
        table.getColumns().add(orderColumn("貨單號碼", HostOrder::orderNumber));
        table.getColumns().add(orderColumn("發票號碼", HostOrder::invoiceNumber));
        table.getColumns().add(orderColumn("買家", HostOrder::buyerName));
        table.getColumns().add(orderColumn("日期", HostOrder::orderDate));
        table.getColumns().add(numberTextColumn("總金額", HostOrder::totalAmount));
        table.getColumns().add(orderColumn("狀態", order -> normalizeStatus(order.orderStatus())));
        table.getColumns().add(orderColumn("更新 Client", HostOrder::updatedByClientId));
        table.setMinHeight(540);
        VBox.setVgrow(table, Priority.ALWAYS);
        return table;
    }

    private TableView<HostClientInfo> buildClientsTable() {
        TableView<HostClientInfo> table = new TableView<>();
        table.getStyleClass().add("host-table");
        table.setColumnResizePolicy(TableView.CONSTRAINED_RESIZE_POLICY_FLEX_LAST_COLUMN);
        table.setPlaceholder(sectionDescription("目前沒有已配對的 client。"));
        table.getColumns().add(clientColumn("名稱", HostClientInfo::clientName));
        table.getColumns().add(clientColumn("Client ID", HostClientInfo::clientId));
        table.getColumns().add(clientColumn("建立時間", HostClientInfo::createdAt));
        table.getColumns().add(clientColumn("最後上線", HostClientInfo::lastSeenAt));
        table.getColumns().add(numberColumn("同步版本", HostClientInfo::lastKnownHostRevision));
        table.setMinHeight(540);
        VBox.setVgrow(table, Priority.ALWAYS);
        return table;
    }

    private VBox card(String title, String description, Node... content) {
        Label titleLabel = new Label(title);
        titleLabel.getStyleClass().add("section-title");

        Label descriptionLabel = new Label(description);
        descriptionLabel.getStyleClass().add("section-description");
        descriptionLabel.setWrapText(true);

        VBox box = new VBox(16, titleLabel, descriptionLabel);
        box.getStyleClass().add("card");
        box.setPadding(new Insets(22));
        box.getChildren().addAll(content);
        return box;
    }

    private VBox metricCard(String title, Label valueLabel, String unit) {
        Label titleLabel = new Label(title);
        titleLabel.getStyleClass().add("metric-title");

        Label unitLabel = new Label(unit);
        unitLabel.getStyleClass().add("metric-unit");

        VBox box = new VBox(12, titleLabel, valueLabel, unitLabel);
        box.getStyleClass().add("metric-card");
        box.setPrefWidth(210);
        box.setMinHeight(140);
        return box;
    }

    private VBox statusMiniCard(String title, Label statusLabel) {
        Label titleLabel = new Label(title);
        titleLabel.getStyleClass().add("mini-card-title");

        VBox box = new VBox(14, titleLabel, statusLabel);
        box.getStyleClass().add("mini-card");
        box.setPrefWidth(220);
        return box;
    }

    private Node exportOptionCard(String title, String description, Node content) {
        VBox box = new VBox(12,
            sectionHeading(title),
            sectionDescription(description),
            content
        );
        box.getStyleClass().add("mini-card");
        return box;
    }

    private GridPane detailGrid(Node... rows) {
        GridPane grid = new GridPane();
        grid.setHgap(18);
        grid.setVgap(12);
        for (int i = 0; i < rows.length; ++i) {
            grid.add(rows[i], 0, i);
        }
        return grid;
    }

    private HBox detailRow(String title, Label value) {
        Label key = new Label(title);
        key.getStyleClass().add("detail-key");
        key.setMinWidth(120);

        HBox row = new HBox(18, key, value);
        row.setAlignment(Pos.TOP_LEFT);
        return row;
    }

    private VBox labeledInput(String labelText, Node input) {
        return new VBox(8, sectionHeading(labelText), input);
    }

    private HBox actionRow(Node... nodes) {
        HBox row = new HBox(12, nodes);
        row.setAlignment(Pos.CENTER_LEFT);
        row.setFillHeight(true);
        return row;
    }

    private HBox row(Node... nodes) {
        HBox row = new HBox(12, nodes);
        row.setAlignment(Pos.CENTER_LEFT);
        return row;
    }

    private Region spacer() {
        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);
        return spacer;
    }

    private Label metricValue() {
        Label label = new Label("0");
        label.getStyleClass().add("metric-value");
        return label;
    }

    private Label detailValue(boolean wrapText) {
        Label label = new Label();
        label.getStyleClass().add("detail-value");
        label.setWrapText(wrapText);
        label.setMaxWidth(Double.MAX_VALUE);
        return label;
    }

    private Label sectionHeading(String text) {
        Label label = new Label(text);
        label.getStyleClass().add("mini-card-title");
        return label;
    }

    private Label sectionDescription(String text) {
        Label label = new Label(text);
        label.getStyleClass().add("section-description");
        label.setWrapText(true);
        return label;
    }

    private Label statusPill(String text, String tone) {
        Label label = new Label(text);
        label.getStyleClass().addAll("status-pill", "status-" + tone);
        return label;
    }

    private void setStatusPill(Label label, String text, String tone) {
        label.setText(text);
        label.getStyleClass().removeIf(styleClass -> styleClass.startsWith("status-"));
        label.getStyleClass().add("status-" + tone);
    }

    private Button primaryButton(String text) {
        Button button = new Button(text);
        button.getStyleClass().addAll("host-button", "host-button-primary");
        button.setMinHeight(42);
        return button;
    }

    private Button secondaryButton(String text) {
        Button button = new Button(text);
        button.getStyleClass().addAll("host-button", "host-button-secondary");
        button.setMinHeight(42);
        return button;
    }

    private void styleDatePicker(DatePicker datePicker) {
        datePicker.getStyleClass().add("host-date-picker");
        datePicker.setEditable(false);
    }

    private void openPath(String pathValue) {
        try {
            Desktop.getDesktop().open(new File(pathValue));
        } catch (Exception ex) {
            showError("開啟失敗", ex.getMessage());
        }
    }

    private void showInfo(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.INFORMATION);
        alert.setTitle(title);
        alert.setHeaderText(title);
        alert.setContentText(message);
        alert.showAndWait();
    }

    private void showError(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.ERROR);
        alert.setTitle(title);
        alert.setHeaderText(title);
        alert.setContentText(message);
        alert.showAndWait();
    }

    private TableColumn<HostOrder, String> orderColumn(String title,
                                                       java.util.function.Function<HostOrder, String> getter) {
        TableColumn<HostOrder, String> column = new TableColumn<>(title);
        column.setCellValueFactory(cell -> new SimpleStringProperty(safe(getter.apply(cell.getValue()))));
        return column;
    }

    private TableColumn<HostOrder, String> numberTextColumn(String title,
                                                            java.util.function.ToLongFunction<HostOrder> getter) {
        TableColumn<HostOrder, String> column = new TableColumn<>(title);
        column.setCellValueFactory(cell -> {
            long value = getter.applyAsLong(cell.getValue());
            return new SimpleStringProperty(value > 0 ? String.valueOf(value) : "");
        });
        return column;
    }

    private TableColumn<HostClientInfo, String> clientColumn(String title,
                                                             java.util.function.Function<HostClientInfo, String> getter) {
        TableColumn<HostClientInfo, String> column = new TableColumn<>(title);
        column.setCellValueFactory(cell -> new SimpleStringProperty(safe(getter.apply(cell.getValue()))));
        return column;
    }

    private TableColumn<HostClientInfo, Number> numberColumn(String title,
                                                             java.util.function.ToLongFunction<HostClientInfo> getter) {
        TableColumn<HostClientInfo, Number> column = new TableColumn<>(title);
        column.setCellValueFactory(cell -> new SimpleLongProperty(getter.applyAsLong(cell.getValue())));
        return column;
    }

    private String normalizeStatus(String status) {
        return switch (safe(status).trim().toLowerCase()) {
            case "success" -> "成功";
            case "canceled", "cancelled" -> "取消";
            case "closed" -> "門市關轉";
            default -> safe(status);
        };
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }

    private enum HostPage {
        OVERVIEW,
        ORDERS,
        CLIENTS,
        EXPORTS
    }
}
