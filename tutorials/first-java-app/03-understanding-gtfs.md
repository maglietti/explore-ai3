# Understanding GTFS Data

Before diving into the code, let's understand the data format we'll be working with. The General Transit Feed Specification (GTFS) is a standardized format used by transit agencies worldwide to share their public transportation schedules and geographic information.

GTFS comes in two flavors:
- **GTFS Static**: Contains scheduled service information like routes, stops, and timetables
- **GTFS Realtime**: Provides real-time updates including vehicle positions, service alerts, and trip updates

We'll be focusing on **GTFS Realtime** for this guide, specifically the vehicle positions feed. This feed provides the current location, route, and status of transit vehicles in operation.

The OneBusAway GTFS-realtime library simplifies working with this data format, allowing us to parse the Protocol Buffer format and extract the information we need.

Here's what a typical vehicle position entry contains:
- **Vehicle ID**: A unique identifier for the transit vehicle
- **Route ID**: The route the vehicle is currently servicing
- **Position**: The latitude and longitude coordinates
- **Timestamp**: When the position was recorded
- **Current Status**: The operational status (e.g., in transit, stopped at station)

Let's model this data for our application by creating a `VehiclePosition.java` class:

```java
package com.gridgain.transit;

import java.sql.Timestamp;

public class VehiclePosition {
    private String vehicleId;
    private String routeId;
    private double latitude;
    private double longitude;
    private long timestamp;
    private String currentStatus;
    
    public VehiclePosition(String vehicleId, String routeId, double latitude, 
                          double longitude, long timestamp, String currentStatus) {
        this.vehicleId = vehicleId;
        this.routeId = routeId;
        this.latitude = latitude;
        this.longitude = longitude;
        this.timestamp = timestamp;
        this.currentStatus = currentStatus;
    }
    
    // Getters
    public String getVehicleId() { return vehicleId; }
    public String getRouteId() { return routeId; }
    public double getLatitude() { return latitude; }
    public double getLongitude() { return longitude; }
    public long getTimestamp() { return timestamp; }
    public String getCurrentStatus() { return currentStatus; }
    
    @Override
    public String toString() {
        return "Vehicle ID: " + vehicleId +
               ", Route: " + routeId +
               ", Position: (" + latitude + ", " + longitude + ")" +
               ", Status: " + currentStatus +
               ", Time: " + new Timestamp(timestamp);
    }
}
```

This simple data model captures all the essential information we need from the GTFS feed, making it easy to work with in our Java application.
