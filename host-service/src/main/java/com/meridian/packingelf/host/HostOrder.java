package com.meridian.packingelf.host;

public record HostOrder(
    String id,
    String orderNumber,
    String invoiceNumber,
    String buyerName,
    String orderDate,
    long totalAmount,
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
