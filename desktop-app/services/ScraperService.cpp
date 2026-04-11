#include "ScraperService.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>

bool ScraperResult::isSuccess() const {
  return status == QStringLiteral("SUCCESS") ||
         status == QStringLiteral("ORDER_CANCELED") ||
         status == QStringLiteral("STORE_CLOSED");
}

ScraperResult ScraperResult::fromJson(const QByteArray &jsonLine) {
  ScraperResult result;

  QJsonParseError err;
  const QJsonDocument doc = QJsonDocument::fromJson(jsonLine.trimmed(), &err);
  if (err.error != QJsonParseError::NoError || !doc.isObject()) {
    result.status = QStringLiteral("ERROR");
    result.message = QStringLiteral("Invalid JSON: ") + err.errorString() +
                     QStringLiteral(" | raw: ") +
                     QString::fromUtf8(jsonLine.left(200));
    return result;
  }

  const QJsonObject obj = doc.object();
  result.status = obj.value(QStringLiteral("status")).toString();
  result.buyerName = obj.value(QStringLiteral("buyer_name")).toString();
  result.orderDate = obj.value(QStringLiteral("order_date")).toString();
  result.usingCoupon = obj.value(QStringLiteral("using_coupon")).toBool(false);
  result.message = obj.value(QStringLiteral("message")).toString();
  return result;
}

ScraperService::ScraperService(QObject *parent) : QObject(parent) {
  const QString appDir = QCoreApplication::applicationDirPath();

  m_scraperExe =
      QDir(appDir).filePath(QStringLiteral("scraper/dist/scraper.exe"));
  if (QFileInfo::exists(m_scraperExe)) {
    qInfo() << "[ScraperService] Production mode: using" << m_scraperExe;
    return;
  }

  QDir dir(appDir);
  for (int i = 0; i < 7; ++i) {
    const QString python =
        dir.filePath(QStringLiteral("scraper/.venv/Scripts/python.exe"));
    if (QFileInfo::exists(python)) {
      m_devMode = true;
      m_devPythonExe = python;
      m_devWorkingDir =
          QDir::cleanPath(dir.filePath(QStringLiteral("scraper")));
      qInfo() << "[ScraperService] Dev mode: Python at" << m_devPythonExe;
      qInfo() << "[ScraperService] Dev mode: working dir" << m_devWorkingDir;
      return;
    }

    if (!dir.cdUp())
      break;
  }

  qWarning()
      << "[ScraperService] scraper.exe not found and dev .venv not found";
  qWarning()
      << "[ScraperService] Run scraper/build.ps1 or ensure .venv exists.";
}

ScraperService::~ScraperService() { cancel(); }

void ScraperService::setScraperExe(const QString &path) { m_scraperExe = path; }

void ScraperService::setStartupTimeoutMs(int ms) { m_startupTimeoutMs = ms; }

void ScraperService::setScrapeTimeoutMs(int ms) { m_scrapeTimeoutMs = ms; }

void ScraperService::setState(BrowserState s, const QString &text) {
  const bool wasBusy = busy();
  m_state = s;
  m_statusText = text;
  emit browserStateChanged();
  emit statusTextChanged();
  if (busy() != wasBusy)
    emit busyChanged();
}

void ScraperService::sendCommand(const QByteArray &jsonLine) {
  if (!m_process || m_process->state() != QProcess::Running) {
    qWarning() << "[ScraperService] sendCommand called but process not running";
    return;
  }

  const QByteArray line = jsonLine.trimmed() + '\n';
  m_process->write(line);
}

void ScraperService::clearTimers() {
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
}

