# Putting It All Together and Next Steps

In this final module, we'll orchestrate all the components we've built into a cohesive application and explore how your transit monitoring system operates. By the end, you'll have a complete, running application.

## The Application Architecture

Before diving into the code, let's review the complete architecture of our transit monitoring system:

```mermaid
graph TB
    %% Main component
    App[TransitMonitorApp]
    
    %% Core services
    ConfigService[ConfigService]
    ConnectService[ConnectService]
    GtfsService[GtfsService]
    SchemaService[SchemaService]
    IngestService[IngestService]
    MonitorService[MonitorService]
    ReportService[ReportService]
    
    %% External systems
    Ignite[(Apache Ignite)]
    GTFS[(GTFS Feed)]
    EnvFile[(.env File)]
    
    %% Utilities
    TerminalUtil([TerminalUtil])
    LoggingUtil([LoggingUtil])
    
    %% Relationships
    App --> ConfigService
    App --> ConnectService
    App --> SchemaService
    App --> GtfsService
    App --> IngestService
    App --> MonitorService
    App --> ReportService
    
    ConfigService --> EnvFile
    
    ConnectService --> Ignite
    SchemaService --> ConnectService
    
    GtfsService --> GTFS
    
    IngestService --> GtfsService
    IngestService --> ConnectService
    
    MonitorService --> ConnectService
    
    ReportService --> ConnectService
    
    App -.-> TerminalUtil
    App -.-> LoggingUtil
    ReportService -.-> TerminalUtil
    
    %% Styling
    classDef main fill:#fffaf0,stroke:#ff8c00,stroke-width:2px
    classDef service fill:#f0f8ff,stroke:#4682b4,stroke-width:1px
    classDef database fill:#f5fffa,stroke:#3cb371,stroke-width:1px,stroke-dasharray: 5 5
    classDef utility fill:#f8f8ff,stroke:#9370db,stroke-width:1px,stroke-dasharray: 3 3
    
    class App main
    class ConfigService,ConnectService,GtfsService,SchemaService,IngestService,MonitorService,ReportService service
    class Ignite,GTFS,EnvFile database
    class TerminalUtil,LoggingUtil utility
```

This architecture demonstrates several important design principles:

1. **Component Separation**: Each class has a clear, focused responsibility
2. **Clean Integration**: Components interact through well-defined interfaces
3. **Central Coordination**: The main application orchestrates all components
4. **Configuration Management**: External configuration keeps credentials secure
5. **Resource Lifecycle**: Components are properly started and stopped

> [!important]
> **Checkpoint**: Review the architecture diagram and make sure you understand:
>
> - The purpose of each component
> - How data flows through the system
> - How components interact with each other
> - The central role of the main application in orchestrating components

## Creating the Main Application

The `TransitMonitoringApp` class serves as our application's entry point, bringing together all the components we've developed:

