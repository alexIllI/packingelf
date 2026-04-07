// ─────────────────────────────────────────────────────────────
// ScraperService.h
// Launches the Python scraper as a background QProcess and
// forwards the JSON result back to the rest of the application.
//
// DESIGN GOALS
// ─────────────────────────────────────────────────────────────
// • The Qt GUI thread is NEVER blocked.
//   The scraper runs as a separate OS process (QProcess).
//   If the scraper hangs, crashes, or times out, the Qt app
//   keeps running and the user is notified via scraperFailed().
//
// • Each scrape() call starts one QProcess.  Only one scrape
//   can be in-flight at a time (busy() guard prevents overlap).
//
// • All stdout from the scraper is buffered; once the process
//   exits the last line of JSON is parsed.
//
// • stderr from the scraper (its verbose step logs) is forwarded
//   to Qt's qDebug() so it appears in the IDE / Qt Creator log.
//
// COMMUNICATION PROTOCOL
// ─────────────────────────────────────────────────────────────
// Qt → scraper (process args):
//   scraper.exe scrape --order <orderNumber> --account <accountName>
//   scraper.exe scrape --order <orderNumber> --manual-login
//
// scraper → Qt (stdout, one JSON line):
//   {"status":"SUCCESS","buyer_name":"...","order_date":"...","using_coupon":true}
//   {"status":"ORDER_NOT_FOUND"}
//   {"status":"ERROR","message":"..."}
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QString>
#include <QByteArray>

// ─── Result struct ────────────────────────────────────────────
// Mirrors the JSON keys written by scraper/__main__.py.
struct ScraperResult {
    QString status;          // ScraperStatus string value
    QString buyerName;
    QString orderDate;
    bool    usingCoupon = false;
    QString message;         // Non-empty on failure

    bool isSuccess() const;

    // Parse from the raw JSON bytes written to scraper stdout.
    static ScraperResult fromJson(const QByteArray& jsonLine);
};

// ─── Service class ────────────────────────────────────────────
class ScraperService : public QObject {
    Q_OBJECT

    // QML can bind to this to show a "scraping…" spinner
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit ScraperService(QObject* parent = nullptr);
    ~ScraperService() override;

    bool busy() const;

    // ── Configuration (set before first call) ─────────────────

    // Full path to scraper.exe.  Defaults to "scraper/dist/scraper.exe"
    // relative to the application executable directory.
    void setScraperExe(const QString& path);

    // Milliseconds before the scraper process is killed (default: 120 000)
    void setTimeoutMs(int ms);

    // ── Main API ──────────────────────────────────────────────

    // Launch the scraper for one order.
    //
    // orderId      – UUID stored in OrdersRepository (returned to caller
    //                in scraperFinished so it can update the right row)
    // orderNumber  – e.g. "PG02491384"
    // accountName  – Friendly name key in the encrypted account store.
    //                Pass an empty string to use --manual-login mode.
    Q_INVOKABLE void scrape(const QString& orderId,
                            const QString& orderNumber,
                            const QString& accountName = QString());

    // Immediately kill any running scraper process.
    Q_INVOKABLE void cancel();

signals:
    // Emitted when the scraper process exits and JSON is parsed.
    // Check result.isSuccess() to distinguish success from order-level errors.
    void scraperFinished(const QString& orderId, const ScraperResult& result);

    // Emitted when the process crashes, times out, or cannot start.
    void scraperFailed(const QString& orderId, const QString& reason);

    void busyChanged();

private slots:
    void onFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onErrorOccurred(QProcess::ProcessError error);
    void onTimeout();

private:
    void cleanup();

    QProcess* m_process  = nullptr;
    QTimer*   m_timer    = nullptr;

    QString   m_currentOrderId;   // ID of the order being scraped
    QString   m_scraperExe;
    int       m_timeoutMs = 120'000;

    QByteArray m_stdoutBuf;        // Accumulates process stdout
};
