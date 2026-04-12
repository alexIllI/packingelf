package com.meridian.packingelf.host;

import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

final class HostExportService {
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ISO_LOCAL_DATE;

    private final Path exportDirectory;

    HostExportService(Path exportDirectory) throws IOException {
        this.exportDirectory = exportDirectory;
        Files.createDirectories(exportDirectory);
    }

    Path exportDirectory() {
        return exportDirectory;
    }

    Path exportDay(LocalDate date, List<HostOrder> orders) throws IOException {
        Path filePath = exportDirectory.resolve("packingelf-" + DATE_FORMAT.format(date) + ".xlsx");
        writeWorkbook(filePath, "貨單資料", orders);
        return filePath;
    }

    List<Path> exportRange(LocalDate fromDate, LocalDate toDate, HostRepository repository) throws Exception {
        List<Path> files = new ArrayList<>();
        LocalDate cursor = fromDate;
        while (!cursor.isAfter(toDate)) {
            files.add(exportDay(cursor, repository.loadOrdersForDate(cursor)));
            cursor = cursor.plusDays(1);
        }
        return files;
    }

    Path exportMonth(YearMonth month, List<HostOrder> orders) throws IOException {
        Path filePath = exportDirectory.resolve("packingelf-" + month + ".xlsx");
        writeWorkbook(filePath, month + " 貨單資料", orders);
        return filePath;
    }

    private void writeWorkbook(Path filePath, String sheetName, List<HostOrder> orders) throws IOException {
        try (XSSFWorkbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet(sheetName);
            CellStyle headerStyle = headerStyle(workbook);
            CellStyle dataStyle = dataStyle(workbook);

            String[] headers = {
                "訂單日期", "貨單號碼", "發票號碼", "買家", "總金額",
                "狀態", "使用優惠券", "建立 Client", "更新 Client",
                "建立時間", "更新時間"
            };

            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < headers.length; ++i) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            int rowIndex = 1;
            for (HostOrder order : orders) {
                Row row = sheet.createRow(rowIndex++);
                writeTextCell(row, 0, order.orderDate(), dataStyle);
                writeTextCell(row, 1, order.orderNumber(), dataStyle);
                writeTextCell(row, 2, order.invoiceNumber(), dataStyle);
                writeTextCell(row, 3, order.buyerName(), dataStyle);
                writeLongCell(row, 4, order.totalAmount(), dataStyle);
                writeTextCell(row, 5, normalizeStatus(order.orderStatus()), dataStyle);
                writeTextCell(row, 6, order.usingCoupon() ? "是" : "否", dataStyle);
                writeTextCell(row, 7, order.createdByClientId(), dataStyle);
                writeTextCell(row, 8, order.updatedByClientId(), dataStyle);
                writeTextCell(row, 9, order.createdAt(), dataStyle);
                writeTextCell(row, 10, order.updatedAt(), dataStyle);
            }

            for (int i = 0; i < headers.length; ++i) {
                sheet.autoSizeColumn(i);
                sheet.setColumnWidth(i, Math.min(sheet.getColumnWidth(i) + 768, 40 * 256));
            }

            try (OutputStream outputStream = Files.newOutputStream(filePath)) {
                workbook.write(outputStream);
            }
        }
    }

    private CellStyle headerStyle(XSSFWorkbook workbook) {
        Font font = workbook.createFont();
        font.setBold(true);
        font.setColor(IndexedColors.WHITE.getIndex());

        CellStyle style = workbook.createCellStyle();
        style.setFont(font);
        style.setFillForegroundColor(IndexedColors.DARK_BLUE.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        applyBorders(style);
        return style;
    }

    private CellStyle dataStyle(XSSFWorkbook workbook) {
        CellStyle style = workbook.createCellStyle();
        style.setAlignment(HorizontalAlignment.LEFT);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        applyBorders(style);
        return style;
    }

    private void applyBorders(CellStyle style) {
        style.setBorderTop(BorderStyle.THIN);
        style.setBorderRight(BorderStyle.THIN);
        style.setBorderBottom(BorderStyle.THIN);
        style.setBorderLeft(BorderStyle.THIN);
    }

    private void writeTextCell(Row row, int columnIndex, String value, CellStyle style) {
        Cell cell = row.createCell(columnIndex);
        cell.setCellValue(value == null ? "" : value);
        cell.setCellStyle(style);
    }

    private void writeLongCell(Row row, int columnIndex, long value, CellStyle style) {
        Cell cell = row.createCell(columnIndex);
        if (value > 0) {
            cell.setCellValue(value);
        } else {
            cell.setCellValue("");
        }
        cell.setCellStyle(style);
    }

    private String normalizeStatus(String status) {
        return switch (status == null ? "" : status.trim().toLowerCase()) {
            case "success" -> "成功";
            case "canceled", "cancelled" -> "取消";
            case "closed" -> "門市關轉";
            default -> status == null ? "" : status;
        };
    }
}
