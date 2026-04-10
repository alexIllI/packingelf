package com.meridian.packingelf.host;

public final class HostLauncher {
    private HostLauncher() {
    }

    public static void main(String[] args) {
        HostApplication.launch(HostApplication.class, args);
    }
}
