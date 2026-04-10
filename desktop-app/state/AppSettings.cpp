#include "AppSettings.h"
#include <QSettings>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    // Uses the default configuration stored in %APPDATA%/Meridian/PackingElf/PackingElf.ini
    // based on QCoreApplication::setOrganizationName and setApplicationName.
    QSettings settings;
    m_orderPrefix = settings.value(QStringLiteral("Settings/OrderPrefix"), 24).toInt();
}

int AppSettings::orderPrefix() const
{
    return m_orderPrefix;
}

void AppSettings::setOrderPrefix(int prefix)
{
    if (m_orderPrefix == prefix)
        return;

    m_orderPrefix = prefix;
    
    QSettings settings;
    settings.setValue(QStringLiteral("Settings/OrderPrefix"), m_orderPrefix);
    
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

