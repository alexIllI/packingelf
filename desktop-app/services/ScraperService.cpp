// ─────────────────────────────────────────────────────────────
// ScraperService.cpp
// See ScraperService.h for full architecture notes.
// ─────────────────────────────────────────────────────────────
#include "ScraperService.h"

#include <QCoreApplication>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

// ─────────────────────────────────────────────────────────────
// ScraperResult helpers
// ─────────────────────────────────────────────────────────────

bool ScraperResult::isSuccess() const
{
    return status == QStringLiteral("SUCCESS");
}

ScraperResult ScraperResult::fromJson(const QByteArray& jsonLine)
{
    ScraperResult r;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(jsonLine.trimmed(), &err);

    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        r.status  = QStringLiteral("ERROR");
        r.message = QStringLiteral("Invalid JSON: ") + err.errorString()
                    + QStringLiteral(" | raw: ") + QString::fromUtf8(jsonLine.left(200));
        return r;
    }

    const QJsonObject obj = doc.object();
    r.status      = obj.value(QStringLiteral("status")).toString();
    r.buyerName   = obj.value(QStringLiteral("buyer_name")).toString();
    r.orderDate   = obj.value(QStringLiteral("order_date")).toString();
    r.usingCoupon = obj.value(QStringLiteral("using_coupon")).toBool(false);
    r.message     = obj.value(QStringLiteral("message")).toString();
    return r;
}

// ─────────────────────────────────────────────────────────────
// ScraperService
// ─────────────────────────────────────────────────────────────

ScraperService::ScraperService(QObject* parent)
    : QObject(parent)
{
    // Default: look for scraper.exe next to the Qt app executable
    const QString appDir = QCoreApplication::applicationDirPath();
    m_scraperExe = QDir(appDir).filePath(
        QStringLiteral("scraper/dist/scraper.exe"));
}

ScraperService::~ScraperService()
{
    // Kill any running process cleanly before we disappear
    cancel();
}

// ─── Configuration ────────────────────────────────────────────

void ScraperService::setScraperExe(const QString& path)
{
    m_scraperExe = path;
}

void ScraperService::setStartupTimeoutMs(int ms)
{
    m_startupTimeoutMs = ms;
}

void ScraperService::setScrapeTimeoutMs(int ms)
{
    m_scrapeTimeoutMs = ms;
}

// ─── Private helpers ──────────────────────────────────────────

void ScraperService::setState(BrowserState s, const QString& text)
{
    const bool wasBusy = busy();
    m_state      = s;
    m_statusText = text;
    emit browserStateChanged();
    emit statusTextChanged();
    if (busy() != wasBusy)
        emit busyChanged();
}

void ScraperService::sendCommand(const QByteArray& jsonLine)
{
    if (!m_process || m_process->state() != QProcess::Running) {
        qWarning() << "[ScraperService] sendCommand called but process not running";
        return;
    }
    const QByteArray line = jsonLine.trimmed() + '\n';
    m_process->write(line);
}