```java
package com.example.transit.app;

import com.example.transit.service.*;
import com.example.transit.util.LoggingUtil;
import com.example.transit.util.TerminalUtil;
import org.apache.ignite.client.IgniteClient;

import java.util.*;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Main application for transit monitoring system.
 * Controls data ingestion, monitoring, and dashboard display.
 */
public class TransitMonitorApp {
    // Configuration constants
    private static final int INGESTION_INTERVAL = 30;  // seconds
    private static final int MONITORING_INTERVAL = 60; // seconds
    private static final int DASHBOARD_REFRESH = 10;   // seconds

    // Dashboard view types
    private static final int VIEW_SUMMARY = 0;
    private static final int VIEW_ALERTS = 1;
    private static final int VIEW_DETAILS = 2;
    private static final int TOTAL_VIEWS = 3;

    // Core services
    private final ConnectService connectionService;
    private final IngestService ingestionService;
    private final MonitorService monitoringService;
    private final ReportService reportingService;
    private final ScheduledExecutorService dashboardScheduler;
    private final IgniteClient client;

    // Dashboard state
    private final AtomicInteger currentView = new AtomicInteger(0);
    private boolean isRunning = false;

    /**
     * Create a new transit monitoring application.
     */
    public TransitMonitorApp() {
        // Get configuration
        ConfigService config = ConfigService.getInstance();
        if (!config.validateConfiguration()) {
            throw new IllegalStateException("Invalid configuration");
        }

        // Initialize core services
        this.connectionService = new ConnectService();
        this.client = connectionService.getClient();
        this.ingestionService = new IngestService(
                new GtfsService(config.getFeedUrl()),
                connectionService)
                .withBatchSize(100);
        this.monitoringService = new MonitorService(connectionService);
        this.reportingService = new ReportService(client);
        this.dashboardScheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "dashboard-thread");
            t.setDaemon(true);
            return t;
        });

        // Set quiet mode to true to suppress individual alert output
        this.monitoringService.setQuietMode(true);
    }

    /**
     * Start all transit monitoring services.
     */
    public boolean start() {
        if (isRunning) {
            TerminalUtil.logInfo("System already running");
            return true;
        }

        try {
            // Setup UI
            TerminalUtil.clearScreen();
            TerminalUtil.printWelcomeBanner();
            TerminalUtil.showStartupAnimation();

            // Setup database
            TerminalUtil.logInfo("Setting up database schema...");
            boolean schemaCreated = new SchemaService(connectionService).createSchema();
            if (!schemaCreated) {
                TerminalUtil.logError("Schema creation failed. Aborting.");
                return false;
            }

            // Start services
            TerminalUtil.logInfo("Starting data ingestion (interval: " + INGESTION_INTERVAL + "s)");
            ingestionService.start(INGESTION_INTERVAL);

            TerminalUtil.logInfo("Starting monitoring (interval: " + MONITORING_INTERVAL + "s)");
            monitoringService.startMonitoring(MONITORING_INTERVAL);

            // Start dashboard
            startDashboard();

            isRunning = true;
            TerminalUtil.logInfo(TerminalUtil.ANSI_GREEN + "Transit monitoring system started" + TerminalUtil.ANSI_RESET);
            return true;
        } catch (Exception e) {
            TerminalUtil.logError("Startup error: " + e.getMessage());
            stop();
            return false;
        }
    }

    /**
     * Stop all services.
     */
    public void stop() {
        TerminalUtil.logInfo("Stopping Transit Monitoring System");
        TerminalUtil.showShutdownAnimation();

        // Stop all services
        shutdownScheduler(dashboardScheduler);
        monitoringService.stopMonitoring();
        ingestionService.stop();

        try {
            connectionService.close();
        } catch (Exception e) {
            TerminalUtil.logError("Error closing connection: " + e.getMessage());
        }

        isRunning = false;
        TerminalUtil.logInfo(TerminalUtil.ANSI_GREEN + "System stopped" + TerminalUtil.ANSI_RESET);
    }

    /**
     * Start the dashboard display.
     */
    private void startDashboard() {
        TerminalUtil.logInfo("Starting dashboard (refresh: " + DASHBOARD_REFRESH + "s)");
        dashboardScheduler.scheduleAtFixedRate(() -> {
            try {
                // Rotate through views
                displayDashboard(currentView.get());
                currentView.set((currentView.get() + 1) % TOTAL_VIEWS);
            } catch (Exception e) {
                TerminalUtil.logError("Dashboard error: " + e.getMessage());
            }
        }, DASHBOARD_REFRESH, DASHBOARD_REFRESH, TimeUnit.SECONDS);
    }

    /**
     * Display the dashboard with the specified view.
     */
    private void displayDashboard(int viewType) {
        int terminalWidth = TerminalUtil.getTerminalWidth();
        TerminalUtil.clearScreen();

        // Display header
        reportingService.printDashboardHeader(terminalWidth);

        // Display view title
        String viewTitle = reportingService.getViewTitle(viewType);
        System.out.println(TerminalUtil.ANSI_BOLD + TerminalUtil.ANSI_YELLOW + viewTitle + TerminalUtil.ANSI_RESET);
        System.out.println(TerminalUtil.ANSI_CYAN + "─".repeat(Math.min(terminalWidth, 80)) + TerminalUtil.ANSI_RESET);

        // Display view content
        switch (viewType) {
            case VIEW_SUMMARY:  displaySummaryView(); break;
            case VIEW_ALERTS:   displayAlertsView(); break;
            case VIEW_DETAILS:  displayDetailsView(); break;
        }

        // Display footer
        reportingService.printDashboardFooter(DASHBOARD_REFRESH);
    }

    /**
     * Display the summary view.
     */
    private void displaySummaryView() {
        // Active vehicles section
        System.out.println(TerminalUtil.ANSI_BOLD + "ACTIVE VEHICLES BY ROUTE" + TerminalUtil.ANSI_RESET);
        reportingService.displayActiveVehicles();

        // Vehicle status section
        System.out.println();
        System.out.println(TerminalUtil.ANSI_BOLD + "VEHICLE STATUS DISTRIBUTION" + TerminalUtil.ANSI_RESET);
        reportingService.displayVehicleStatuses();

        // Ingestion status section
        System.out.println();
        System.out.println(TerminalUtil.ANSI_BOLD + "DATA INGESTION STATUS" + TerminalUtil.ANSI_RESET);
        reportingService.displayIngestionStatus(ingestionService.getStatistics());
    }

    /**
     * Display the alerts view.
     */
    private void displayAlertsView() {
        // Recent alerts section
        System.out.println(TerminalUtil.ANSI_BOLD + "RECENT SERVICE ALERTS" + TerminalUtil.ANSI_RESET);
        reportingService.displayRecentAlerts(monitoringService.getRecentAlerts());

        // Alert statistics section
        System.out.println();
        System.out.println(TerminalUtil.ANSI_BOLD + "ALERT STATISTICS" + TerminalUtil.ANSI_RESET);
        reportingService.displayAlertStatistics(monitoringService.getAlertCounts());
    }

    /**
     * Display the details view.
     */
    private void displayDetailsView() {
        // System statistics section
        System.out.println(TerminalUtil.ANSI_BOLD + "SYSTEM STATISTICS" + TerminalUtil.ANSI_RESET);
        reportingService.displaySystemStatistics();

        // Monitoring thresholds section
        System.out.println();
        System.out.println(TerminalUtil.ANSI_BOLD + "MONITORING THRESHOLDS" + TerminalUtil.ANSI_RESET);
        reportingService.displayMonitoringThresholds();

        // Connection status section
        System.out.println();
        System.out.println(TerminalUtil.ANSI_BOLD + "CONNECTION STATUS" + TerminalUtil.ANSI_RESET);
        reportingService.displayConnectionStatus(ingestionService.getStatistics());
    }

    /**
     * Helper to safely shutdown a scheduler.
     */
    private void shutdownScheduler(ScheduledExecutorService scheduler) {
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }

    /**
     * Main method to run the transit monitoring application.
     */
    public static void main(String[] args) {
        // Configure logging to suppress unnecessary output
        LoggingUtil.setLogs("OFF");

        // Create application
        TransitMonitorApp app;
        try {
            app = new TransitMonitorApp();
        } catch (IllegalStateException e) {
            return; // Exit if configuration is invalid
        }

        if (app.start()) {
            // Show running message
            System.out.println("\n" + TerminalUtil.ANSI_BOLD + "═".repeat(60) + TerminalUtil.ANSI_RESET);
            System.out.println(TerminalUtil.ANSI_GREEN + "Transit monitoring system is running" + TerminalUtil.ANSI_RESET);
            System.out.println(TerminalUtil.ANSI_BLUE + "Press ENTER to exit" + TerminalUtil.ANSI_RESET);
            System.out.println(TerminalUtil.ANSI_BOLD + "═".repeat(60) + TerminalUtil.ANSI_RESET + "\n");

            // Wait for user input to exit
            try {
                new Scanner(System.in).nextLine();
            } catch (Exception e) {
                try {
                    Thread.sleep(60000); // Wait 1 minute if input doesn't work
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }

            // Stop application
            app.stop();
        }
    }
}
```

