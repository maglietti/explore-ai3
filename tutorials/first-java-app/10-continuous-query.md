# Adding a Service Monitor

One of Ignite's powerful features is its SQL querying capability which enables us to monitor for specific conditions and trigger actions when those conditions are met. Let's implement a service monitor to detect potential service disruptions by identifying vehicles that have been stopped for an extended period.

Create a file `ServiceMonitor.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Monitors vehicle positions for potential service disruptions.
 * Uses a polling approach to check for stopped vehicles.
 */
public class ServiceMonitor {
    // Threshold in minutes that determines when a stopped vehicle is considered delayed
    private static final int STOPPED_THRESHOLD_MINUTES = 5;
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
    private final IgniteClient client;
    
    public ServiceMonitor() {
        this.client = IgniteConnection.getClient();
    }
    
    /**
     * Starts monitoring for service disruptions by polling the database at regular intervals.
     * 
     * @param intervalSeconds The polling interval in seconds
     */
    public void startMonitoring(int intervalSeconds) {
        System.out.println("Starting service disruption monitoring (polling every " + intervalSeconds + " seconds)");
        scheduler.scheduleAtFixedRate(
            this::checkForServiceDisruptions, 
            0, 
            intervalSeconds, 
            TimeUnit.SECONDS
        );
    }
    
    /**
     * Stops the monitoring service.
     */
    public void stopMonitoring() {
        scheduler.shutdown();
        System.out.println("Service disruption monitoring stopped");
    }
    
    /**
     * Checks for vehicles that have been stopped for longer than the threshold.
     */
    private void checkForServiceDisruptions() {
        // Query to detect vehicles stopped for more than the threshold time
        String querySql = 
            "SELECT " +
            "    v.vehicle_id, " +
            "    v.route_id, " +
            "    v.current_status, " +
            "    v.latitude, " +
            "    v.longitude, " +
            "    v.time_stamp, " +
            "    TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as stopped_minutes " +
            "FROM vehicle_positions v " +
            "JOIN (" +
            "    SELECT vehicle_id, MAX(time_stamp) as latest_ts " +
            "    FROM vehicle_positions " +
            "    GROUP BY vehicle_id " +
            ") l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts " +
            "WHERE " +
            "    v.current_status = 'STOPPED_AT' " +
            "    AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) >= ?";
        
        try {
            // Execute the query with the threshold parameter
            var result = client.sql().execute(null, querySql, STOPPED_THRESHOLD_MINUTES);
            
            int count = 0;
            // Process each row in the result
            while (result.hasNext()) {
                var row = result.next();
                count++;
                
                System.out.println("Service disruption detected!");
                System.out.println("Vehicle ID: " + row.stringValue("vehicle_id"));
                System.out.println("Route ID: " + row.stringValue("route_id"));
                System.out.println("Status: " + row.stringValue("current_status"));
                System.out.println("Last updated: " + row.value("time_stamp"));
                System.out.println("Minutes stopped: " + row.intValue("stopped_minutes"));
                System.out.println("Location: (" + row.doubleValue("latitude") + ", " 
                                  + row.doubleValue("longitude") + ")");
                System.out.println("--------------------");
            }
            
            if (count > 0) {
                System.out.println("Found " + count + " delayed vehicles");
            }
        } catch (Exception e) {
            System.err.println("Error checking for service disruptions: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
```

## Understanding the Service Monitor

The ServiceMonitor uses a scheduled polling approach to regularly check for vehicles that meet our criteria for a service disruption. The key components include:

1. **The SQL Query**: This is the core of our monitoring solution, which identifies vehicles that have been stopped for more than 5 minutes.

2. **A Scheduled Executor**: This runs the check at regular intervals.

3. **Result Processing**: Each vehicle that meets the criteria is logged with detailed information.

The SQL query is particularly powerful because it:

1. Finds the latest position record for each vehicle using a subquery
2. Checks if that latest record has a "STOPPED_AT" status
3. Calculates how long the vehicle has been stopped using the `TIMESTAMPDIFF` function
4. Only returns vehicles where the stopped time exceeds our threshold (5 minutes)

## Using the Service Monitor

To use this monitor in your application, you would integrate it like this:

```java
public class TransitMonitoringApp {
    public static void main(String[] args) {
        // Set up schema first
        SchemaSetup schemaSetup = new SchemaSetup();
        schemaSetup.createSchema();
        
        // Start the data ingestion service
        DataIngestionService ingestService = new DataIngestionService("your-gtfs-feed-url");
        ingestService.start(30); // Update every 30 seconds
        
        // Start the service monitor with a 15-second polling interval
        ServiceMonitor monitor = new ServiceMonitor();
        monitor.startMonitoring(15);
        
        // The application continues running with regular monitoring
        System.out.println("Transit monitoring system is now active");
        
        // Add a shutdown hook to stop services gracefully
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("Shutting down monitoring services...");
            ingestService.stop();
            monitor.stopMonitoring();
        }));
    }
}
```

## Benefits of SQL-Based Monitoring

Using SQL queries for monitoring provides several advantages:

1. **Declarative Definition**: You can express complex conditions directly in SQL
2. **Server-Side Processing**: Filtering happens on the server, minimizing network traffic
3. **Flexibility**: Easily adjust thresholds or add new conditions
4. **Integration**: Works seamlessly with your existing data model

In a production system, you might extend this monitor with additional functionality such as:
- Sending notifications via email or SMS
- Logging incidents to a separate table for historical analysis
- Triggering automated recovery procedures
- Calculating service level metrics

This SQL-based monitoring approach demonstrates how Ignite can be used not just for data storage but as an intelligent processing platform for real-time applications.
