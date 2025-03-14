# Putting It All Together

Finally, let's create our main application class that brings everything together. This will be the entry point for our transit monitoring system, orchestrating all the components we've built.

Create `TransitMonitoringApp.java`:

```java
package com.gridgain.transit;

import org.apache.ignite.client.IgniteClient;

import java.util.Date;
import java.util.Map;
import java.util.Scanner;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class TransitMonitoringApp {
    public static void main(String[] args) {
        // Set feed URL - use a reliable transit agency feed
        String feedUrl = "https://api.511.org/transit/vehiclepositions?api_key=YOUR_KEY&agency=SF";
        
        System.out.println("Starting Transit Monitoring Application with Ignite 3.0");
        
        // Connect to Ignite
        IgniteClient client = IgniteConnection.getClient();
        System.out.println("Connected to Ignite cluster");
        
        try {
            // First, test our GTFS connection to make sure data source works
            System.out.println("\n=== Testing GTFS Connection ===");
            GTFSFeedClient testClient = new GTFSFeedClient(feedUrl);
            int vehicleCount = testClient.getVehiclePositions().size();
            System.out.println("GTFS connection test successful. Found " + vehicleCount + " vehicles.");
            System.out.println("==========================\n");
            
            // Create schema
            System.out.println("Setting up database schema...");
            SchemaSetup schemaSetup = new SchemaSetup();
            schemaSetup.createSchema();
            
            // Start data ingestion service
            System.out.println("Starting data ingestion service...");
            DataIngestionService ingestionService = new DataIngestionService(feedUrl);
            ingestionService.start(30); // Fetch every 30 seconds
            
            // Wait a moment for some data to be ingested
            System.out.println("Waiting for initial data ingestion...");
            Thread.sleep(5000); // Wait 5 seconds
            
            // Verify data is in Ignite
            System.out.println("\n=== Verifying Data in Ignite ===");
            DataVerifier.verifyData();
            System.out.println("===========================\n");
            
            // Set up monitoring for service disruptions
            System.out.println("Setting up service disruption monitoring...");
            ServiceMonitor monitor = new ServiceMonitor();
            monitor.monitorServiceDisruptions();
            
            // Start simple console dashboard
            System.out.println("Starting console dashboard...");
            startConsoleDashboard();
            
            System.out.println("\n===============================================");
            System.out.println("Transit monitoring system is now running");
            System.out.println("Press ENTER to exit");
            System.out.println("===============================================\n");
            
            // Wait for user input to stop
            new Scanner(System.in).nextLine();
            
            // Cleanup
            System.out.println("Shutting down...");
            ingestionService.stop();
            client.close();
            
        } catch (Exception e) {
            System.err.println("Error in transit monitoring app: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    private static void startConsoleDashboard() {
        ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(() -> {
            System.out.println("\n----- TRANSIT DASHBOARD -----");
            System.out.println("Current time: " + new Date());
            
            // Get vehicle counts by route
            TransitQueries queries = new TransitQueries();
            Map<String, Integer> routeCounts = queries.getVehicleCountsByRoute();
            
            System.out.println("\nActive vehicles by route:");
            if (routeCounts.isEmpty()) {
                System.out.println("No active vehicles found in the last 5 minutes.");
            } else {
                routeCounts.entrySet().stream()
                    .sorted((e1, e2) -> e2.getValue().compareTo(e1.getValue())) // Sort by count descending
                    .forEach(entry -> 
                        System.out.println("Route " + entry.getKey() + ": " + entry.getValue() + " vehicles"));
            }
            
            System.out.println("\n----------------------------\n");
        }, 10, 10, TimeUnit.SECONDS); // Initial delay of 10 seconds, then every 10 seconds
    }
}
```

## The Application Workflow

Let's walk through what this application does:

1. **Initialization**:
   - Sets up the GTFS feed URL
   - Connects to the Ignite cluster

2. **Testing Connections**:
   - Tests the GTFS connection to ensure our data source works
   - This provides early validation before proceeding

3. **Schema Setup**:
   - Creates the necessary table in Ignite if it doesn't exist

4. **Data Ingestion**:
   - Starts the data ingestion service to fetch transit data
   - Configures it to run every 30 seconds

5. **Data Verification**:
   - Waits briefly for initial data to be ingested
   - Verifies that data is correctly stored in Ignite
   - This validation step ensures our pipeline is working end-to-end

6. **Service Monitoring**:
   - Sets up continuous queries to detect service disruptions
   - Will automatically notify when vehicles are stopped for too long

7. **Dashboard**:
   - Creates a simple console dashboard that refreshes every 10 seconds
   - Shows active vehicles by route

8. **Cleanup**:
   - Stops all services when the user ends the application
   - Closes the Ignite connection

This design provides a complete end-to-end application that demonstrates Ignite's capabilities for real-time data processing and monitoring.

## Running the Application

To run your application:

1. Ensure your Ignite cluster is running
2. Build your project with Maven:
   ```
   mvn clean package
   ```
3. Run the application:
   ```
   java -jar target/transit-monitoring-1.0.jar
   ```

If you're using the sample transit feed URL, make sure to replace `YOUR_KEY` with a valid API key. If you don't have one, the application will automatically fall back to using the bundled sample data.
