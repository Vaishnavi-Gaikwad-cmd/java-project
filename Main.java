package com.hospital;

import com.hospital.util.DatabaseConnection;
import javafx.application.Application;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

/** Entry point. Phase 1 shows a database connectivity check; Phase 2 replaces it with Login. */
public class Main extends Application {

    @Override
    public void start(Stage stage) {
        boolean connected = DatabaseConnection.isDatabaseReachable();

        Label title = new Label("MediCare Hospital");
        title.setStyle("-fx-font-size: 28px; -fx-font-weight: bold; -fx-text-fill: #0f766e;");
        Label subtitle = new Label("Hospital Management System");
        Label status = new Label(connected
                ? "Database connection: OK"
                : "Database connection FAILED - check application.properties");
        status.setStyle("-fx-font-size: 14px; -fx-text-fill: " + (connected ? "#15803d" : "#b91c1c") + ";");

        VBox root = new VBox(12, title, subtitle, status);
        root.setAlignment(Pos.CENTER);
        root.setPadding(new Insets(40));

        stage.setTitle("MediCare Hospital Management System");
        stage.setScene(new Scene(root, 520, 260));
        stage.show();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
