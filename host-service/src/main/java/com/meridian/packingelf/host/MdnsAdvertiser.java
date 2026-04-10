package com.meridian.packingelf.host;

import java.io.Closeable;
import java.io.IOException;

final class MdnsAdvertiser implements Closeable {
    MdnsAdvertiser(String serviceName, int port) throws IOException {
        // Discovery is intentionally stubbed for now.
        // The current client build still uses a manually configured host URL.
    }

    void start() throws IOException {
    }

    @Override
    public void close() throws IOException {
    }
}
