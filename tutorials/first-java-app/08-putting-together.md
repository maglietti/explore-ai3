# Putting It All Together

In this final section, we'll create our main application class that orchestrates all the components we've built. Then we'll explore how to test and verify our system is working correctly with Ignite SQL.

## Creating the Main Application

The `TransitMonitoringApp` class will be our application's entry point, bringing together all the components we've developed.

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import io.github.cdimascio.dotenv.Dotenv;

import java.util.Date;
import java.util.Scanner;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class TransitMonitoringApp {
    public static void main(String[] args) {
        System.out.println("Starting Transit Monitoring Application with Ignite 3.0");
        
        // Load environment variables from .env file
        Dotenv dotenv = Dotenv.configure().ignoreIfMissing().load();
        
        // Retrieve configuration values
        String apiToken = dotenv.get("API_TOKEN");
        String baseUrl = dotenv.get("GTFS_BASE_URL");
        String agency = dotenv.get("GTFS_AGENCY");
        
        // Validate configuration
        if (apiToken == null || baseUrl == null || agency == null) {
            System.err.println("Missing configuration. Please check your .env file.");
            System.err.println("Required variables: API_TOKEN, GTFS_BASE_URL, GTFS_AGENCY");
            return;
        }
        
        // Construct the full feed URL
        String feedUrl = String.format("%s?api_key=%s&agency=%s", baseUrl, apiToken, agency);
        System.out.println("Using GTFS feed URL: " + feedUrl);
        
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
            monitor.startMonitoring(60); // Check every 60 seconds
            
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
            monitor.stopMonitoring();
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
            
            // Get the Ignite client
            IgniteClient client = IgniteConnection.getClient();
            
            try {
                // Query to get vehicle counts by route for active vehicles
                String routeCountSql = 
                    "SELECT route_id, COUNT(DISTINCT vehicle_id) as vehicle_count " +
                    "FROM vehicle_positions " +
                    "WHERE TIMESTAMPDIFF(MINUTE, time_stamp, CURRENT_TIMESTAMP) <= 5 " +
                    "GROUP BY route_id " +
                    "ORDER BY vehicle_count DESC";
                
                var resultSet = client.sql().execute(null, routeCountSql);
                
                System.out.println("\nActive vehicles by route (last 5 minutes):");
                boolean hasData = false;
                
                while (resultSet.hasNext()) {
                    hasData = true;
                    var row = resultSet.next();
                    String routeId = row.stringValue("route_id");
                    int count = (int) row.longValue("vehicle_count");
                    System.out.println("Route " + routeId + ": " + count + " vehicles");
                }
                
                if (!hasData) {
                    System.out.println("No active vehicles found in the last 5 minutes.");
                }
                
                // Optional: Get total vehicle count
                var totalResult = client.sql().execute(null, 
                        "SELECT COUNT(DISTINCT vehicle_id) as total FROM vehicle_positions");
                
                if (totalResult.hasNext()) {
                    System.out.println("\nTotal unique vehicles tracked: " + 
                            totalResult.next().longValue("total"));
                }
                
            } catch (Exception e) {
                System.err.println("Error updating dashboard: " + e.getMessage());
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
   - Connects to the Ignite cluster using our `IgniteConnection` singleton

2. **Testing Connections**:
   - Tests the GTFS connection to ensure our data source works
   - This provides early validation before proceeding

3. **Schema Setup**:
   - Creates the necessary table in Ignite using our `SchemaSetup` class
   - Uses Ignite's Catalog API for type-safe table creation

4. **Data Ingestion**:
   - Starts the data ingestion service to fetch transit data every 30 seconds
   - Our `DataIngestionService` handles batched inserts for efficiency

5. **Data Verification**:
   - Waits briefly for initial data to be ingested
   - Uses `DataVerifier` to confirm data is correctly stored in Ignite

6. **Service Monitoring**:
   - Sets up monitoring to detect service disruptions
   - The `ServiceMonitor` tracks vehicles stopped for too long

7. **Dashboard**:
   - Creates a simple console dashboard refreshing every 10 seconds
   - Shows active vehicles by route using our query methods

8. **Cleanup**:
   - Stops all services when the user ends the application
   - Properly closes the Ignite connection

## Testing with Ignite SQL

While our application is running, we can interact directly with the data in Ignite using SQL. This helps with debugging, verification, and ad-hoc analysis.

### Using the Ignite CLI

The Ignite CLI provides a convenient way to run SQL queries against your Ignite cluster:

1. Open a new terminal window
2. Navigate to your Ignite installation directory
3. Run the Ignite CLI tool:
   ```
   bin/ignite --client
   ```
4. Connect to your node:
   ```
   connect 127.0.0.1:10800
   ```
5. Run SQL queries:
   ```
   sql> SELECT * FROM vehicle_positions LIMIT 5;
   ```

### Useful Verification Queries

Here are some SQL queries that will help you verify your transit data:

#### Count total vehicle positions
```sql
SELECT COUNT(*) FROM vehicle_positions;
```

#### See active vehicles by route
```sql
SELECT route_id, COUNT(DISTINCT vehicle_id) as vehicle_count
FROM vehicle_positions 
GROUP BY route_id
ORDER BY vehicle_count DESC;
```

#### Find the latest position for each vehicle
```sql
WITH latest_positions AS (
  SELECT vehicle_id, MAX(time_stamp) as latest_ts
  FROM vehicle_positions
  GROUP BY vehicle_id
)
SELECT v.vehicle_id, v.route_id, v.latitude, v.longitude, 
       v.current_status, v.time_stamp
FROM vehicle_positions v
JOIN latest_positions l 
  ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts;
```

#### Check for delayed vehicles
```sql
SELECT v.vehicle_id, v.route_id, v.current_status, v.time_stamp,
       TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as minutes_delayed
FROM vehicle_positions v
JOIN (
  SELECT vehicle_id, MAX(time_stamp) as latest_ts
  FROM vehicle_positions
  GROUP BY vehicle_id
) latest ON v.vehicle_id = latest.vehicle_id AND v.time_stamp = latest.latest_ts
WHERE v.current_status = 'STOPPED_AT'
AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) > 5;
```

#### Get hourly vehicle count statistics
```sql
SELECT 
  HOUR(time_stamp) as hour_of_day, 
  COUNT(DISTINCT vehicle_id) as vehicle_count
FROM vehicle_positions
GROUP BY HOUR(time_stamp)
ORDER BY hour_of_day;
```

### Understanding the Results

The results from these queries tell you a lot about your transit data:

1. **Total count**: Shows how much data you've collected
2. **Active vehicles by route**: Identifies which routes have the most vehicles
3. **Latest positions**: Shows the current location of each vehicle
4. **Delayed vehicles**: Identifies potential service disruptions
5. **Hourly statistics**: Shows how vehicle counts change throughout the day

These queries showcase some of Ignite's SQL capabilities, including:
- Time-based functions (`TIMESTAMPDIFF`, `CURRENT_TIMESTAMP`, `HOUR`)
- Common Table Expressions (`WITH` clauses)
- Aggregations (`COUNT`, `GROUP BY`)
- Joins and subqueries

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

If you're using the sample transit feed URL, make sure to replace `YOUR_KEY` with a valid API key. If you don't have one, consider implementing a fallback to sample data in your `GTFSFeedClient`.

## Troubleshooting

If you encounter issues:

1. **Connection problems**: Verify your Ignite cluster is running with `bin/ignite --status`
2. **Schema errors**: Check column types and names match between your Java code and database
3. **Empty data**: Ensure your GTFS feed URL is correct and accessible
4. **Query errors**: Verify SQL syntax against Ignite's supported dialect

Reviewing the logs in both your application and the Ignite server can provide valuable diagnostic information.