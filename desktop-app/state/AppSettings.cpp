#include "AppSettings.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>

namespace {
constexpr auto kOrderPrefixKey = "Settings/OrderPrefix";
constexpr auto kAccountsKey = "MyAcg/AccountsJson";
constexpr auto kAutoLoginEnabledKey = "MyAcg/AutoLoginEnabled";
constexpr auto kSelectedAccountKey = "MyAcg/SelectedAccountName";
}

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    const QString appDataDir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(appDataDir);

    m_configFilePath = appDataDir + QStringLiteral("/config.ini");
    load();
    save();
}

void AppSettings::load()
{
    QSettings settings(m_configFilePath, QSettings::IniFormat);

    const int storedPrefix =
        settings.value(QString::fromLatin1(kOrderPrefixKey), kDefaultOrderPrefix).toInt();
    m_orderPrefix = sanitizePrefix(storedPrefix);
    m_autoLoginEnabled =
        settings.value(QString::fromLatin1(kAutoLoginEnabledKey), false).toBool();
    m_selectedMyAcgAccountName =
        sanitizeAccountName(settings.value(QString::fromLatin1(kSelectedAccountKey)).toString());

    m_accounts.clear();
    const QByteArray rawAccounts =
        settings.value(QString::fromLatin1(kAccountsKey), QStringLiteral("[]")).toByteArray();
    const QJsonDocument accountsDoc = QJsonDocument::fromJson(rawAccounts);
    if (accountsDoc.isArray()) {
        const QJsonArray accountsArray = accountsDoc.array();
        for (const QJsonValue& value : accountsArray) {
            if (!value.isObject())
                continue;

            const QJsonObject obj = value.toObject();
            const QString name = sanitizeAccountName(obj.value(QStringLiteral("name")).toString());
            const QString account = obj.value(QStringLiteral("account")).toString().trimmed();
            const QString password = obj.value(QStringLiteral("password")).toString();
            if (name.isEmpty() || account.isEmpty() || password.isEmpty())
                continue;

            m_accounts.append(MyAcgAccount{name, account, password});
        }
    }

    if (!hasMyAcgAccount(m_selectedMyAcgAccountName))
        m_selectedMyAcgAccountName.clear();
}

void AppSettings::save() const
{
    QSettings settings(m_configFilePath, QSettings::IniFormat);
    settings.setValue(QString::fromLatin1(kOrderPrefixKey), m_orderPrefix);
    settings.setValue(QString::fromLatin1(kAutoLoginEnabledKey), m_autoLoginEnabled);
    settings.setValue(QString::fromLatin1(kSelectedAccountKey), m_selectedMyAcgAccountName);

    QJsonArray accountsArray;
    for (const MyAcgAccount& account : m_accounts) {
        QJsonObject obj;
        obj.insert(QStringLiteral("name"), account.name);
        obj.insert(QStringLiteral("account"), account.account);
        obj.insert(QStringLiteral("password"), account.password);
        accountsArray.append(obj);
    }
    settings.setValue(QString::fromLatin1(kAccountsKey),
                      QString::fromUtf8(QJsonDocument(accountsArray).toJson(QJsonDocument::Compact)));
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
    save();
    emit orderPrefixChanged();
}

QStringList AppSettings::printingPrefixOptions() const
{
    QStringList options;
    for (int i = -2; i <= 2; ++i)
        options.append(QStringLiteral("PG%1").arg(m_orderPrefix + i, 3, 10, QLatin1Char('0')));
    return options;
}

QVariantList AppSettings::myAcgAccounts() const
{
    QVariantList accounts;
    for (const MyAcgAccount& account : m_accounts)
        accounts.append(accountToVariantMap(account));
    return accounts;
}

QStringList AppSettings::myAcgAccountNames() const
{
    QStringList names;
    for (const MyAcgAccount& account : m_accounts)
        names.append(account.name);
    return names;
}

bool AppSettings::autoLoginEnabled() const
{
    return m_autoLoginEnabled;
}

QString AppSettings::selectedMyAcgAccountName() const
{
    return m_selectedMyAcgAccountName;
}

