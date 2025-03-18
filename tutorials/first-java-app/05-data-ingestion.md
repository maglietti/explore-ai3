# Building the Data Ingestion Service

In this module, we'll implement a robust data ingestion service for our transit monitoring application. This service will regularly fetch transit data from our GTFS feed and store it in Apache Ignite, forming the backbone of our real-time monitoring system.

## Understanding Data Ingestion Requirements

For a real-time transit monitoring system, we need to:

1. Periodically fetch the latest vehicle positions
2. Efficiently store them in our Ignite database
3. Handle errors gracefully to ensure continuous operation
4. Provide a clean service lifecycle (start/stop)

Our implementation will use a scheduled execution approach with proper resource management and error isolation.

## Implementing the DataIngestionService

Let's create a `DataIngestionService.java` file:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlParametersBatch;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/**
 * Service responsible for periodically fetching transit data and storing it in Ignite.
 * Implements a resilient data ingestion pipeline with configurable scheduling.
 */
public class DataIngestionService {
    private final GTFSFeedClient feedClient;
    private final IgniteClient igniteClient;
    private final ScheduledExecutorService scheduler;
    private ScheduledFuture<?> scheduledTask;
    private int batchSize = 100; // Default batch size
    
    /**
     * Constructs a new data ingestion service.
     * 
     * @param feedUrl The URL of the GTFS realtime feed
     */
    public DataIngestionService(String feedUrl) {
        this.feedClient = new GTFSFeedClient(feedUrl);
        this.igniteClient = IgniteConnection.getClient();
        this.scheduler = Executors.newSingleThreadScheduledExecutor();
    }
    
    /**
     * Sets the batch size for database operations.
     * 
     * @param batchSize Number of records to process in each batch
     * @return This DataIngestionService instance for method chaining
     */
    public DataIngestionService withBatchSize(int batchSize) {
        this.batchSize = batchSize;
        return this;
    }
    
    /**
     * Starts the data ingestion service with the specified interval.
     * 
     * @param intervalSeconds The interval between data fetches in seconds
     */
    public void start(int intervalSeconds) {
        scheduledTask = scheduler.scheduleAtFixedRate(
            this::fetchAndStoreData,
            0,
            intervalSeconds,
            TimeUnit.SECONDS
        );
        System.out.println("Data ingestion service started with " 
            + intervalSeconds + " second interval");
    }
    
    /**
     * Stops the data ingestion service and cleans up resources.
     */
    public void stop() {
        if (scheduledTask != null) {
            scheduledTask.cancel(true);
            scheduler.shutdown();
            System.out.println("Data ingestion service stopped");
        }
    }
    
