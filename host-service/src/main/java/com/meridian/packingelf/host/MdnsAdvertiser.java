package com.meridian.packingelf.host;

import java.io.Closeable;
import java.io.IOException;

final class MdnsAdvertiser implements Closeable {
    private final String serviceName;

    MdnsAdvertiser(String serviceName, int port) throws IOException {
        this.serviceName = serviceName == null || serviceName.isBlank()
            ? "packingelf-host.local"
            : serviceName + ".local";
        // Discovery is intentionally stubbed for now.
        // The current client build still uses a manually configured host URL.
    }

    void start() throws IOException {
    }

    String serviceName() {
        return serviceName;
    }

    @Override
    public void close() throws IOException {
    }
}