void ScraperService::killProcess()
{
    if (m_startupTimer) {
        m_startupTimer->stop();
        m_startupTimer->deleteLater();
        m_startupTimer = nullptr;
    }
    if (m_scrapeTimer) {
        m_scrapeTimer->stop();
        m_scrapeTimer->deleteLater();
        m_scrapeTimer = nullptr;
    }
    if (m_process) {
        // Try graceful quit first; fall back to kill
        m_process->write("{\"cmd\":\"quit\"}\n");
        if (!m_process->waitForFinished(2'000))
            m_process->kill();
        m_process->waitForFinished(1'000);
        m_process->deleteLater();
        m_process = nullptr;
    }
    m_currentOrderId.clear();
    m_stdoutBuf.clear();
}

// ─── Public API ───────────────────────────────────────────────

void ScraperService::startBrowser(const QString& accountName)
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        qWarning() << "[ScraperService] startBrowser called while already running — ignoring";
        return;
    }

    m_pendingAccount = accountName;
    m_stdoutBuf.clear();

    // Build argument list: scraper.exe daemon --account X  |or|  --manual-login
    QStringList args;
    args << QStringLiteral("daemon");

    if (accountName.isEmpty()) {
        args << QStringLiteral("--manual-login");
        qInfo() << "[ScraperService] Starting browser daemon in manual-login mode";
    } else {
        args << QStringLiteral("--account") << accountName;
        qInfo() << "[ScraperService] Starting browser daemon with account:" << accountName;
    }

    m_process = new QProcess(this);
    m_process->setProgram(m_scraperExe);
    m_process->setArguments(args);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    // stdout → line-buffered JSON event parser
    connect(m_process, &QProcess::readyReadStandardOutput,
            this,      &ScraperService::onReadyReadStdout);

    // stderr → forward to qDebug() (step-by-step logs)
    connect(m_process, &QProcess::readyReadStandardError,
            this,      &ScraperService::onReadyReadStderr);

    connect(m_process, &QProcess::finished,
            this,      &ScraperService::onFinished);
    connect(m_process, &QProcess::errorOccurred,
            this,      &ScraperService::onErrorOccurred);

    // Timeout guard: if {"type":"ready"} doesn't arrive within limit, kill process
    m_startupTimer = new QTimer(this);
    m_startupTimer->setSingleShot(true);
    connect(m_startupTimer, &QTimer::timeout,
            this,           &ScraperService::onStartupTimeout);
    m_startupTimer->start(m_startupTimeoutMs);

    setState(Starting, QStringLiteral("正在啟動瀏覽器…"));

    m_process->start();

    if (!m_process->waitForStarted(5'000)) {
        qCritical() << "[ScraperService] Failed to start process:" << m_process->errorString();
        const QString reason = QStringLiteral("無法啟動爬蟲程式: ") + m_process->errorString();
        killProcess();
        setState(Error, reason);
        emit browserDied(reason);
    } else {
        qInfo() << "[ScraperService] Daemon PID:" << m_process->processId();
    }
}

void ScraperService::restartBrowser(const QString& accountName)
{
    qInfo() << "[ScraperService] restartBrowser() called";
    setState(Restarting, QStringLiteral("正在重新啟動瀏覽器…"));

    // If a scrape was in flight, notify failure
    if (!m_currentOrderId.isEmpty()) {
        const QString id = m_currentOrderId;
        m_currentOrderId.clear();
        emit scraperFailed(id, QStringLiteral("Browser restarted by user"));
    }

    killProcess();  // Clean kill of old process
    startBrowser(accountName.isEmpty() ? m_pendingAccount : accountName);
}

void ScraperService::calibrate()
{
    if (m_state == Offline || m_state == Starting || m_state == Restarting) {
        qWarning() << "[ScraperService] calibrate() ignored — browser not ready";
        return;
    }

    setState(Busy, QStringLiteral("校正中…"));
    sendCommand(R"({"cmd":"calibrate"})");
}

void ScraperService::scrape(const QString& orderId, const QString& orderNumber)
{
    if (m_state != Ready) {
        const QString reason = (m_state == Offline || m_state == Error)
            ? QStringLiteral("瀏覽器未啟動，請先點擊「重新啟動」")
            : QStringLiteral("瀏覽器正忙，請稍後再試");
        qWarning() << "[ScraperService] scrape() called but not Ready:"
                   << m_statusText;
        emit scraperFailed(orderId, reason);
        return;
    }

    m_currentOrderId = orderId;
    setState(Busy, QStringLiteral("搜尋貨單 %1…").arg(orderNumber));

    // Build {"cmd":"scrape","order_id":"...","order_number":"..."}\n
    const QJsonObject obj{
        { QStringLiteral("cmd"),          QStringLiteral("scrape") },
        { QStringLiteral("order_id"),     orderId },
        { QStringLiteral("order_number"), orderNumber },
    };
    sendCommand(QJsonDocument(obj).toJson(QJsonDocument::Compact));

    // Timeout watchdog for scrape
    m_scrapeTimer = new QTimer(this);
    m_scrapeTimer->setSingleShot(true);
    connect(m_scrapeTimer, &QTimer::timeout,
            this,          &ScraperService::onScrapeTimeout);
    m_scrapeTimer->start(m_scrapeTimeoutMs);

    qInfo() << "[ScraperService] Scrape started for order" << orderNumber;
}

void ScraperService::cancel()
{
    if (!m_process) return;
    qInfo() << "[ScraperService] cancel() — killing daemon process";

    if (!m_currentOrderId.isEmpty()) {
        const QString id = m_currentOrderId;
        m_currentOrderId.clear();
        emit scraperFailed(id, QStringLiteral("Cancelled by user"));
    }

    killProcess();
    setState(Offline, QStringLiteral("已停止"));
}

// ─── Private slots ────────────────────────────────────────────

void ScraperService::onReadyReadStdout()
{
    m_stdoutBuf.append(m_process->readAllStandardOutput());

    // Parse every complete line (lines terminated by '\n')
    int newlineIdx;
    while ((newlineIdx = m_stdoutBuf.indexOf('\n')) != -1) {
        const QByteArray line = m_stdoutBuf.left(newlineIdx).trimmed();
        m_stdoutBuf.remove(0, newlineIdx + 1);
        if (!line.isEmpty())
            handleEvent(line);
    }
}

void ScraperService::onReadyReadStderr()
{
    const QByteArray err = m_process->readAllStandardError();
    for (const QByteArray& line : err.split('\n')) {
        if (!line.trimmed().isEmpty())
            qDebug().noquote() << "[scraper]" << QString::fromUtf8(line);
    }
}

void ScraperService::handleEvent(const QByteArray& line)
{
    QJsonParseError parseErr;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &parseErr);

    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[ScraperService] Bad JSON from daemon:" << line.left(200);
        return;
    }

    const QJsonObject obj  = doc.object();
    const QString     type = obj.value(QStringLiteral("type")).toString();

    if (type == QStringLiteral("ready")) {
        // Browser logged in and on My Store page
        if (m_startupTimer) {
            m_startupTimer->stop();
            m_startupTimer->deleteLater();
            m_startupTimer = nullptr;
        }
        setState(Ready, QStringLiteral("瀏覽器就緒"));
        emit browserReady();
        qInfo() << "[ScraperService] Browser daemon ready.";

    } else if (type == QStringLiteral("scrape_result")) {
        if (m_scrapeTimer) {
            m_scrapeTimer->stop();
            m_scrapeTimer->deleteLater();
            m_scrapeTimer = nullptr;
        }

        const QString orderId = obj.value(QStringLiteral("order_id")).toString();
        const ScraperResult result = ScraperResult::fromJson(line);

        setState(Ready, QStringLiteral("瀏覽器就緒"));
        m_currentOrderId.clear();

        qInfo() << "[ScraperService] Scrape result for order" << orderId
                << "→" << result.status;
        emit scraperFinished(orderId, result);

    } else if (type == QStringLiteral("calibrate_result")) {
        const bool ok  = obj.value(QStringLiteral("ok")).toBool();
        const QString msg = obj.value(QStringLiteral("message")).toString();
        setState(Ready, ok ? QStringLiteral("校正完成") : QStringLiteral("校正失敗"));
        qInfo() << "[ScraperService] Calibrate result: ok=" << ok << msg;

    } else if (type == QStringLiteral("pong")) {
        qDebug() << "[ScraperService] pong received";

    } else if (type == QStringLiteral("error")) {
        const QString msg = obj.value(QStringLiteral("msg")).toString();
        qWarning() << "[ScraperService] Daemon error event:" << msg;
        // If we're expecting a scrape result, fail it
        if (!m_currentOrderId.isEmpty()) {
            const QString id = m_currentOrderId;
            m_currentOrderId.clear();
            if (m_scrapeTimer) { m_scrapeTimer->stop(); m_scrapeTimer->deleteLater(); m_scrapeTimer = nullptr; }
            setState(Ready, QStringLiteral("瀏覽器就緒 (上次發生錯誤)"));
            emit scraperFailed(id, msg);
        }
    } else {
        qWarning() << "[ScraperService] Unknown event type:" << type;
    }
}

