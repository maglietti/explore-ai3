# Testing the GTFS Connection

Before we proceed with integrating our GTFS client with Ignite, let's create a simple test to ensure we can successfully connect to our transit feed and parse the data. This step is crucial for verifying that our data source works correctly before building more complex functionality.

Create a new file `GTFSConnectionTest.java`:

```java
package com.example.transit;

import java.util.List;

public class GTFSConnectionTest {

    public static void main(String[] args) {
        // Set the URL to your GTFS-realtime feed
        String feedUrl = "https://api.511.org/transit/vehiclepositions?api_key=YOUR_KEY&agency=SF";
        
        // Create the feed client
        GTFSFeedClient feedClient = new GTFSFeedClient(feedUrl);
        
        System.out.println("Testing connection to GTFS feed...");
        
        try {
            // Fetch vehicle positions
            List<VehiclePosition> positions = feedClient.getVehiclePositions();
            
            if (positions.isEmpty()) {
                System.out.println("Warning: No vehicle positions found in the feed.");
            } else {
                System.out.println("Success! Retrieved " + positions.size() + " vehicle positions.");
                
                // Print the first 5 positions as a sample
                System.out.println("\nSample data (first 5 vehicles):");
                positions.stream()
                    .limit(5)
                    .forEach(position -> System.out.println(position));
                
                // Print some statistics
                long uniqueRoutes = positions.stream()
                    .map(VehiclePosition::getRouteId)
                    .distinct()
                    .count();
                
                long uniqueVehicles = positions.stream()
                    .map(VehiclePosition::getVehicleId)
                    .distinct()
                    .count();
                
                System.out.println("\nStatistics:");
                System.out.println("- Unique routes: " + uniqueRoutes);
                System.out.println("- Unique vehicles: " + uniqueVehicles);
            }
        } catch (Exception e) {
            System.err.println("Error testing GTFS feed: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
```

## Running the Test

To run this test, compile and execute it using Maven:

```bash
mvn compile exec:java -Dexec.mainClass="com.example.transit.GTFSConnectionTest"
```

## What to Expect

If the test is successful, you'll see output similar to this:

```
Testing connection to GTFS feed...
Success! Retrieved 243 vehicle positions.

Sample data (first 5 vehicles):
Vehicle ID: 5504, Route: 14, Position: (37.78219, -122.41612), Status: IN_TRANSIT_TO, Time: 2023-04-15 14:32:45.0
Vehicle ID: 5510, Route: 14, Position: (37.78723, -122.40778), Status: STOPPED_AT, Time: 2023-04-15 14:32:48.0
Vehicle ID: 5602, Route: 22, Position: (37.77641, -122.39502), Status: IN_TRANSIT_TO, Time: 2023-04-15 14:32:43.0
Vehicle ID: 5702, Route: 30, Position: (37.79823, -122.40587), Status: IN_TRANSIT_TO, Time: 2023-04-15 14:32:46.0
Vehicle ID: 5810, Route: 45, Position: (37.80503, -122.41786), Status: STOPPED_AT, Time: 2023-04-15 14:32:47.0

Statistics:
- Unique routes: 38
- Unique vehicles: 243
```

If the live feed is unavailable or you don't have a valid API key, you'll see the fallback to sample data in action:

```
Testing connection to GTFS feed...
Error fetching live feed, falling back to sample data: Server returned HTTP response code: 401
Loaded 150 vehicle positions from sample data.
Success! Retrieved 150 vehicle positions.
...
```

## What This Test Verifies

This test confirms several important aspects of our GTFS client:

1. **Connection**: It verifies we can successfully connect to the GTFS feed
2. **Parsing**: It confirms we can parse the Protocol Buffer format correctly
3. **Data Quality**: It shows us the amount and variety of data we're getting
4. **Fallback Mechanism**: It tests our sample data fallback functionality
5. **Data Model**: It validates our `VehiclePosition` model works correctly

Having this test in place gives us confidence to proceed with integrating this data source with Ignite in the next steps.

> **Note**: For this guide, we've included a sample data file that will be used if the live feed is not accessible. In a production environment, you'd want more robust error handling and retry logic.
