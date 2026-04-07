// ─────────────────────────────────────────────────────────────
// ScraperService.cpp
// See ScraperService.h for the full architecture notes.
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
        r.message = QStringLiteral("Invalid JSON from scraper: ") + err.errorString()
                    + QStringLiteral(" | raw: ") + QString::fromUtf8(jsonLine);
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
    // Default scraper path: <app dir>/scraper/dist/scraper.exe
    const QString appDir = QCoreApplication::applicationDirPath();
    m_scraperExe = QDir(appDir).filePath(
        QStringLiteral("scraper/dist/scraper.exe"));
}

ScraperService::~ScraperService()
{
    cancel();  // Kill any running process before we disappear
}

// ─── Configuration ────────────────────────────────────────────

void ScraperService::setScraperExe(const QString& path)
{
    m_scraperExe = path;
}

void ScraperService::setTimeoutMs(int ms)
{
    m_timeoutMs = ms;
}

// ─── Public API ───────────────────────────────────────────────

bool ScraperService::busy() const
{
    return m_process && m_process->state() != QProcess::NotRunning;
}

void ScraperService::scrape(const QString& orderId,
                            const QString& orderNumber,
                            const QString& accountName)
{
    if (busy()) {
        qWarning() << "[ScraperService] Already busy; ignoring scrape request for" << orderId;
        return;
    }

    // ── Build argument list ────────────────────────────────────
    // Matches the CLI:
    //   scraper.exe scrape --order <num> --account <name>
    //   scraper.exe scrape --order <num> --manual-login
    QStringList args;
    args << QStringLiteral("scrape")
         << QStringLiteral("--order") << orderNumber;

    if (accountName.isEmpty()) {
        args << QStringLiteral("--manual-login");
        qInfo() << "[ScraperService] Launching scraper in manual-login mode for order" << orderNumber;
    } else {
        args << QStringLiteral("--account") << accountName;
        qInfo() << "[ScraperService] Launching scraper for order" << orderNumber
                << "with account" << accountName;
    }

    // ── Set up QProcess ───────────────────────────────────────
    m_currentOrderId = orderId;
    m_stdoutBuf.clear();

    m_process = new QProcess(this);
    m_process->setProgram(m_scraperExe);
    m_process->setArguments(args);

    // Merge channels: we want stdout and stderr separately.
    // stdout  → JSON result we parse
    // stderr  → verbose progress log we forward to qDebug
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(m_process, &QProcess::finished,
            this,      &ScraperService::onFinished);
    connect(m_process, &QProcess::errorOccurred,
            this,      &ScraperService::onErrorOccurred);

    // Forward stderr lines to Qt debug output so they appear in IDE log
    connect(m_process, &QProcess::readyReadStandardError, this, [this]() {
        const QByteArray errOutput = m_process->readAllStandardError();
        // Print each stderr line from the scraper to the Qt debug log
        for (const QByteArray& line : errOutput.split('\n')) {
            if (!line.trimmed().isEmpty())
                qDebug().noquote() << "[scraper]" << QString::fromUtf8(line);
        }
    });

    // Buffer stdout (the JSON result line)
    connect(m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        m_stdoutBuf.append(m_process->readAllStandardOutput());
    });

    // ── Timeout watchdog ──────────────────────────────────────
    m_timer = new QTimer(this);
    m_timer->setSingleShot(true);
    connect(m_timer, &QTimer::timeout, this, &ScraperService::onTimeout);
    m_timer->start(m_timeoutMs);

    // ── Start the process ─────────────────────────────────────
    m_process->start();

    if (!m_process->waitForStarted(5'000)) {
        qCritical() << "[ScraperService] Failed to start scraper process:"
                    << m_process->errorString();
        const QString reason = QStringLiteral("Process failed to start: ")
                               + m_process->errorString();
        cleanup();
        emit scraperFailed(orderId, reason);
        emit busyChanged();
    } else {
        qInfo() << "[ScraperService] Scraper process started. PID:" << m_process->processId();
        emit busyChanged();
    }
}

void ScraperService::cancel()
{
    if (!m_process) return;
    qInfo() << "[ScraperService] Cancelling scraper process…";
    m_process->kill();
    m_process->waitForFinished(3'000);
    cleanup();
    emit busyChanged();
}

// ─── Private slots ────────────────────────────────────────────

void ScraperService::onFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (m_timer) m_timer->stop();

    // Read any remaining stdout that hasn't been buffered yet
    m_stdoutBuf.append(m_process->readAllStandardOutput());

    const QString orderId = m_currentOrderId;

    if (exitStatus == QProcess::CrashExit) {
        qWarning() << "[ScraperService] Scraper process CRASHED for order" << orderId;
        cleanup();
        emit scraperFailed(orderId, QStringLiteral("Scraper process crashed"));
        emit busyChanged();
        return;
    }

    if (exitCode != 0) {
        qWarning() << "[ScraperService] Scraper exited with code" << exitCode
                   << "for order" << orderId;
    }

    // Find the last non-empty line of stdout (the JSON result)
    QByteArray jsonLine;
    for (const QByteArray& line : m_stdoutBuf.split('\n')) {
        if (!line.trimmed().isEmpty())
            jsonLine = line;
    }

    if (jsonLine.isEmpty()) {
        qWarning() << "[ScraperService] No JSON output from scraper for order" << orderId;
        cleanup();
        emit scraperFailed(orderId, QStringLiteral("No output from scraper process"));
        emit busyChanged();
        return;
    }

    const ScraperResult result = ScraperResult::fromJson(jsonLine);
    qInfo() << "[ScraperService] Order" << orderId << "→ status:" << result.status;

    cleanup();
    emit scraperFinished(orderId, result);
    emit busyChanged();
}

void ScraperService::onErrorOccurred(QProcess::ProcessError error)
{
    // onFinished will also fire (with CrashExit) for most errors,
    // so we only handle FailedToStart here (onFinished won't fire then).
    if (error == QProcess::FailedToStart) {
        if (m_timer) m_timer->stop();
        const QString reason = QStringLiteral("Scraper executable not found or permission denied: ")
                               + m_scraperExe;
        qCritical() << "[ScraperService]" << reason;
        const QString orderId = m_currentOrderId;
        cleanup();
        emit scraperFailed(orderId, reason);
        emit busyChanged();
    }
}

void ScraperService::onTimeout()
{
    qWarning() << "[ScraperService] Scraper timed out for order" << m_currentOrderId
               << "— killing process.";
    m_process->kill();
    // onFinished will fire with CrashExit; we emit scraperFailed from there.
    // But we also want a clear TIMEOUT reason, so emit now and guard in onFinished.
    const QString orderId = m_currentOrderId;
    // cleanup() is called in onFinished; don't double-delete here.
    emit scraperFailed(orderId, QStringLiteral("TIMEOUT: scraper exceeded time limit"));
    emit busyChanged();
}

// ─── Cleanup ──────────────────────────────────────────────────

void ScraperService::cleanup()
{
    if (m_timer) {
        m_timer->stop();
        m_timer->deleteLater();
        m_timer = nullptr;
    }
    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }
    m_currentOrderId.clear();
    m_stdoutBuf.clear();
}
