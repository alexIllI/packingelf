module com.meridian.packingelf.host {
    requires javafx.controls;
    requires javafx.graphics;
    requires java.sql;
    requires java.desktop;
    requires jdk.httpserver;
    requires com.fasterxml.jackson.databind;
    requires org.apache.poi.ooxml;
    requires org.xerial.sqlitejdbc;

    exports com.meridian.packingelf.host;
}