QString AppSettings::configFilePath() const
{
    return m_configFilePath;
}

bool AppSettings::addOrUpdateMyAcgAccount(const QString& name,
                                          const QString& account,
                                          const QString& password)
{
    const QString sanitizedName = sanitizeAccountName(name);
    const QString trimmedAccount = account.trimmed();
    if (sanitizedName.isEmpty() || trimmedAccount.isEmpty() || password.isEmpty())
        return false;

    const int existingIndex = indexOfMyAcgAccount(sanitizedName);
    if (existingIndex >= 0) {
        m_accounts[existingIndex] = MyAcgAccount{sanitizedName, trimmedAccount, password};
    } else {
        m_accounts.append(MyAcgAccount{sanitizedName, trimmedAccount, password});
    }

    if (m_selectedMyAcgAccountName.isEmpty())
        m_selectedMyAcgAccountName = sanitizedName;

    save();
    emit myAcgAccountsChanged();
    emit autoLoginSettingsChanged();
    return true;
}

bool AppSettings::deleteMyAcgAccount(const QString& name)
{
    const int existingIndex = indexOfMyAcgAccount(name);
    if (existingIndex < 0)
        return false;

    const QString removedName = m_accounts.at(existingIndex).name;
    m_accounts.removeAt(existingIndex);

    if (m_selectedMyAcgAccountName == removedName)
        m_selectedMyAcgAccountName = m_accounts.isEmpty() ? QString() : m_accounts.first().name;

    save();
    emit myAcgAccountsChanged();
    emit autoLoginSettingsChanged();
    return true;
}

QVariantMap AppSettings::myAcgAccount(const QString& name) const
{
    const int index = indexOfMyAcgAccount(name);
    if (index < 0)
        return {};
    return accountToVariantMap(m_accounts.at(index));
}

bool AppSettings::hasMyAcgAccount(const QString& name) const
{
    return indexOfMyAcgAccount(name) >= 0;
}

void AppSettings::setAutoLoginEnabled(bool enabled)
{
    if (enabled && m_selectedMyAcgAccountName.isEmpty() && !m_accounts.isEmpty())
        m_selectedMyAcgAccountName = m_accounts.first().name;

    if (m_autoLoginEnabled == enabled)
        return;

    m_autoLoginEnabled = enabled;
    save();
    emit autoLoginSettingsChanged();
}

void AppSettings::setSelectedMyAcgAccountName(const QString& name)
{
    const QString sanitizedName =
        hasMyAcgAccount(name) ? sanitizeAccountName(name) : QString();
    if (m_selectedMyAcgAccountName == sanitizedName)
        return;

    m_selectedMyAcgAccountName = sanitizedName;
    save();
    emit autoLoginSettingsChanged();
}

std::optional<MyAcgAccount> AppSettings::selectedMyAcgAccount() const
{
    const int index = indexOfMyAcgAccount(m_selectedMyAcgAccountName);
    if (index < 0)
        return std::nullopt;
    return m_accounts.at(index);
}

int AppSettings::sanitizePrefix(int prefix) const
{
    if (prefix < kMinOrderPrefix)
        return kMinOrderPrefix;
    if (prefix > kMaxOrderPrefix)
        return kMaxOrderPrefix;
    return prefix;
}

QString AppSettings::sanitizeAccountName(const QString& name) const
{
    return name.trimmed();
}

int AppSettings::indexOfMyAcgAccount(const QString& name) const
{
    const QString sanitizedName = sanitizeAccountName(name);
    for (int i = 0; i < m_accounts.size(); ++i) {
        if (m_accounts.at(i).name.compare(sanitizedName, Qt::CaseSensitive) == 0)
            return i;
    }
    return -1;
}

QVariantMap AppSettings::accountToVariantMap(const MyAcgAccount& account) const
{
    QVariantMap map;
    map.insert(QStringLiteral("name"), account.name);
    map.insert(QStringLiteral("account"), account.account);
    map.insert(QStringLiteral("password"), account.password);
    map.insert(QStringLiteral("maskedPassword"), QString(account.password.size(), QLatin1Char('*')));
    return map;
}
