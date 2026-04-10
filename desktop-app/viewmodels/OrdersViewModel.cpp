#include "OrdersViewModel.h"

#include <QDateTime>
#include <QDebug>
#include <QUuid>

OrdersViewModel::OrdersViewModel(std::shared_ptr<OrdersRepository> repo,
                                 OutboxStore* outbox,
                                 QObject* parent)
    : QAbstractListModel(parent)
    , m_repo(std::move(repo))
    , m_outbox(outbox)
{
    refresh();
}

int OrdersViewModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_orders.size());
}

QVariant OrdersViewModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_orders.size())
        return {};

    const Order& order = m_orders.at(index.row());
    switch (role) {
    case IdRole:            return order.id;
    case OrderNumberRole:   return order.orderNumber;
    case InvoiceNumberRole: return order.invoiceNumber;
    case OrderDateRole:     return order.orderDate;
    case BuyerNameRole:     return order.buyerName;
    case StatusRole:        return order.orderStatus;
    case UsingCouponRole:   return order.usingCoupon ? QStringLiteral("yes") : QStringLiteral("no");
    case CreatedByRole:     return order.createdByClientId;
    case UpdatedByRole:     return order.updatedByClientId;
    case CreatedAtRole:     return order.createdAt;
    case UpdatedAtRole:     return order.updatedAt;
    default:                return {};
    }
}

QHash<int, QByteArray> OrdersViewModel::roleNames() const
{
    return {
        { IdRole,            "id" },
        { OrderNumberRole,   "orderNumber" },
        { InvoiceNumberRole, "invoiceNumber" },
        { OrderDateRole,     "date" },
        { BuyerNameRole,     "accountName" },
        { StatusRole,        "status" },
        { UsingCouponRole,   "usingCoupon" },
        { CreatedByRole,     "createdBy" },
        { UpdatedByRole,     "updatedBy" },
        { CreatedAtRole,     "createdAt" },
        { UpdatedAtRole,     "updatedAt" }
    };
}

int OrdersViewModel::pendingCount() const
{
    return m_repo->countPendingSubmissions();
}

QString OrdersViewModel::submitForScrape(const QString& orderNumber,
                                         const QString& invoiceNumber)
{
    if (orderNumber.isEmpty() || invoiceNumber.isEmpty()) {
        qWarning() << "[OrdersVM] submitForScrape missing inputs";
        return {};
    }

    auto submission = m_repo->createSubmission(orderNumber, invoiceNumber);
    if (!submission.has_value())
        return {};

    m_repo->updateSubmissionState(submission->submissionId, QStringLiteral("scraping"));
    emit pendingCountChanged();
    return submission->submissionId;
}

bool OrdersViewModel::removeOrder(int row)
{
    if (row < 0 || row >= m_orders.size())
        return false;

    const SyncConfig config = m_repo->syncConfig();
    const Order order = m_orders.at(row);
    if (!m_repo->softDelete(order.id, config.clientId))
        return false;

    if (m_outbox)
        m_outbox->enqueueDeleteOrder(order.orderNumber, config.clientId);

    beginRemoveRows(QModelIndex(), row, row);
    m_orders.removeAt(row);
    endRemoveRows();

    emit countChanged();
    emit orderRemoved(order.id);
    return true;
}

void OrdersViewModel::refresh()
{
    beginResetModel();
    m_orders = m_repo->fetchAll();
    endResetModel();
    emit countChanged();
    emit pendingCountChanged();
}

std::optional<QString> OrdersViewModel::normalizeStatus(const QString& scraperStatus) const
{
    const QString normalized = scraperStatus.trimmed().toUpper();
    if (normalized == QStringLiteral("SUCCESS"))
        return QStringLiteral("success");
    if (normalized == QStringLiteral("ORDER_CANCELED") || normalized == QStringLiteral("CANCELED"))
        return QStringLiteral("canceled");
    if (normalized == QStringLiteral("RETURNED"))
        return QStringLiteral("returned");
    return std::nullopt;
}

void OrdersViewModel::emitModelChanged()
{
    refresh();
}

void OrdersViewModel::handleScraperFinished(const QString& submissionId, const ScraperResult& result)
{
    const auto submission = m_repo->fetchSubmission(submissionId);
    if (!submission.has_value())
        return;

    const auto normalizedStatus = normalizeStatus(result.status);
    const bool resultComplete = normalizedStatus.has_value()
        && !result.buyerName.trimmed().isEmpty()
        && !result.orderDate.trimmed().isEmpty();

    if (!resultComplete) {
        qWarning() << "[OrdersVM] Scrape result rejected for submission" << submissionId
                   << "status:" << result.status << "message:" << result.message;
        m_repo->deleteSubmission(submissionId);
        emit pendingCountChanged();
        return;
    }

    const SyncConfig config = m_repo->syncConfig();
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    Order order;
    order.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    order.orderNumber = submission->orderNumber;
    order.invoiceNumber = submission->invoiceNumber;
    order.orderDate = result.orderDate;
    order.buyerName = result.buyerName;
    order.orderStatus = *normalizedStatus;
    order.usingCoupon = result.usingCoupon;
    order.createdByClientId = config.clientId;
    order.updatedByClientId = config.clientId;
    order.createdAt = now;
    order.updatedAt = now;
    order.deletedAt.clear();
    order.serverRevision = 0;

    if (!m_repo->upsertOrder(order)) {
        qWarning() << "[OrdersVM] Failed to persist finalized order for submission" << submissionId;
        return;
    }

    if (m_outbox)
        m_outbox->enqueueUpsertOrder(order, config.clientId);

    m_repo->deleteSubmission(submissionId);
    emitModelChanged();

    auto persisted = m_repo->fetchByOrderNumber(order.orderNumber);
    emit orderCreated(persisted.has_value() ? persisted->id : order.id);
}

void OrdersViewModel::handleScraperFailed(const QString& submissionId, const QString& reason)
{
    qWarning() << "[OrdersVM] Scrape failed for submission" << submissionId << reason;
    m_repo->deleteSubmission(submissionId);
    emit pendingCountChanged();
}