void ScraperService::onFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    // Flush any remaining stdout
    if (m_process)
        onReadyReadStdout();

    qWarning() << "[ScraperService] Daemon process exited. code=" << exitCode
               << "status=" << exitStatus;

    const QString reason = exitStatus == QProcess::CrashExit
        ? QStringLiteral("瀏覽器程序崩潰")
        : QStringLiteral("瀏覽器程序已結束 (code=%1)").arg(exitCode);

    // If a scrape was in flight, fail it
    if (!m_currentOrderId.isEmpty()) {
        const QString id = m_currentOrderId;
        m_currentOrderId.clear();
        emit scraperFailed(id, reason);
    }

    killProcess();

    // Only update state if we're not already in Restarting
    // (restartBrowser() calls killProcess then startBrowser, so we skip this)
    if (m_state != Restarting) {
        setState(Offline, QStringLiteral("瀏覽器已關閉"));
        emit browserDied(reason);
    }
}

void ScraperService::onErrorOccurred(QProcess::ProcessError error)
{
    // Only handle FailedToStart here — other errors also fire onFinished.
    if (error == QProcess::FailedToStart) {
        const QString reason = QStringLiteral("找不到爬蟲程式或無法執行: ") + m_scraperExe;
        qCritical() << "[ScraperService]" << reason;

        if (!m_currentOrderId.isEmpty()) {
            const QString id = m_currentOrderId;
            m_currentOrderId.clear();
            emit scraperFailed(id, reason);
        }

        killProcess();
        setState(Error, reason);
        emit browserDied(reason);
    }
}

void ScraperService::onStartupTimeout()
{
    qWarning() << "[ScraperService] Startup timed out — killing process";
    const QString reason = QStringLiteral("啟動逾時：瀏覽器未能在時限內就緒");
    killProcess();
    setState(Error, reason);
    emit browserDied(reason);
}

void ScraperService::onScrapeTimeout()
{
    qWarning() << "[ScraperService] Scrape timed out for order" << m_currentOrderId;
    const QString id = m_currentOrderId;
    // Don't kill the whole daemon — just report a timeout.
    // The browser may still be usable after the page times out.
    m_currentOrderId.clear();
    m_scrapeTimer = nullptr;  // Already fired, will be deleted by Qt ownership
    setState(Ready, QStringLiteral("瀏覽器就緒 (上次逾時)"));
    emit scraperFailed(id, QStringLiteral("TIMEOUT: 爬蟲超過最大等待時間"));
}
