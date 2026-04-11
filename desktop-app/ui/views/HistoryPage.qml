import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PackingElf 1.0

ContentPage {
    id: historyView
    anchors.fill: parent

    title: qsTr("歷史紀錄")
    subtitle: qsTr("依日期、狀態或關鍵字查詢已完成貨單")

    property int selectedHistoryRow: -1
    property string selectedHistoryOrderNumber: ""
    property string pendingFromDate: ""
    property string pendingToDate: ""
    property string calendarTarget: ""
    property int calendarYear: (new Date()).getFullYear()
    property int calendarMonth: (new Date()).getMonth()
    readonly property var statusOptions: [
        { text: qsTr("全部"), value: "all" },
        { text: qsTr("成功"), value: "success" },
        { text: qsTr("關轉"), value: "closed" },
        { text: qsTr("取消"), value: "canceled" }
    ]

    function clearSelection() {
        selectedHistoryRow = -1;
        selectedHistoryOrderNumber = "";
        historyTable.currentIndex = -1;
    }

    function selectRow(row) {
        selectedHistoryRow = row;
        selectedHistoryOrderNumber = HistoryOrdersTableVM.orderNumberAt(row);
    }

    function formatDatePart(value) {
        return String(value).padStart(2, "0");
    }

    function formatDateString(year, month, day) {
        return year + "-" + formatDatePart(month + 1) + "-" + formatDatePart(day);
    }

    function parseIsoDate(value) {
        if (!value || String(value).length < 10)
            return null;

        var parts = String(value).split("-");
        if (parts.length !== 3)
            return null;

        var year = Number(parts[0]);
        var month = Number(parts[1]) - 1;
        var day = Number(parts[2]);
        if (isNaN(year) || isNaN(month) || isNaN(day))
            return null;

        return new Date(year, month, day);
    }

    function openCalendar(target) {
        calendarTarget = target;
        var sourceText = target === "from" ? pendingFromDate : pendingToDate;
        var parsed = parseIsoDate(sourceText);
        var basis = parsed || new Date();
        calendarYear = basis.getFullYear();
        calendarMonth = basis.getMonth();
        datePickerPopup.open();
    }

    function visibleMonthLabel() {
        return calendarYear + " / " + formatDatePart(calendarMonth + 1);
    }

    function shiftMonth(delta) {
        var next = new Date(calendarYear, calendarMonth + delta, 1);
        calendarYear = next.getFullYear();
        calendarMonth = next.getMonth();
    }

    function firstDayOffset() {
        var day = new Date(calendarYear, calendarMonth, 1).getDay();
        return (day + 6) % 7;
    }

    function daysInVisibleMonth() {
        return new Date(calendarYear, calendarMonth + 1, 0).getDate();
    }

    function dayForCell(index) {
        var day = index - firstDayOffset() + 1;
        if (day < 1 || day > daysInVisibleMonth())
            return 0;
        return day;
    }

    function isSelectedDay(day) {
        if (day <= 0)
            return false;

        var currentText = calendarTarget === "from" ? pendingFromDate : pendingToDate;
        var parsed = parseIsoDate(currentText);
        return parsed
            && parsed.getFullYear() === calendarYear
            && parsed.getMonth() === calendarMonth
            && parsed.getDate() === day;
    }

    function pickDay(day) {
        if (day <= 0)
            return;

        var formatted = formatDateString(calendarYear, calendarMonth, day);
        if (calendarTarget === "from")
            pendingFromDate = formatted;
        else if (calendarTarget === "to")
            pendingToDate = formatted;
        datePickerPopup.close();
    }

    function clearDate(target) {
        if (target === "from")
            pendingFromDate = "";
        else
            pendingToDate = "";
    }

    function applyFilters() {
        var fromDate = parseIsoDate(pendingFromDate);
        var toDate = parseIsoDate(pendingToDate);
        if (fromDate && toDate && fromDate > toDate) {
            AppDialog.showWarning(
                qsTr("日期區間無效"),
                qsTr("開始日期不能晚於結束日期。")
            );
            return;
        }

        var statusValue = historyStatusDropdown.currentValue;
        if (statusValue === undefined || statusValue === null || statusValue === "")
            statusValue = "all";

        HistoryOrdersTableVM.applyFilters(String(statusValue),
                                          searchInput.text,
                                          pendingFromDate,
                                          pendingToDate);
        clearSelection();
    }

    function resetFilters() {
        searchInput.text = "";
        pendingFromDate = "";
        pendingToDate = "";
        historyStatusDropdown.currentIndex = 0;
        HistoryOrdersTableVM.clearFilters();
        clearSelection();
    }

    function formatOrderStatus(status) {
        var normalized = String(status || "").trim().toLowerCase();
        if (normalized === "success")
            return qsTr("成功");
        if (normalized === "canceled")
            return qsTr("取消");
        if (normalized === "closed")
            return qsTr("關轉");
        return normalized.length > 0 ? normalized : qsTr("未記錄");
    }

    function formatCouponFlag(usingCoupon) {
        return usingCoupon ? qsTr("有") : qsTr("無");
    }

    function orderSummary(details) {
        return qsTr("貨單號碼：%1\n發票號碼：%2\n訂單日期：%3\n目前狀態：%4\n優惠券：%5")
            .arg(String(details.orderNumber || qsTr("未記錄")))
            .arg(String(details.invoiceNumber || qsTr("未記錄")))
            .arg(String(details.orderDate || qsTr("未記錄")))
            .arg(formatOrderStatus(details.status))
            .arg(formatCouponFlag(Boolean(details.usingCoupon)));
    }

    function requestDeleteSelectedOrder() {
        if (selectedHistoryRow < 0)
            return;

        var details = OrdersVM.orderDetailsByOrderNumber(selectedHistoryOrderNumber);
        if (!details || !details.id)
            return;

        AppDialog.confirm({
            titleText: qsTr("刪除歷史紀錄"),
            messageText: qsTr("確定要刪除這筆歷史紀錄嗎？\n\n%1").arg(orderSummary(details)),
            confirmText: qsTr("刪除"),
            cancelText: qsTr("取消"),
            iconSource: AppDialog.warningIcon,
            accentColor: Theme.warningColor,
            onConfirmAction: function() {
                if (!OrdersVM.removeOrderByOrderNumber(historyView.selectedHistoryOrderNumber)) {
                    AppDialog.showError(qsTr("刪除失敗"), qsTr("無法刪除這筆歷史紀錄，請稍後再試。"));
                    return;
                }

                historyView.clearSelection();
            }
        });
    }

    Component.onCompleted: {
        historyStatusDropdown.currentIndex = 0;
        applyFilters();
    }

    Connections {
        target: HistoryOrdersTableVM
        function onCountChanged() {
            if (historyView.selectedHistoryRow >= HistoryOrdersTableVM.count)
                historyView.clearSelection();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.pageGap

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumHeight: 188
            radius: 16
            color: Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, Constants.basicOpacity)
            border.color: Theme.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: qsTr("查詢條件")
                    color: Theme.header1Color
                    font.pixelSize: Constants.header2FontSize
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    CustomEntry {
                        id: searchInput
                        placeholderText: qsTr("搜尋貨單號碼或發票號碼")
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        onAccepted: historyView.applyFilters()
                    }

                    CustomButton {
                        text: qsTr("搜尋")
                        highlighted: true
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 44
                        onClicked: historyView.applyFilters()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: qsTr("開始日期")
                        color: Theme.header3Color
                        font.pixelSize: Constants.header3FontSize
                    }

                    Item {
                        Layout.preferredWidth: 138
                        Layout.preferredHeight: 40

                        CustomEntry {
                            anchors.fill: parent
                            text: historyView.pendingFromDate
                            placeholderText: qsTr("選擇開始日期")
                            readOnly: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historyView.openCalendar("from")
                        }
                    }

                    CustomButton {
                        text: qsTr("清空")
                        Layout.preferredWidth: 60
                        onClicked: historyView.clearDate("from")
                    }

                    Text {
                        text: qsTr("結束日期")
                        color: Theme.header3Color
                        font.pixelSize: Constants.header3FontSize
                        Layout.leftMargin: 2
                    }

                    Item {
                        Layout.preferredWidth: 138
                        Layout.preferredHeight: 40

                        CustomEntry {
                            anchors.fill: parent
                            text: historyView.pendingToDate
                            placeholderText: qsTr("選擇結束日期")
                            readOnly: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historyView.openCalendar("to")
                        }
                    }

                    CustomButton {
                        text: qsTr("清空")
                        Layout.preferredWidth: 60
                        onClicked: historyView.clearDate("to")
                    }

                    Text {
                        text: qsTr("狀態")
                        color: Theme.header3Color
                        font.pixelSize: Constants.header3FontSize
                        Layout.leftMargin: 2
                    }

                    CustomDropdown {
                        id: historyStatusDropdown
                        model: historyView.statusOptions
                        textRole: "text"
                        valueRole: "value"
                        placeholderText: qsTr("全部")
                        Layout.preferredWidth: 96
                    }

                    Item { Layout.fillWidth: true }

                    CustomButton {
                        text: qsTr("套用")
                        highlighted: true
                        Layout.preferredWidth: 80
                        onClicked: historyView.applyFilters()
                    }

                    CustomButton {
                        text: qsTr("重設")
                        Layout.preferredWidth: 80
                        onClicked: historyView.resetFilters()
                    }
                }
            }
        }

        CustomTable {
            id: historyTable
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: [
                { title: qsTr("日期"), role: "date", width: 0.16 },
                { title: qsTr("貨單號碼"), role: "orderNumber", width: 0.28 },
                { title: qsTr("發票號碼"), role: "invoiceNumber", width: 0.20 },
                { title: qsTr("買家"), role: "accountName", width: 0.16 },
                { title: qsTr("狀態"), role: "status", width: 0.10 },
                { title: qsTr("優惠券"), role: "usingCoupon", width: 0.10 }
            ]
            model: HistoryOrdersTableVM

            onRowClicked: index => {
                historyView.selectRow(index);
            }
        }

        RowLayout {
            Layout.fillWidth: true

            CustomButton {
                text: qsTr("清除選取")
                enabled: historyView.selectedHistoryRow >= 0
                onClicked: historyView.clearSelection()
            }

            CustomButton {
                text: qsTr("刪除")
                enabled: historyView.selectedHistoryRow >= 0
                onClicked: historyView.requestDeleteSelectedOrder()
            }

            Item { Layout.fillWidth: true }

            Text {
                color: Theme.header3Color
                text: qsTr("目前顯示 %1 筆資料").arg(HistoryOrdersTableVM.count)
                font.pixelSize: Constants.header3FontSize
            }
        }
    }

    Popup {
        id: datePickerPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        width: 300
        height: 330
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.round(((parent ? parent.width : width) - width) / 2)
        y: Math.round(((parent ? parent.height : height) - height) / 2)

        background: Rectangle {
            radius: 16
            color: Theme.sidebarColor
            border.color: Theme.borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                CustomButton {
                    text: qsTr("上月")
                    Layout.preferredWidth: 70
                    onClicked: historyView.shiftMonth(-1)
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: historyView.visibleMonthLabel()
                    color: Theme.header1Color
                    font.pixelSize: Constants.header3FontSize
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                CustomButton {
                    text: qsTr("下月")
                    Layout.preferredWidth: 70
                    onClicked: historyView.shiftMonth(1)
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: [qsTr("一"), qsTr("二"), qsTr("三"), qsTr("四"), qsTr("五"), qsTr("六"), qsTr("日")]

                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: Theme.headerSubColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: 42

                    delegate: Rectangle {
                        required property int index
                        readonly property int day: historyView.dayForCell(index)
                        readonly property bool selected: historyView.isSelectedDay(day)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 8
                        color: day === 0
                               ? "transparent"
                               : selected
                                 ? Theme.primaryColor
                                 : Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.08)
                        border.color: day === 0 ? "transparent" : (selected ? Theme.primaryColor : Theme.borderColor)

                        Text {
                            anchors.centerIn: parent
                            text: day > 0 ? String(day) : ""
                            color: selected ? "#000000" : Theme.header3Color
                            font.pixelSize: Constants.header3FontSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: day > 0
                            hoverEnabled: true
                            cursorShape: day > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: historyView.pickDay(day)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                CustomButton {
                    text: qsTr("取消")
                    onClicked: datePickerPopup.close()
                }
            }
        }
    }
}
