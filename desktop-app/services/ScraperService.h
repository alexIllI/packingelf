// ─────────────────────────────────────────────────────────────
// ScraperService.h
// Manages the long-running Python scraper daemon process.
//
// ARCHITECTURE (Daemon mode)
// ─────────────────────────────────────────────────────────────
// The scraper is a persistent QProcess that keeps the Chromium
// browser alive between print jobs.
//
// Lifecycle:
//   1. startBrowser()  → launches "scraper.exe daemon --account X"
//   2. Process emits   → {"type":"ready"}  → state = Ready
//   3. scrape() sends  → {"cmd":"scrape","order_id":"...","order_number":"..."}\n
//   4. Process emits   → {"type":"scrape_result", ...}
//   5. On unexpected process exit → state = Offline, emit browserDied()
//   6. restartBrowser() kills old process and calls startBrowser() again
//
// Stdin/Stdout protocol
// ─────────────────────────────────────────────────────────────
//   C++ → scraper stdin (commands):
//     {"cmd":"scrape",    "order_id":"uuid","order_number":"PG02412345"}
//     {"cmd":"calibrate"}
//     {"cmd":"ping"}
//     {"cmd":"quit"}
//
//   scraper stdout → C++ (events):
//     {"type":"ready"}
//     {"type":"scrape_result","order_id":"...","status":"SUCCESS",...}
//     {"type":"calibrate_result","ok":true,"url":"...","message":"..."}
//     {"type":"pong"}
//     {"type":"error","msg":"..."}
//
//   stderr → forwarded line-by-line to qDebug() (progress logs)
//
// Robustness
// ─────────────────────────────────────────────────────────────
//   • If the user closes the browser window, the process exits.
//     The Qt app detects this (onFinished), sets state=Offline and
//     emits browserDied(). The user can click 重新啟動 to recover.
//   • restartBrowser() is always safe — it kills any running process
//     first, then starts a fresh one. The Qt app never crashes.
//   • Only one scrape() or calibrate() can run at a time (busy guard).
// ─────────────────────────────────────────────────────────────
#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QString>
#include <QByteArray>

// ─── Result struct ────────────────────────────────────────────
// Mirrors the JSON keys in scrape_result events from the daemon.
struct ScraperResult {
    QString status;          // ScraperStatus value string
    QString buyerName;
    QString orderDate;
    bool    usingCoupon = false;
    QString message;         // Non-empty on any failure

    bool isSuccess() const;

    // Parse from a {"type":"scrape_result", ...} JSON object's raw bytes.
    static ScraperResult fromJson(const QByteArray& jsonLine);
};

// ─── Service class ────────────────────────────────────────────
class ScraperService : public QObject {
    Q_OBJECT

public:
    // ── Browser state (exposed to QML via browserState property) ──
    // Matches the scraper daemon lifecycle states.
    enum BrowserState {
        Offline      = 0,   // Process not running
        Starting     = 1,   // Process launched, waiting for {"type":"ready"}
        Ready        = 2,   // Browser alive and on My Store page
        Busy         = 3,   // A scrape or calibrate is in progress
        Restarting   = 4,   // restartBrowser() in progress
        Error        = 5    // Process exited unexpectedly
    };
    Q_ENUM(BrowserState)

    // ── QML-bindable properties ────────────────────────────────
    Q_PROPERTY(int     browserState READ browserStateInt NOTIFY browserStateChanged)
    Q_PROPERTY(QString statusText   READ statusText      NOTIFY statusTextChanged)
    Q_PROPERTY(bool    busy         READ busy            NOTIFY busyChanged)

    explicit ScraperService(QObject* parent = nullptr);
    ~ScraperService() override;

    // ── Property readers ──────────────────────────────────────
    int     browserStateInt() const { return static_cast<int>(m_state); }
    BrowserState browserState() const { return m_state; }
    QString statusText() const { return m_statusText; }
    bool    busy()       const { return m_state == Busy; }

    // ── Configuration (set before first call) ─────────────────

    // Full path to scraper.exe.  Defaults to "<appDir>/scraper/dist/scraper.exe"
    void setScraperExe(const QString& path);

    // Milliseconds to wait for {"type":"ready"} after launching (default: 120 000)
    void setStartupTimeoutMs(int ms);

    // Milliseconds to wait for a scrape result before killing the process (default: 120 000)
    void setScrapeTimeoutMs(int ms);

    // ── Main API (all Q_INVOKABLE for QML) ───────────────────

