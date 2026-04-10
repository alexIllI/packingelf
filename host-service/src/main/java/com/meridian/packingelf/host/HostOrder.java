package com.meridian.packingelf.host;

public record HostOrder(
    String id,
    String orderNumber,
    String invoiceNumber,
    String buyerName,
    String orderDate,
    String orderStatus,
    boolean usingCoupon,
    String createdByClientId,
    String updatedByClientId,
    String createdAt,
    String updatedAt,
    String deletedAt,
    long serverRevision
) {
}
