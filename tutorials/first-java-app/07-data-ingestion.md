# Building the Data Ingestion Service

Now that we can fetch transit data, let's create a service to regularly retrieve and store it in Ignite. This service will run on a scheduled interval, fetching the latest vehicle positions and storing them in our Ignite table.

Create a file `DataIngestionService.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlParametersBatch;

import java.sql.Timestamp;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

public class DataIngestionService {
    private final GTFSFeedClient feedClient;
    private final IgniteClient igniteClient;
    private final ScheduledExecutorService scheduler;
    private ScheduledFuture<?> scheduledTask;
    
    public DataIngestionService(String feedUrl) {
        this.feedClient = new GTFSFeedClient(feedUrl);
        this.igniteClient = IgniteConnection.getClient();
        this.scheduler = Executors.newSingleThreadScheduledExecutor();
    }
    
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
    
    public void stop() {
        if (scheduledTask != null) {
            scheduledTask.cancel(true);
            scheduler.shutdown();
            System.out.println("Data ingestion service stopped");
        }
    }
    
    private void fetchAndStoreData() {
        try {
            List<VehiclePosition> positions = feedClient.getVehiclePositions();
            storeVehiclePositions(positions);
            System.out.println("Fetched and stored " + positions.size() + " vehicle positions");
        } catch (Exception e) {
            System.err.println("Error in data ingestion: " + e.getMessage());
        }
    }
    
    private void storeVehiclePositions(List<VehiclePosition> positions) {
        if (positions.isEmpty()) {
            return;
        }
        
        SqlClientSession sqlSession = igniteClient.sql();
        
        for (VehiclePosition position : positions) {
            try {
                String insertSql = "INSERT INTO vehicle_positions "
                    + "(vehicle_id, route_id, latitude, longitude, timestamp, current_status) "
                    + "VALUES (?, ?, ?, ?, ?, ?)";
                
                SqlParametersBatch batch = sqlSession.prepareNativeBatch(insertSql);
                
                batch.addBatch(
                    position.getVehicleId(),
                    position.getRouteId(),
                    position.getLatitude(),
                    position.getLongitude(),
                    new Timestamp(position.getTimestamp()),
                    position.getCurrentStatus()
                );
                
                batch.execute();
            } catch (Exception e) {
                System.err.println("Error storing vehicle position: " + e.getMessage());
            }
        }
    }
}
```

## Key Features of the Data Ingestion Service

This service has several important characteristics:

1. **Scheduled Execution**: Using Java's `ScheduledExecutorService`, it periodically fetches and stores data at a configurable interval.

2. **Batch Inserts**: It uses Ignite's batch insert capabilities for efficient data storage, which is much more efficient than individual inserts.

3. **Error Handling**: It includes basic error handling to ensure that temporary issues don't crash the service.

4. **Clean Lifecycle**: The service can be started and stopped cleanly, with proper resource cleanup.

By encapsulating this functionality in a dedicated service class, we maintain a clean separation of concerns in our application. The `DataIngestionService` is responsible solely for keeping our Ignite table updated with the latest transit data.

In a more advanced implementation, we might add features like:

- Retry logic for failed fetches or inserts
- Throttling to handle very frequent updates
- Deduplication to avoid storing duplicate positions
- Backpressure handling for high-volume feeds

However, for our 40-minute guide, this implementation strikes a good balance between functionality and simplicity.
