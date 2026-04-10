#include "AppSettings.h"

#include <QDir>
#include <QSettings>
#include <QStandardPaths>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    const QString appDataDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(appDataDir);

    m_configFilePath = appDataDir + QStringLiteral("/config.ini");

    QSettings settings(m_configFilePath, QSettings::IniFormat);
    const int storedPrefix =
        settings.value(QStringLiteral("Settings/OrderPrefix"), kDefaultOrderPrefix).toInt();
    m_orderPrefix = sanitizePrefix(storedPrefix);
    settings.setValue(QStringLiteral("Settings/OrderPrefix"), m_orderPrefix);
    settings.sync();
}

int AppSettings::orderPrefix() const
{
    return m_orderPrefix;
}

void AppSettings::setOrderPrefix(int prefix)
{
    const int sanitizedPrefix = sanitizePrefix(prefix);
    if (m_orderPrefix == sanitizedPrefix)
        return;

    m_orderPrefix = sanitizedPrefix;

    QSettings settings(m_configFilePath, QSettings::IniFormat);
    settings.setValue(QStringLiteral("Settings/OrderPrefix"), m_orderPrefix);
    settings.sync();

    emit orderPrefixChanged();
}

QStringList AppSettings::printingPrefixOptions() const
{
    // Generates an array of [-2, -1, 0, +1, +2] offset from the current prefix
    // pad with zeros, e.g. "PG022", "PG023", "PG024", "PG025", "PG026"
    QStringList options;
    for (int i = -2; i <= 2; ++i) {
        options.append(QStringLiteral("PG%1").arg(m_orderPrefix + i, 3, 10, QLatin1Char('0')));
    }
    return options;
}

QString AppSettings::configFilePath() const
{
    return m_configFilePath;
}

int AppSettings::sanitizePrefix(int prefix) const
{
    if (prefix < kMinOrderPrefix)
        return kMinOrderPrefix;
    if (prefix > kMaxOrderPrefix)
        return kMaxOrderPrefix;
    return prefix;
}

