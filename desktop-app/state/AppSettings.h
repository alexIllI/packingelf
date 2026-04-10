#pragma once

#include <QObject>
#include <QStringList>

class AppSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(int orderPrefix READ orderPrefix WRITE setOrderPrefix NOTIFY orderPrefixChanged)
    Q_PROPERTY(QStringList printingPrefixOptions READ printingPrefixOptions NOTIFY orderPrefixChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    int orderPrefix() const;
    Q_INVOKABLE void setOrderPrefix(int prefix);

    QStringList printingPrefixOptions() const;

signals:
    void orderPrefixChanged();

private:
    int m_orderPrefix;
};