    // Start the browser daemon.
    //   accountName = "" → --manual-login (user types credentials in browser)
    //   accountName = "子午計畫" → reads from encrypted account store
    Q_INVOKABLE void startBrowser(const QString& accountName = QString());
    Q_INVOKABLE void startBrowserWithCredentials(const QString& accountName,
                                                 const QString& loginAccount,
                                                 const QString& password);
    Q_INVOKABLE void startConfiguredBrowser();

    // Kill any running daemon and start a fresh one.
    // Safe to call at any time — will not crash the Qt app.
    Q_INVOKABLE void restartBrowser(const QString& accountName = QString());
    Q_INVOKABLE void restartBrowserWithCredentials(const QString& accountName,
                                                   const QString& loginAccount,
                                                   const QString& password);
    Q_INVOKABLE void restartConfiguredBrowser();

    // Send {"cmd":"calibrate"} to the running daemon.
    // Closes extra tabs, returns to My Store page.
    // No-op if not in Ready or Busy state.
    Q_INVOKABLE void calibrate();

    // Send a scrape command for one order to the running daemon.
    //   orderId     = UUID from OrdersRepository (returned in scraperFinished signal)
    //   orderNumber = e.g. "PG02412345"
    // No-op if browser is not Ready. Emits scraperFailed if daemon is not running.
    Q_INVOKABLE void scrape(const QString& orderId, const QString& orderNumber);

    // Kill the daemon process immediately (e.g. when app is quitting).
    Q_INVOKABLE void cancel();

signals:
    // ── Browser lifecycle signals ─────────────────────────────
    void browserReady();                 // Browser is on My Store, ready for orders
    void browserDied(const QString& reason); // Unexpected process exit

    // ── Scrape result signals ─────────────────────────────────
    // Emitted when a scrape_result event arrives from the daemon.
    void scraperFinished(const QString& orderId, const ScraperResult& result);

    // Emitted on timeout or process crash during a scrape.
    void scraperFailed(const QString& orderId, const QString& reason);

    // ── Property-change signals ────────────────────────────────
    void browserStateChanged();
    void statusTextChanged();
    void busyChanged();

private slots:
    void onReadyReadStdout();
    void onReadyReadStderr();
    void onFinished(int exitCode, QProcess::ExitStatus status);
    void onErrorOccurred(QProcess::ProcessError error);
    void onStartupTimeout();
    void onScrapeTimeout();

private:
    void launchBrowser(const QString& accountName,
                       const QString& loginAccount,
                       const QString& password,
                       bool manualLogin);
    void clearTimers();

    // Parse a single JSON event line received from the daemon stdout.
    void handleEvent(const QByteArray& line);

    // Set state + statusText together, emit both changed signals.
    void setState(BrowserState s, const QString& text);

    // Kill process, clear pointers/timers. Does NOT emit signals.
    void killProcess();

    // Write a JSON command to the daemon's stdin.
    void sendCommand(const QByteArray& jsonLine);

    QProcess* m_process         = nullptr;
    QTimer*   m_startupTimer    = nullptr;   // Guards {"type":"ready"} arrival
    QTimer*   m_scrapeTimer     = nullptr;   // Guards scrape completion

    BrowserState m_state        = Offline;
    QString      m_statusText   = QStringLiteral("未啟動");

    QString      m_pendingAccount;           // Account name for current/next startBrowser
    QString      m_pendingLoginAccount;
    QString      m_pendingPassword;
    QString      m_currentOrderId;          // orderId of the in-flight scrape
    QByteArray   m_stdoutBuf;               // Accumulates partial stdout lines
    bool         m_expectedShutdown = false;
    QString      m_lastDaemonError;
    bool         m_preferAutoLogin = false;
    QString      m_preferredAccountName;
    QString      m_preferredLoginAccount;
    QString      m_preferredPassword;

    // ── Executable discovery (set once in constructor) ────────────────
    // Production: m_scraperExe is the path to scraper.exe
    // Dev mode:   m_devMode=true, m_devPythonExe is .venv python,
    //             m_devWorkingDir is the scraper source root, and
    //             m_scraperExe is unused.
    QString      m_scraperExe;
    bool         m_devMode       = false;    // true when running from Python source
    QString      m_devPythonExe;             // .venv/Scripts/python.exe
    QString      m_devWorkingDir;            // scraper/ source directory

    int          m_startupTimeoutMs = 180'000;  // 3 min (includes manual login wait)
    int          m_scrapeTimeoutMs  = 120'000;  // 2 min per order

public:
    void setPreferredLoginMode(bool autoLoginEnabled,
                               const QString& accountName,
                               const QString& loginAccount,
                               const QString& password);
};
