# Implementing the GTFS Client

Now let's create the client that will fetch transit data from a GTFS-realtime feed. We'll implement a wrapper around the OneBusAway library that handles connection issues and provides fallback to sample data if needed.

Create a file `GTFSFeedClient.java`:

```java
package com.gridgain.transit;

import com.google.transit.realtime.GtfsRealtime.FeedEntity;
import com.google.transit.realtime.GtfsRealtime.FeedMessage;
import com.google.transit.realtime.GtfsRealtime.Position;
import com.google.transit.realtime.GtfsRealtime.VehiclePosition.VehicleStopStatus;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

public class GTFSFeedClient {
    private final String feedUrl;
    
    public GTFSFeedClient(String feedUrl) {
        this.feedUrl = feedUrl;
    }
    
    public List<VehiclePosition> getVehiclePositions() {
        List<VehiclePosition> positions = new ArrayList<>();
        
        try {
            // Try to fetch from the live feed
            FeedMessage feed = fetchFeed();
            
            for (FeedEntity entity : feed.getEntityList()) {
                if (entity.hasVehicle()) {
                    com.google.transit.realtime.GtfsRealtime.VehiclePosition vehicle = entity.getVehicle();
                    
                    if (vehicle.hasPosition() && vehicle.hasVehicle() && vehicle.hasTrip()) {
                        Position position = vehicle.getPosition();
                        String vehicleId = vehicle.getVehicle().getId();
                        String routeId = vehicle.getTrip().getRouteId();
                        
                        // Map the GTFS status to our string representation
                        String status;
                        if (vehicle.hasCurrentStatus()) {
                            switch (vehicle.getCurrentStatus()) {
                                case IN_TRANSIT_TO:
                                    status = "IN_TRANSIT_TO";
                                    break;
                                case STOPPED_AT:
                                    status = "STOPPED_AT";
                                    break;
                                default:
                                    status = "UNKNOWN";
                            }
                        } else {
                            status = "UNKNOWN";
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
            
            System.out.println("Fetched " + positions.size() + " vehicle positions from live feed");
            
        } catch (Exception e) {
            System.err.println("Error fetching live feed, falling back to sample data: " + e.getMessage());
            positions = loadSampleData();
        }
        
        return positions;
    }
    
    private FeedMessage fetchFeed() throws IOException {
        URL url = new URL(feedUrl);
        try (InputStream in = url.openStream()) {
            return FeedMessage.parseFrom(in);
        }
    }
    
    private List<VehiclePosition> loadSampleData() {
        List<VehiclePosition> positions = new ArrayList<>();
        
        try (InputStream in = getClass().getResourceAsStream("/sample-vehicle-positions.pb")) {
            if (in == null) {
                System.err.println("Sample data file not found");
                return positions;
            }
            
            FeedMessage feed = FeedMessage.parseFrom(in);
            
            for (FeedEntity entity : feed.getEntityList()) {
                if (entity.hasVehicle()) {
                    com.google.transit.realtime.GtfsRealtime.VehiclePosition vehicle = entity.getVehicle();
                    
                    if (vehicle.hasPosition() && vehicle.hasVehicle() && vehicle.hasTrip()) {
                        Position position = vehicle.getPosition();
                        String vehicleId = vehicle.getVehicle().getId();
                        String routeId = vehicle.getTrip().getRouteId();
                        
                        // Map status as before
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
            
            System.out.println("Loaded " + positions.size() + " vehicle positions from sample data");
            
        } catch (Exception e) {
            System.err.println("Error loading sample data: " + e.getMessage());
        }
        
        return positions;
    }
}
```

The `GTFSFeedClient` class has several important features:

1. **Live Data Fetching**: It attempts to connect to a GTFS-realtime feed URL and parse the Protocol Buffer format.
2. **Sample Data Fallback**: If the live feed isn't available, it loads sample data from a bundled resource file.
3. **Data Transformation**: It converts the GTFS-specific data structures into our application's `VehiclePosition` model.
4. **Error Handling**: It gracefully handles connection issues and parsing problems.

This design makes our application robust even in offline or unstable network conditions, which is essential for a monitoring system.
