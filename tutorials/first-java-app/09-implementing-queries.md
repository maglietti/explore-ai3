# Implementing Basic Queries

Now that we've verified our data is correctly stored in Ignite, let's implement some useful queries to extract insights. These queries will showcase Ignite's SQL capabilities and provide valuable information for our transit monitoring system.

Create a file `TransitQueries.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlParameters;
import org.apache.ignite.client.SqlResultCursor;
import org.apache.ignite.client.SqlRow;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class TransitQueries {
    /**
     * Find all vehicles currently operating on a specific route
     */
    public List<VehiclePosition> findVehiclesByRoute(String routeId) {
        List<VehiclePosition> vehicles = new ArrayList<>();
        IgniteClient client = IgniteConnection.getClient();
        SqlClientSession sqlSession = client.sql();
        
        String querySql = "SELECT DISTINCT ON (vehicle_id) "
            + "vehicle_id, route_id, latitude, longitude, timestamp, current_status "
            + "FROM vehicle_positions "
            + "WHERE route_id = ? "
            + "ORDER BY vehicle_id, timestamp DESC";
        
        try (SqlParameters params = sqlSession.prepareNative(querySql)
            .addParameter(routeId);
             SqlResultCursor cursor = params.execute()) {
            
            while (cursor.hasNext()) {
                SqlRow row = cursor.next();
                VehiclePosition vehicle = new VehiclePosition(
                    row.getString("vehicle_id"),
                    row.getString("route_id"),
                    row.getDouble("latitude"),
                    row.getDouble("longitude"),
                    row.getTimestamp("timestamp").getTime(),
                    row.getString("current_status")
                );
                vehicles.add(vehicle);
            }
        } catch (Exception e) {
            System.err.println("Error querying vehicles by route: " + e.getMessage());
        }
        
        return vehicles;
    }
    
    /**
     * Find the vehicles nearest to a specific geographic location
     */
    public List<VehiclePosition> findNearestVehicles(double lat, double lon, int limit) {
        List<VehiclePosition> vehicles = new ArrayList<>();
        IgniteClient client = IgniteConnection.getClient();
        SqlClientSession sqlSession = client.sql();
        
        // Using Euclidean distance as a simple approximation
        // In a production app, you'd use a proper geospatial function
        String querySql = "SELECT DISTINCT ON (vehicle_id) "
            + "vehicle_id, route_id, latitude, longitude, timestamp, current_status, "
            + "SQRT(POWER(latitude - ?, 2) + POWER(longitude - ?, 2)) as distance "
            + "FROM vehicle_positions "
            + "ORDER BY vehicle_id, timestamp DESC, distance ASC "
            + "LIMIT ?";
        
        try (SqlParameters params = sqlSession.prepareNative(querySql)
            .addParameter(lat)
            .addParameter(lon)
            .addParameter(limit);
             SqlResultCursor cursor = params.execute()) {
            
            while (cursor.hasNext()) {
                SqlRow row = cursor.next();
                VehiclePosition vehicle = new VehiclePosition(
                    row.getString("vehicle_id"),
                    row.getString("route_id"),
                    row.getDouble("latitude"),
                    row.getDouble("longitude"),
                    row.getTimestamp("timestamp").getTime(),
                    row.getString("current_status")
                );
                vehicles.add(vehicle);
            }
        } catch (Exception e) {
            System.err.println("Error querying nearest vehicles: " + e.getMessage());
        }
        
        return vehicles;
    }
    
    /**
     * Get a count of active vehicles by route
     */
    public Map<String, Integer> getVehicleCountsByRoute() {
        Map<String, Integer> routeCounts = new HashMap<>();
        IgniteClient client = IgniteConnection.getClient();
        SqlClientSession sqlSession = client.sql();
        
        String querySql = "SELECT route_id, COUNT(DISTINCT vehicle_id) as vehicle_count "
            + "FROM ("
            + "  SELECT DISTINCT ON (vehicle_id) "
            + "    vehicle_id, route_id "
            + "  FROM vehicle_positions "
            + "  WHERE timestamp > ? "
            + "  ORDER BY vehicle_id, timestamp DESC"
            + ") AS latest_positions "
            + "GROUP BY route_id";
        
        // Only count vehicles with positions in the last 5 minutes
        long cutoffTime = System.currentTimeMillis() - (5 * 60 * 1000);
        
        try (SqlParameters params = sqlSession.prepareNative(querySql)
            .addParameter(new Timestamp(cutoffTime));
             SqlResultCursor cursor = params.execute()) {
            
            while (cursor.hasNext()) {
                SqlRow row = cursor.next();
                routeCounts.put(
                    row.getString("route_id"),
                    row.getInt("vehicle_count")
                );
            }
        } catch (Exception e) {
            System.err.println("Error getting vehicle counts: " + e.getMessage());
        }
        
        return routeCounts;
    }
}
```

## Understanding These Queries

Let's examine what each of these queries does:

### 1. Finding Vehicles by Route

The `findVehiclesByRoute` method retrieves all vehicles currently operating on a specific route. Key features:

- Uses `DISTINCT ON (vehicle_id)` to get only the most recent position for each vehicle
- Sorts by `timestamp DESC` to ensure we get the latest position
- Uses parameterized queries for security and performance
- Returns a list of `VehiclePosition` objects for easy consumption by other parts of the application

### 2. Finding Nearest Vehicles

The `findNearestVehicles` method finds vehicles closest to a given geographic point. Key features:

- Calculates distance using a simple Euclidean formula (in a production app, you'd use a proper geospatial function)
- Orders results by distance, showing closest vehicles first
- Limits the number of results to prevent excessive data transfer
- Again uses `DISTINCT ON` to ensure we only get the latest position for each vehicle

### 3. Getting Vehicle Counts by Route

The `getVehicleCountsByRoute` method provides a count of active vehicles on each route. Key features:

- Uses a subquery to get the latest position of each vehicle
- Filters out stale data older than 5 minutes
- Groups results by route ID for easy analysis
- Returns a map for quick lookup of counts by route

These queries demonstrate Ignite's SQL capabilities, including:
- Complex query structures with subqueries
- Mathematical functions
- Aggregation and grouping
- Advanced sorting and filtering
- Parameterized queries for security

With these queries, we now have the foundational business logic for our transit monitoring system.
