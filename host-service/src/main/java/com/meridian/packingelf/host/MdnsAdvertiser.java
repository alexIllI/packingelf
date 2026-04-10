package com.meridian.packingelf.host;

import javax.jmdns.JmDNS;
import javax.jmdns.ServiceInfo;
import java.io.Closeable;
import java.io.IOException;
import java.net.InetAddress;

final class MdnsAdvertiser implements Closeable {
    private final JmDNS jmDns;
    private final ServiceInfo serviceInfo;

    MdnsAdvertiser(String serviceName, int port) throws IOException {
        InetAddress address = InetAddress.getLocalHost();
        this.jmDns = JmDNS.create(address);
        this.serviceInfo = ServiceInfo.create("_packingelf._tcp.local.", serviceName, port, "role=host");
    }

    void start() throws IOException {
        jmDns.registerService(serviceInfo);
    }

    @Override
    public void close() throws IOException {
        jmDns.unregisterService(serviceInfo);
        jmDns.close();
    }
}