void ScraperService::killProcess() {
  clearTimers();

  if (m_process) {
    QProcess *process = m_process;
    m_process = nullptr;

    disconnect(process, nullptr, this, nullptr);

    if (process->state() == QProcess::Running) {
      process->write("{\"cmd\":\"quit\"}\n");
      if (!process->waitForFinished(2'000))
        process->kill();
      process->waitForFinished(1'000);
    }

    process->deleteLater();
  }

  m_currentOrderId.clear();
  m_stdoutBuf.clear();
}

void ScraperService::setPreferredLoginMode(bool autoLoginEnabled,
                                           const QString &accountName,
                                           const QString &loginAccount,
                                           const QString &password) {
  m_preferAutoLogin = autoLoginEnabled && !accountName.trimmed().isEmpty() &&
                      !loginAccount.trimmed().isEmpty() && !password.isEmpty();
  m_preferredAccountName = accountName.trimmed();
  m_preferredLoginAccount = loginAccount.trimmed();
  m_preferredPassword = password;
}

void ScraperService::startBrowser(const QString &accountName) {
  launchBrowser(accountName, QString(), QString(), accountName.isEmpty());
}

void ScraperService::startBrowserWithCredentials(const QString &accountName,
                                                 const QString &loginAccount,
                                                 const QString &password) {
  launchBrowser(accountName, loginAccount, password, false);
}

void ScraperService::startConfiguredBrowser() {
  if (m_preferAutoLogin) {
    startBrowserWithCredentials(m_preferredAccountName, m_preferredLoginAccount,
                                m_preferredPassword);
    return;
  }

  startBrowser(QString());
}

void ScraperService::launchBrowser(const QString &accountName,
                                   const QString &loginAccount,
                                   const QString &password, bool manualLogin) {
  if (m_process && m_process->state() != QProcess::NotRunning) {
    qWarning() << "[ScraperService] startBrowser called while already running "
                  "-- ignoring";
    return;
  }

  m_pendingAccount = accountName.trimmed();
  m_pendingLoginAccount = loginAccount.trimmed();
  m_pendingPassword = password;
  m_lastDaemonError.clear();
  m_stdoutBuf.clear();
  m_expectedShutdown = false;

  QStringList args;
  args << QStringLiteral("daemon");

  if (manualLogin || m_pendingLoginAccount.isEmpty() ||
      m_pendingPassword.isEmpty()) {
    m_pendingAccount.clear();
    m_pendingLoginAccount.clear();
    m_pendingPassword.clear();
    args << QStringLiteral("--manual-login");
    qInfo() << "[ScraperService] Starting browser daemon in manual-login mode";
  } else {
    args << QStringLiteral("--direct-login");
    if (!m_pendingAccount.isEmpty())
      args << QStringLiteral("--account-label") << m_pendingAccount;
    qInfo()
        << "[ScraperService] Starting browser daemon with configured account:"
        << m_pendingAccount;
  }

  m_process = new QProcess(this);
  QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
  env.insert(QStringLiteral("PYTHONUTF8"), QStringLiteral("1"));
  env.insert(QStringLiteral("PYTHONIOENCODING"), QStringLiteral("utf-8"));
  if (!m_pendingLoginAccount.isEmpty()) {
    env.insert(QStringLiteral("PACKINGELF_MYACG_LOGIN"), m_pendingLoginAccount);
    env.insert(QStringLiteral("PACKINGELF_MYACG_PASSWORD"), m_pendingPassword);
  } else {
    env.remove(QStringLiteral("PACKINGELF_MYACG_LOGIN"));
    env.remove(QStringLiteral("PACKINGELF_MYACG_PASSWORD"));
  }
  m_process->setProcessEnvironment(env);

  if (m_devMode) {
    m_process->setProgram(m_devPythonExe);
    m_process->setWorkingDirectory(m_devWorkingDir);
    QStringList pythonArgs;
    pythonArgs << QStringLiteral("-u") << QStringLiteral("-m")
               << QStringLiteral("src");
    pythonArgs << args;
    m_process->setArguments(pythonArgs);
    qInfo() << "[ScraperService] Dev cmd:" << m_devPythonExe
            << pythonArgs.join(" ");
  } else {
    m_process->setProgram(m_scraperExe);
    m_process->setArguments(args);
  }

  m_process->setProcessChannelMode(QProcess::SeparateChannels);
  connect(m_process, &QProcess::readyReadStandardOutput, this,
          &ScraperService::onReadyReadStdout);
  connect(m_process, &QProcess::readyReadStandardError, this,
          &ScraperService::onReadyReadStderr);
  connect(m_process, &QProcess::finished, this, &ScraperService::onFinished);
  connect(m_process, &QProcess::errorOccurred, this,
          &ScraperService::onErrorOccurred);

  m_startupTimer = new QTimer(this);
  m_startupTimer->setSingleShot(true);
  connect(m_startupTimer, &QTimer::timeout, this,
          &ScraperService::onStartupTimeout);
  m_startupTimer->start(m_startupTimeoutMs);

  setState(Starting, QStringLiteral("正在啟動瀏覽器..."));
  m_process->start();

  if (!m_process->waitForStarted(5'000)) {
    qCritical() << "[ScraperService] Failed to start process:"
                << m_process->errorString();
    const QString reason =
        QStringLiteral("無法啟動瀏覽器程序: ") + m_process->errorString();
    killProcess();
    setState(Error, reason);
    emit browserDied(reason);
    return;
  }

  qInfo() << "[ScraperService] Daemon PID:" << m_process->processId();
}

void ScraperService::restartBrowser(const QString &accountName) {
  qInfo() << "[ScraperService] restartBrowser() called";
  setState(Restarting, QStringLiteral("正在重新啟動瀏覽器..."));
  m_expectedShutdown = true;

  if (!m_currentOrderId.isEmpty()) {
    const QString id = m_currentOrderId;
    m_currentOrderId.clear();
    emit scraperFailed(id, QStringLiteral("Browser restarted by user"));
  }

  killProcess();
  startBrowser(accountName.isEmpty() ? m_pendingAccount : accountName);
}

void ScraperService::restartBrowserWithCredentials(const QString &accountName,
                                                   const QString &loginAccount,
                                                   const QString &password) {
  qInfo() << "[ScraperService] restartBrowserWithCredentials() called";
  setState(Restarting, QStringLiteral("正在重新啟動瀏覽器..."));
  m_expectedShutdown = true;

  if (!m_currentOrderId.isEmpty()) {
    const QString id = m_currentOrderId;
    m_currentOrderId.clear();
    emit scraperFailed(id, QStringLiteral("Browser restarted by user"));
  }

  killProcess();
  startBrowserWithCredentials(accountName, loginAccount, password);
}

void ScraperService::restartConfiguredBrowser() {
  if (m_preferAutoLogin) {
    restartBrowserWithCredentials(m_preferredAccountName,
                                  m_preferredLoginAccount, m_preferredPassword);
    return;
  }

  restartBrowser(QString());
}

void ScraperService::calibrate() {
  if (m_state == Offline || m_state == Starting || m_state == Restarting) {
    qWarning() << "[ScraperService] calibrate() ignored -- browser not ready";
    return;
  }

  setState(Busy, QStringLiteral("校正中..."));
  sendCommand(R"({"cmd":"calibrate"})");
}

void ScraperService::scrape(const QString &orderId,
                            const QString &orderNumber) {
  if (m_state != Ready) {
    const QString reason =
        (m_state == Offline || m_state == Error)
            ? QStringLiteral("瀏覽器尚未就緒，請先啟動或重新登入。")
            : QStringLiteral("瀏覽器忙碌中，請稍後再試。");
    qWarning() << "[ScraperService] scrape() called but not Ready:"
               << m_statusText;
    emit scraperFailed(orderId, reason);
    return;
  }

  m_currentOrderId = orderId;
  setState(Busy, QStringLiteral("搜尋貨單 %1...").arg(orderNumber));

  const QJsonObject obj{
      {QStringLiteral("cmd"), QStringLiteral("scrape")},
      {QStringLiteral("order_id"), orderId},
      {QStringLiteral("order_number"), orderNumber},
  };
  sendCommand(QJsonDocument(obj).toJson(QJsonDocument::Compact));

  m_scrapeTimer = new QTimer(this);
  m_scrapeTimer->setSingleShot(true);
  connect(m_scrapeTimer, &QTimer::timeout, this,
          &ScraperService::onScrapeTimeout);
  m_scrapeTimer->start(m_scrapeTimeoutMs);

  qInfo() << "[ScraperService] Scrape started for order" << orderNumber;
}

void ScraperService::cancel() {
  if (!m_process)
    return;

  m_expectedShutdown = true;
  qInfo() << "[ScraperService] cancel() -- killing daemon process";

  if (!m_currentOrderId.isEmpty()) {
    const QString id = m_currentOrderId;
    m_currentOrderId.clear();
    emit scraperFailed(id, QStringLiteral("Cancelled by user"));
  }

  killProcess();
  setState(Offline, QStringLiteral("已停止瀏覽器"));
}

void ScraperService::onReadyReadStdout() {
  m_stdoutBuf.append(m_process->readAllStandardOutput());

  int newlineIdx = -1;
  while ((newlineIdx = m_stdoutBuf.indexOf('\n')) != -1) {
    const QByteArray line = m_stdoutBuf.left(newlineIdx).trimmed();
    m_stdoutBuf.remove(0, newlineIdx + 1);
    if (!line.isEmpty())
      handleEvent(line);
  }
}

void ScraperService::onReadyReadStderr() {
  const QByteArray err = m_process->readAllStandardError();
  for (const QByteArray &line : err.split('\n')) {
    if (!line.trimmed().isEmpty())
      qDebug().noquote() << "[scraper]" << QString::fromUtf8(line);
  }
}

void ScraperService::handleEvent(const QByteArray &line) {
  QJsonParseError parseErr;
  const QJsonDocument doc = QJsonDocument::fromJson(line, &parseErr);
  if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
    qWarning() << "[ScraperService] Bad JSON from daemon:" << line.left(200);
    return;
  }

  const QJsonObject obj = doc.object();
  const QString type = obj.value(QStringLiteral("type")).toString();

  if (type == QStringLiteral("ready")) {
    if (m_startupTimer) {
      m_startupTimer->stop();
      m_startupTimer->deleteLater();
      m_startupTimer = nullptr;
    }

    setState(Ready, QStringLiteral("瀏覽器已就緒"));
    emit browserReady();
    qInfo() << "[ScraperService] Browser daemon ready.";
    return;
  }

  if (type == QStringLiteral("scrape_result")) {
    if (m_scrapeTimer) {
      m_scrapeTimer->stop();
      m_scrapeTimer->deleteLater();
      m_scrapeTimer = nullptr;
    }

    const QString orderId = obj.value(QStringLiteral("order_id")).toString();
    const ScraperResult result = ScraperResult::fromJson(line);

    setState(Ready, QStringLiteral("瀏覽器已就緒"));
    m_currentOrderId.clear();

    qInfo() << "[ScraperService] Scrape result for order" << orderId << "->"
            << result.status;
    emit scraperFinished(orderId, result);
    return;
  }

  if (type == QStringLiteral("calibrate_result")) {
    const bool ok = obj.value(QStringLiteral("ok")).toBool();
    const QString msg = obj.value(QStringLiteral("message")).toString();
    setState(Ready,
             ok ? QStringLiteral("校正完成") : QStringLiteral("校正失敗"));
    qInfo() << "[ScraperService] Calibrate result: ok=" << ok << msg;
    return;
  }

  if (type == QStringLiteral("pong")) {
    qDebug() << "[ScraperService] pong received";
    return;
  }

  if (type == QStringLiteral("error")) {
    const QString msg = obj.value(QStringLiteral("msg")).toString();
    qWarning() << "[ScraperService] Daemon error event:" << msg;
    m_lastDaemonError = msg;
    if (!m_currentOrderId.isEmpty()) {
      const QString id = m_currentOrderId;
      m_currentOrderId.clear();
      if (m_scrapeTimer) {
        m_scrapeTimer->stop();
        m_scrapeTimer->deleteLater();
        m_scrapeTimer = nullptr;
      }
      setState(Ready, QStringLiteral("瀏覽器已就緒 (列印失敗)"));
      emit scraperFailed(id, msg);
    }
    return;
  }

  qWarning() << "[ScraperService] Unknown event type:" << type;
}

void ScraperService::onFinished(int exitCode, QProcess::ExitStatus exitStatus) {
  if (m_process)
    onReadyReadStdout();

  const bool expectedShutdown = m_expectedShutdown;
  m_expectedShutdown = false;

  if (expectedShutdown) {
    qInfo() << "[ScraperService] Daemon process stopped. code=" << exitCode
            << "status=" << exitStatus;
  } else {
    qWarning() << "[ScraperService] Daemon process exited. code=" << exitCode
               << "status=" << exitStatus;
  }

  const QString reason =
      expectedShutdown
          ? QStringLiteral("瀏覽器已停止")
          : (!m_lastDaemonError.isEmpty()
                 ? m_lastDaemonError
                 : (exitStatus == QProcess::CrashExit
                        ? QStringLiteral("瀏覽器程序異常結束")
                        : QStringLiteral("瀏覽器程序已結束 (code=%1)")
                              .arg(exitCode)));

  if (!m_currentOrderId.isEmpty()) {
    const QString id = m_currentOrderId;
    m_currentOrderId.clear();
    emit scraperFailed(id, reason);
  }

  clearTimers();
  if (m_process) {
    QProcess *process = m_process;
    m_process = nullptr;
    process->deleteLater();
  }
  m_stdoutBuf.clear();
  m_lastDaemonError.clear();

  if (m_state != Restarting) {
    setState(Offline, QStringLiteral("瀏覽器已離線"));
    emit browserDied(reason);
  }
}

void ScraperService::onErrorOccurred(QProcess::ProcessError error) {
  if (error != QProcess::FailedToStart)
    return;

  const QString reason =
      QStringLiteral("無法啟動網頁自動化程式: ") + m_scraperExe;
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

void ScraperService::onStartupTimeout() {
  qWarning() << "[ScraperService] Startup timed out -- killing process";
  const QString reason = QStringLiteral("啟動逾時，瀏覽器未在時限內就緒。");
  killProcess();
  setState(Error, reason);
  emit browserDied(reason);
}

void ScraperService::onScrapeTimeout() {
  qWarning() << "[ScraperService] Scrape timed out for order"
             << m_currentOrderId;
  const QString id = m_currentOrderId;

  m_currentOrderId.clear();
  m_scrapeTimer = nullptr;
  setState(Ready, QStringLiteral("瀏覽器已就緒 (列印逾時)"));
  emit scraperFailed(id, QStringLiteral("TIMEOUT: 列印等待逾時，請稍後再試。"));
}
