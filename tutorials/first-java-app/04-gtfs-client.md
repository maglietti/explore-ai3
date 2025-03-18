# Building and Testing the GTFS Client

In this module, we'll implement a client that communicates with a GTFS-realtime feed to fetch transit vehicle positions, then validate it with a test application before integrating with Apache Ignite.

## Create the GTFS Client

Let's implement a client that fetches transit data from a GTFS-realtime feed. This class will handle the connection to the feed and transform the data into our domain model.

Create `GTFSFeedClient.java`:

```java
package com.example.transit;

import com.google.transit.realtime.GtfsRealtime.FeedEntity;
import com.google.transit.realtime.GtfsRealtime.FeedMessage;
import com.google.transit.realtime.GtfsRealtime.Position;

import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

/**
 * Client for retrieving GTFS-realtime feed data.
 */
public class GTFSFeedClient {
    private final String feedUrl;

    public GTFSFeedClient(String feedUrl) {
        this.feedUrl = feedUrl;
    }

    /**
     * Retrieves vehicle positions from the GTFS feed.
     *
     * @return List of vehicle positions
     * @throws IOException if there's an error fetching or parsing the feed
     */
    public List<VehiclePosition> getVehiclePositions() throws IOException {
        List<VehiclePosition> positions = new ArrayList<>();

        // Parse feed directly from URL
        URL url = new URL(feedUrl);
        FeedMessage feed = FeedMessage.parseFrom(url.openStream());

        for (FeedEntity entity : feed.getEntityList()) {
            if (entity.hasVehicle()) {
                com.google.transit.realtime.GtfsRealtime.VehiclePosition vehicle = entity.getVehicle();

                if (vehicle.hasPosition() && vehicle.hasVehicle() && vehicle.hasTrip()) {
                    Position position = vehicle.getPosition();
                    String vehicleId = vehicle.getVehicle().getId();
                    String routeId = vehicle.getTrip().getRouteId();

                    // Map the GTFS status to our string representation
                    String status = "UNKNOWN";
                    if (vehicle.hasCurrentStatus()) {
                        switch (vehicle.getCurrentStatus()) {
                            case IN_TRANSIT_TO:
                                status = "IN_TRANSIT_TO";
                                break;
                            case STOPPED_AT:
                                status = "STOPPED_AT";
                                break;
                        }
                    }

                    // Create our vehicle position object
                    positions.add(new VehiclePosition(
                            vehicleId,
                            routeId,
                            position.getLatitude(),
                            position.getLongitude(),
                            vehicle.hasTimestamp() ? vehicle.getTimestamp() * 1000 : System.currentTimeMillis(),
                            status
                    ));
                }
            }
        }

        System.out.println("Fetched " + positions.size() + " vehicle positions from feed");

        return positions;
    }
}
```

## Obtaining a 511.org API Token

To access the GTFS-realtime feed for the San Francisco Bay Area, you'll need an API token from 511.org:

1. Visit <https://511.org/open-data/token>
2. Complete the registration form
3. Submit the form
4. Save the API token that's emailed to you

## Configure Environment Variables

For API token management, we'll use the `dotenv-java` library for environment variable handling.

Add this dependency to the `pom.xml`:

```xml
<!-- Environment -->
<dependency>
    <groupId>io.github.cdimascio</groupId>
    <artifactId>dotenv-java</artifactId>
    <version>2.3.2</version>
</dependency>
```

Create a file named `.env` in the root of your project:

```conf
# 511.org API token - get yours at https://511.org/open-data/token
API_TOKEN=your_token_here

# GTFS Feed URL
GTFS_BASE_URL=https://api.511.org/transit/vehiclepositions

# GTFS Agency - default is San Francisco Muni
GTFS_AGENCY=SF
```

Save the file to `.env` and replace `your_token_here` with your actual API token.

## Create a Test Application

Let's validate our GTFS client with a test application before integrating with Ignite.

Create `GTFSConnectionTest.java`:

```java
package com.example.transit;

import io.github.cdimascio.dotenv.Dotenv;

import java.io.IOException;
import java.util.List;

/**
 * Test class to verify the GTFS connection and data parsing.
 * Demonstrates fetching and analyzing real-time vehicle positions.
 */
public class GTFSConnectionTest {

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

        System.out.println("Using GTFS feed URL: " + feedUrl);

        // Create the feed client and test it
        GTFSFeedClient feedClient = new GTFSFeedClient(feedUrl);

        try {
            // Fetch vehicle positions
            List<VehiclePosition> positions = feedClient.getVehiclePositions();

            if (positions.isEmpty()) {
                System.out.println("Warning: No vehicle positions found in the feed.");
                return;
            }

            System.out.println("Success! Retrieved " + positions.size() + " vehicle positions.");

            // Print the first 5 positions as a sample
            System.out.println("\nSample data (first 5 vehicles):");
            positions.stream()
                    .limit(5)
                    .forEach(System.out::println);

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

        } catch (IOException e) {
            System.err.println("Error testing GTFS feed: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
```

## Run the Test

Execute the test to validate the GTFS client:

```bash
mvn compile exec:java -Dexec.mainClass="com.example.transit.GTFSConnectionTest"
```

Successful execution will produce output similar to:

``` text
Using GTFS feed URL: https://api.511.org/transit/vehiclepositions?api_key=a1b2c3d4-5e6f-7g8h-9i0j-k1l2m3n4o5p6&agency=SF
Fetched 540 vehicle positions from feed
Success! Retrieved 540 vehicle positions.

Sample data (first 5 vehicles):
Vehicle ID: 1050, Route: F, Position: (37.7687873840332, -122.42732238769531), Status: STOPPED_AT, Time: 2025-03-18 10:53:23.0
Vehicle ID: 1051, Route: F, Position: (37.782012939453125, -122.41065979003906), Status: STOPPED_AT, Time: 2025-03-18 10:53:23.0
Vehicle ID: 1052, Route: F, Position: (37.72022247314453, -122.44660949707031), Status: IN_TRANSIT_TO, Time: 2025-03-18 10:53:23.0
Vehicle ID: 1058, Route: F, Position: (37.80823516845703, -122.416015625), Status: IN_TRANSIT_TO, Time: 2025-03-18 10:53:23.0
Vehicle ID: 1059, Route: F, Position: (37.792911529541016, -122.3965835571289), Status: STOPPED_AT, Time: 2025-03-18 10:53:23.0

Statistics:
- Unique routes: 58
- Unique vehicles: 540
```

## Troubleshooting

If you encounter issues:

- Verify your API token is correctly configured in the `.env` file
- Ensure the feed URL is properly constructed
- Check network connectivity to the GTFS endpoint
- Verify the protobuf dependencies are correctly installed

In the next module, we'll integrate this client with Apache Ignite to store and analyze the vehicle position data.
