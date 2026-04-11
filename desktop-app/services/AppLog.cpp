#include "AppLog.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMessageLogContext>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>

#include <cstdio>
#include <memory>

namespace {
QMutex g_logMutex;
std::unique_ptr<QFile> g_logFile;
QString g_logDirectoryPath;
QString g_currentLogFilePath;
bool g_installed = false;

QString levelLabel(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return QStringLiteral("DEBUG");
    case QtInfoMsg:
        return QStringLiteral("INFO");
    case QtWarningMsg:
        return QStringLiteral("WARN");
    case QtCriticalMsg:
        return QStringLiteral("ERROR");
    case QtFatalMsg:
        return QStringLiteral("FATAL");
    }
    return QStringLiteral("LOG");
}

QString buildLine(QtMsgType type,
                  const QMessageLogContext& context,
                  const QString& message)
{
    QString line = QStringLiteral("%1 [%2] %3")
                       .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz")),
                            levelLabel(type),
                            message);

    if (context.file && context.line > 0) {
        line += QStringLiteral(" (%1:%2)")
                    .arg(QString::fromUtf8(context.file))
                    .arg(context.line);
    }

    return line;
}

void writeLine(const QString& line)
{
    const QByteArray utf8 = line.toUtf8();
    std::fwrite(utf8.constData(), 1, static_cast<size_t>(utf8.size()), stderr);
    std::fwrite("\n", 1, 1, stderr);
    std::fflush(stderr);

    QMutexLocker locker(&g_logMutex);
    if (!g_logFile || !g_logFile->isOpen())
        return;

    g_logFile->write(utf8);
    g_logFile->write("\n");
    g_logFile->flush();
}

void appMessageHandler(QtMsgType type,
                       const QMessageLogContext& context,
                       const QString& message)
{
    writeLine(buildLine(type, context, message));

    if (type == QtFatalMsg)
        std::abort();
}
}

void AppLog::install()
{
    QMutexLocker locker(&g_logMutex);
    if (g_installed)
        return;

    const QString baseDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    g_logDirectoryPath = baseDir + QStringLiteral("/logs");
    QDir().mkpath(g_logDirectoryPath);

    g_currentLogFilePath = g_logDirectoryPath + QStringLiteral("/packingelf-")
                         + QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"))
                         + QStringLiteral(".log");

    g_logFile = std::make_unique<QFile>(g_currentLogFilePath);
    if (g_logFile->open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qInstallMessageHandler(appMessageHandler);
        g_installed = true;
        locker.unlock();
        writeLine(QStringLiteral("%1 [INFO] Logging started at %2")
                      .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz")),
                           g_currentLogFilePath));
        return;
    }

    qInstallMessageHandler(appMessageHandler);
    g_installed = true;
    locker.unlock();
    writeLine(QStringLiteral("%1 [WARN] Failed to open log file: %2")
                  .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz")),
                       g_currentLogFilePath));
}

QString AppLog::logDirectoryPath()
{
    QMutexLocker locker(&g_logMutex);
    return g_logDirectoryPath;
}

QString AppLog::currentLogFilePath()
{
    QMutexLocker locker(&g_logMutex);
    return g_currentLogFilePath;
}