    /**
     * Fetches data from the GTFS feed and stores it in Ignite.
     * This method is called periodically by the scheduler.
     */
    private void fetchAndStoreData() {
        try {
            List<VehiclePosition> positions = feedClient.getVehiclePositions();
            
            if (!positions.isEmpty()) {
                int recordsStored = storeVehiclePositions(positions);
                System.out.println("Fetched " + positions.size() + 
                                  " and stored " + recordsStored + 
                                  " vehicle positions");
            } else {
                System.out.println("No vehicle positions fetched from feed");
            }
        } catch (Exception e) {
            System.err.println("Error in data ingestion: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Stores vehicle positions in Ignite using efficient batch processing.
     * 
     * @param positions List of vehicle positions to store
     * @return Number of records successfully stored
     */
    private int storeVehiclePositions(List<VehiclePosition> positions) {
        if (positions.isEmpty()) {
            return 0;
        }
        
        SqlClientSession sqlSession = igniteClient.sql();
        int recordsProcessed = 0;
        
        try {
            String insertSql = "INSERT INTO vehicle_positions "
                + "(vehicle_id, route_id, latitude, longitude, time_stamp, current_status) "
                + "VALUES (?, ?, ?, ?, ?, ?)";
            
            SqlParametersBatch batch = sqlSession.prepareNativeBatch(insertSql);
            
            for (int i = 0; i < positions.size(); i++) {
                VehiclePosition position = positions.get(i);
                
                // Convert epoch milliseconds to LocalDateTime for Ignite
                LocalDateTime timestamp = LocalDateTime.ofInstant(
                    position.getTimestampAsInstant(), 
                    ZoneId.systemDefault()
                );
                
                batch.addBatch(
                    position.getVehicleId(),
                    position.getRouteId(),
                    position.getLatitude(),
                    position.getLongitude(),
                    timestamp,
                    position.getCurrentStatus()
                );
                
                // Execute batch when reaching batch size or end of list
                if ((i + 1) % batchSize == 0 || i == positions.size() - 1) {
                    batch.execute();
                    recordsProcessed += batch.size();
                    batch = sqlSession.prepareNativeBatch(insertSql);
                }
            }
            
            return recordsProcessed;
            
        } catch (Exception e) {
            System.err.println("Error storing vehicle positions: " + e.getMessage());
            e.printStackTrace();
            return recordsProcessed;
        }
    }
}
```

## Data Verification Utility

To ensure our data ingestion pipeline is working correctly, let's also create a verification utility that can check and analyze the data stored in Ignite:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlResultCursor;
import org.apache.ignite.client.SqlRow;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Utility class for verifying and examining data in the Ignite database.
 */
public class DataVerifier {
    
    private static final DateTimeFormatter DATETIME_FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    /**
     * Verifies the existence and integrity of vehicle position data in Ignite.
     */
    public static boolean verifyData() {
        IgniteClient client = null;
        
        try {
            client = IgniteConnection.getClient();
            SqlClientSession sqlSession = client.sql();
            
            System.out.println("Verifying data in vehicle_positions table...");
            
            // Check if table exists and has data
            String countSql = "SELECT COUNT(*) as count FROM vehicle_positions";
            SqlResultCursor cursor = sqlSession.execute(countSql);
            
            if (cursor.hasNext()) {
                SqlRow row = cursor.next();
                long count = row.getLong("count");
                
                System.out.println("Table exists");
                System.out.println("Table contains " + count + " records");
                
                if (count > 0) {
                    // Sample some data
                    String sampleSql = "SELECT * FROM vehicle_positions ORDER BY time_stamp DESC LIMIT 3";
                    cursor = sqlSession.execute(sampleSql);
                    
                    System.out.println("\nSample records (most recent):");
                    while (cursor.hasNext()) {
                        SqlRow record = cursor.next();
                        LocalDateTime timestamp = record.getTimestamp("time_stamp");
                        
                        System.out.println("Vehicle: " + record.getString("vehicle_id") + 
                                          ", Route: " + record.getString("route_id") +
                                          ", Status: " + record.getString("current_status") +
                                          ", Time: " + timestamp.format(DATETIME_FORMATTER));
                    }
                    
                    // Get route statistics
                    String routeStatsSql = "SELECT route_id, COUNT(*) as record_count " +
                                         "FROM vehicle_positions " +
                                         "GROUP BY route_id " +
                                         "ORDER BY record_count DESC " +
                                         "LIMIT 5";
                    
                    cursor = sqlSession.execute(routeStatsSql);
                    
                    System.out.println("\nTop routes by number of records:");
                    while (cursor.hasNext()) {
                        SqlRow record = cursor.next();
                        System.out.println("Route " + record.getString("route_id") + 
                                          ": " + record.getLong("record_count") + " records");
                    }
                    
                    System.out.println("\nVerification complete - data exists in Ignite");
                    return true;
                } else {
                    System.out.println("Table is empty. Let's start the ingestion service to load some data.");
                    return true;
                }
            }
            
            System.err.println("Error checking the table");
            return false;
            
        } catch (Exception e) {
            System.err.println("Error verifying data: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
}
```

## Key Technical Features

Our data ingestion implementation has several important features:

### Scheduled Execution

The service uses Java's `ScheduledExecutorService` to fetch data at configurable intervals. This approach ensures we maintain a consistent, up-to-date view of transit operations.

```java
scheduledTask = scheduler.scheduleAtFixedRate(
    this::fetchAndStoreData,
    0,
    intervalSeconds,
    TimeUnit.SECONDS
);
```

### Efficient Batch Processing

Rather than inserting records one at a time, we use Ignite's batch processing capabilities to improve efficiency:

```java
SqlParametersBatch batch = sqlSession.prepareNativeBatch(insertSql);
// ... add multiple records to batch ...
batch.execute();
```

This approach significantly reduces network overhead and improves insertion throughput.

### Error Isolation

Errors during data fetching or storage are contained within the scheduled task, ensuring that temporary failures don't crash the service:

```java
try {
    // ... fetch and store data ...
} catch (Exception e) {
    System.err.println("Error in data ingestion: " + e.getMessage());
    e.printStackTrace();
}
```

### Resource Management

The service provides a clean lifecycle with proper resource cleanup:

```java
public void stop() {
    if (scheduledTask != null) {
        scheduledTask.cancel(true);
        scheduler.shutdown();
        System.out.println("Data ingestion service stopped");
    }
}
```

## Testing Your Implementation

Let's create a simple test to verify our data ingestion service. Create a new file `DataIngestionTest.java`:

```java
package com.example.transit;

import io.github.cdimascio.dotenv.Dotenv;

/**
 * Test class for the data ingestion service.
 */
public class DataIngestionTest {

    public static void main(String[] args) {
        // Load environment variables from .env file
        Dotenv dotenv = Dotenv.configure().ignoreIfMissing().load();

        // Retrieve configuration values
        String apiToken = dotenv.get("API_TOKEN");
        String baseUrl = dotenv.get("GTFS_BASE_URL");
        String agency = dotenv.get("GTFS_AGENCY");

        // Validate configuration
        if (apiToken == null || baseUrl == null || agency == null) {
            System.err.println("Missing configuration. Please check your .env file.");
            return;
        }

        // Construct the full feed URL
        String feedUrl = String.format("%s?api_key=%s&agency=%s", baseUrl, apiToken, agency);

        try {
            // Create and start the schema
            SchemaSetup schemaSetup = new SchemaSetup();
            boolean schemaCreated = schemaSetup.createSchema();
            
            if (!schemaCreated) {
                System.err.println("Failed to create schema. Aborting test.");
                return;
            }
            
            // Verify initial state (should be empty)
            System.out.println("\n--- Initial data state ---");
            DataVerifier.verifyData();
            
            // Create and start the data ingestion service
            System.out.println("\n--- Starting data ingestion service ---");
            DataIngestionService ingestService = new DataIngestionService(feedUrl);
            ingestService.start(30); // Fetch every 30 seconds
            
            // Wait for some data to be ingested
            System.out.println("\nWaiting for data ingestion...");
            Thread.sleep(40000); // Wait a bit longer than the fetch interval
            
            // Verify data after ingestion
            System.out.println("\n--- Data state after ingestion ---");
            DataVerifier.verifyData();
            
            // Stop the ingestion service
            System.out.println("\n--- Stopping data ingestion service ---");
            ingestService.stop();
            
            System.out.println("\nTest completed successfully!");
            
        } catch (Exception e) {
            System.err.println("Error during test: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Clean up connection
            IgniteConnection.close();
        }
    }
}
```

Run this test to verify that your data ingestion service is working correctly. You should see:

1. An initial empty state verification
2. The service starting and fetching data
3. A verification showing data has been ingested
4. The service shutting down cleanly

## Performance Considerations

When deploying your ingestion service in a production environment, consider these factors:

1. **Fetch Interval**: Choose an interval that balances data freshness with system load. Typically, 15-60 seconds is appropriate for transit data.

2. **Batch Size**: The default batch size of 100 works well for most cases, but you might tune this based on the size of your transit system.

3. **Error Handling**: Our implementation provides basic error handling. For production, consider adding more sophisticated retry logic or monitoring.

4. **Memory Usage**: Be mindful of memory usage when dealing with large transit systems. Consider implementing pagination for massive datasets.

## Next Steps

Now that you've implemented your data ingestion service, you can:

1. Experiment with different fetch intervals to see how they affect data freshness
2. Modify the verification utility to display additional statistics
3. Implement more sophisticated error handling or monitoring

In the next section, we'll build on this foundation to implement meaningful queries against our transit data.