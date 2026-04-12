package com.meridian.packingelf.host;

public record HostClientInfo(
    String clientId,
    String clientName,
    String createdAt,
    String lastSeenAt,
    long lastKnownHostRevision
) {
}
