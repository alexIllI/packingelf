#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class AppSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(int orderPrefix READ orderPrefix WRITE setOrderPrefix NOTIFY orderPrefixChanged)
    Q_PROPERTY(QStringList printingPrefixOptions READ printingPrefixOptions NOTIFY orderPrefixChanged)
    Q_PROPERTY(QString configFilePath READ configFilePath CONSTANT)

public:
    explicit AppSettings(QObject *parent = nullptr);

    int orderPrefix() const;
    Q_INVOKABLE void setOrderPrefix(int prefix);

    QStringList printingPrefixOptions() const;
    QString configFilePath() const;

signals:
    void orderPrefixChanged();

private:
    static constexpr int kDefaultOrderPrefix = 24;
    static constexpr int kMinOrderPrefix = 2;
    static constexpr int kMaxOrderPrefix = 997;

    int sanitizePrefix(int prefix) const;

    int m_orderPrefix;
    QString m_configFilePath;
};

