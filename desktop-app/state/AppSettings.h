#pragma once

#include <QObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <optional>

struct MyAcgAccount {
    QString name;
    QString account;
    QString password;
};

class AppSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(int orderPrefix READ orderPrefix WRITE setOrderPrefix NOTIFY orderPrefixChanged)
    Q_PROPERTY(QStringList printingPrefixOptions READ printingPrefixOptions NOTIFY orderPrefixChanged)
    Q_PROPERTY(QVariantList myAcgAccounts READ myAcgAccounts NOTIFY myAcgAccountsChanged)
    Q_PROPERTY(QStringList myAcgAccountNames READ myAcgAccountNames NOTIFY myAcgAccountsChanged)
    Q_PROPERTY(bool autoLoginEnabled READ autoLoginEnabled WRITE setAutoLoginEnabled NOTIFY autoLoginSettingsChanged)
    Q_PROPERTY(QString selectedMyAcgAccountName READ selectedMyAcgAccountName WRITE setSelectedMyAcgAccountName NOTIFY autoLoginSettingsChanged)
    Q_PROPERTY(QString configFilePath READ configFilePath CONSTANT)

public:
    explicit AppSettings(QObject *parent = nullptr);

    int orderPrefix() const;
    Q_INVOKABLE void setOrderPrefix(int prefix);

    QStringList printingPrefixOptions() const;
    QVariantList myAcgAccounts() const;
    QStringList myAcgAccountNames() const;
    bool autoLoginEnabled() const;
    QString selectedMyAcgAccountName() const;
    QString configFilePath() const;

    Q_INVOKABLE bool addOrUpdateMyAcgAccount(const QString& name,
                                             const QString& account,
                                             const QString& password);
    Q_INVOKABLE bool deleteMyAcgAccount(const QString& name);
    Q_INVOKABLE QVariantMap myAcgAccount(const QString& name) const;
    Q_INVOKABLE bool hasMyAcgAccount(const QString& name) const;
    Q_INVOKABLE void setAutoLoginEnabled(bool enabled);
    Q_INVOKABLE void setSelectedMyAcgAccountName(const QString& name);

    std::optional<MyAcgAccount> selectedMyAcgAccount() const;

signals:
    void orderPrefixChanged();
    void myAcgAccountsChanged();
    void autoLoginSettingsChanged();

private:
    static constexpr int kDefaultOrderPrefix = 24;
    static constexpr int kMinOrderPrefix = 2;
    static constexpr int kMaxOrderPrefix = 997;

    void load();
    void save() const;
    int sanitizePrefix(int prefix) const;
    QString sanitizeAccountName(const QString& name) const;
    int indexOfMyAcgAccount(const QString& name) const;
    QVariantMap accountToVariantMap(const MyAcgAccount& account) const;

    int m_orderPrefix = kDefaultOrderPrefix;
    QList<MyAcgAccount> m_accounts;
    bool m_autoLoginEnabled = false;
    QString m_selectedMyAcgAccountName;
    QString m_configFilePath;
};
