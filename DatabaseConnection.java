package com.hospital.util;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/** Central JDBC connection provider. Credentials come from application.properties only. */
public final class DatabaseConnection {

    private static final Logger LOGGER = Logger.getLogger(DatabaseConnection.class.getName());
    private static final String CONFIG_PATH = "/config/application.properties";
    private static final Properties PROPERTIES = loadProperties();

    private DatabaseConnection() { }

    private static Properties loadProperties() {
        Properties properties = new Properties();
        try (InputStream input = DatabaseConnection.class.getResourceAsStream(CONFIG_PATH)) {
            if (input == null) {
                LOGGER.severe("Missing configuration file: " + CONFIG_PATH);
            } else {
                properties.load(input);
            }
        } catch (IOException exception) {
            LOGGER.log(Level.SEVERE, "Unable to read database configuration", exception);
        }
        return properties;
    }

    public static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(
                PROPERTIES.getProperty("db.url"),
                PROPERTIES.getProperty("db.username"),
                PROPERTIES.getProperty("db.password"));
    }

    /** Returns true when a connection can be opened; technical details are only logged. */
    public static boolean isDatabaseReachable() {
        try (Connection connection = getConnection()) {
            return connection.isValid(3);
        } catch (SQLException exception) {
            LOGGER.log(Level.SEVERE, "Database connection failed", exception);
            return false;
        }
    }
}