You will need the following files from the sample repository for the application to run:

- The `TerminalUtils` utility class
- The `ConfigService` service class
- The `ReportService` service class

> [!important]
> **Checkpoint**: Take a moment to understand the structure of the main application:
>
> - How it initializes and connects all the components we've developed
> - The dashboard refresh cycle and multiple view types
> - The proper startup and shutdown sequence
> - How it handles user interaction

## Running the Application

To run the complete transit monitoring application:

1. Ensure your Ignite cluster is running (see [Module 2](02-project-setup.md))
2. Configure your `.env` file with the appropriate GTFS feed details
3. Build the project: `mvn clean package`
4. Run the application:

   ```bash
   java -jar target/transit-monitor-1.0.jar
   ```

5. Hit ENTER to end the application

When the application starts successfully, you'll see:

- Confirmation messages as each component initializes
- The console dashboard updating every few seconds
- A prompt to press Enter to exit

> [!note]
> The application uses a rotating dashboard that cycles through three views:
>
> 1. **Summary View**: Shows active vehicles by route, status distribution, and ingestion statistics
> 2. **Alerts View**: Displays service alerts and alert statistics
> 3. **Details View**: Shows system-wide statistics, monitoring thresholds, and connection status

> [!important]
> **Checkpoint**: After starting the application, verify that:
>
> - All components initialize without errors
> - Data is being ingested (check the ingestion statistics)
> - The dashboard updates regularly
> - You can exit cleanly by pressing Enter

## A Complete Transit Monitoring System

Congratulations! You've now built a complete transit monitoring system using Apache Ignite 3. Your application:

1. **Connects to real-time transit data** using the GTFS-realtime standard
2. **Stores and processes this data** in a distributed Ignite database
3. **Monitors for service disruptions** using SQL-based analysis
4. **Visualizes system status** through a console dashboard
5. **Manages the complete lifecycle** of all components

This system demonstrates the power of Apache Ignite for real-time data processing and monitoring applications. The architecture patterns you've learned can be applied to many other domains beyond transit monitoring, including IoT systems, financial transaction monitoring, logistics tracking, and more.

> [!important]
> **Final Checkpoint**: As you wrap up the tutorial, ensure you:
>
> - Understand how all components work together in the integrated application
> - Can run the complete application and interpret its dashboard output
> - Know how to troubleshoot common issues that might arise
> - Have ideas for how you might extend or customize the system for your needs

Thank you for completing this guide! We hope you've gained a practical understanding of Apache Ignite 3.0's capabilities for real-time data processing and monitoring applications.

Happy coding with Apache Ignite!
