# Adding a Service Monitor

In this module, we'll implement a monitoring system that continuously watches for potential service disruptions in our transit network. By leveraging Apache Ignite's SQL query capability, we can detect specific conditions and trigger appropriate responses when those conditions are met.

## Understanding Monitoring Approaches in Distributed Systems

When building monitoring solutions for distributed systems like our transit application, there are several common approaches to consider:

```mermaid
graph TD
    A[Monitoring Approaches]
    A --> B[Event-Based]
    A --> C[Polling-Based]
    A --> D[Push Notifications]
    
    B --> B1[Continuous Queries]
    B --> B2[Event Listeners]
    
    C --> C1[Scheduled Execution]
    C --> C2[Periodic SQL Queries]
    
    D --> D1[Callback Registration]
    D --> D2[Subscription Model]
    
    style A fill:#f9f9f9,stroke:#333,stroke-width:2px
```

For our transit monitoring system, we'll implement a **polling-based approach** using scheduled SQL queries. This approach offers several advantages:

1. **Simplicity**: Easy to implement and understand
2. **Flexibility**: Can modify query criteria without redeploying
3. **Control**: Precise control over monitoring frequency
4. **Resource Management**: Predictable resource usage pattern

> [!note]
> A polling-based approach periodically checks the system state by executing queries at fixed intervals. While it may not be as real-time as event-based approaches, it's more straightforward to implement and often sufficient for transit monitoring where conditions change relatively slowly (on the order of seconds or minutes rather than milliseconds).

> [!important]
> **Checkpoint**: Before proceeding, make sure you understand:
>
> - The difference between event-based, polling-based, and push notification approaches
> - Why we're choosing a polling-based approach for our transit monitoring
> - The advantages and limitations of this approach

Let's implement this pattern to monitor for vehicles that have been stopped for an extended period, potentially indicating service disruptions.

Create a file `ServiceMonitor.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Monitors vehicle positions for potential service disruptions.
 * This class periodically checks for various conditions that might
 * indicate issues in the transit system, such as delayed vehicles,
 * bunching, or insufficient route coverage.
 */
public class ServiceMonitor {
    // Thresholds for monitoring conditions
    private static final int STOPPED_THRESHOLD_MINUTES = 5;
    private static final int BUNCHING_DISTANCE_KM = 1;
    private static final int MINIMUM_VEHICLES_PER_ROUTE = 2;
    private static final int OFFLINE_THRESHOLD_MINUTES = 15;
    
    // Monitoring infrastructure
    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    private final IgniteClient client;
    private final DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss");
    
    // Statistics tracking
    private final Map<String, AtomicInteger> alertCounts = new HashMap<>();
    private final List<ServiceAlert> recentAlerts = new ArrayList<>();
    private final int maxRecentAlerts = 100;
    
    /**
     * Creates a new service monitor connected to the Ignite cluster.
     */
    public ServiceMonitor() {
        this.client = IgniteConnection.getClient();
        initializeAlertCounters();
    }
    
    /**
     * Initializes alert counters for each type of monitored condition.
     */
    private void initializeAlertCounters() {
        alertCounts.put("DELAYED_VEHICLE", new AtomicInteger(0));
        alertCounts.put("VEHICLE_BUNCHING", new AtomicInteger(0));
        alertCounts.put("LOW_ROUTE_COVERAGE", new AtomicInteger(0));
        alertCounts.put("OFFLINE_VEHICLE", new AtomicInteger(0));
    }
    
    /**
     * Starts monitoring for service disruptions by polling the database at regular intervals.
     * 
     * @param intervalSeconds The polling interval in seconds
     */
    public void startMonitoring(int intervalSeconds) {
        System.out.println("Starting service disruption monitoring (polling every " + intervalSeconds + " seconds)");
        
        // Schedule all monitoring tasks
        scheduler.scheduleAtFixedRate(
            this::checkForDelayedVehicles, 
            5, 
            intervalSeconds, 
            TimeUnit.SECONDS
        );
        
        scheduler.scheduleAtFixedRate(
            this::checkForVehicleBunching, 
            10, 
            intervalSeconds, 
            TimeUnit.SECONDS
        );
        
        scheduler.scheduleAtFixedRate(
            this::checkForLowRouteCoverage, 
            15, 
            intervalSeconds, 
            TimeUnit.SECONDS
        );
        
        scheduler.scheduleAtFixedRate(
            this::checkForOfflineVehicles, 
            20, 
            intervalSeconds, 
            TimeUnit.SECONDS
        );
        
        // Also schedule a task to regularly print monitoring statistics
        scheduler.scheduleAtFixedRate(
            this::printMonitoringStatistics, 
            30, 
            300, 
            TimeUnit.SECONDS  // Print stats every 5 minutes
        );
    }
    
    /**
     * Stops the monitoring service.
     */
    public void stopMonitoring() {
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(10, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
            Thread.currentThread().interrupt();
        }
        System.out.println("Service disruption monitoring stopped");
        printMonitoringStatistics(); // Print final statistics
    }
    
    /**
     * Checks for vehicles that have been stopped for longer than the threshold.
     */
    private void checkForDelayedVehicles() {
        try {
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
            
            // Execute the query with the threshold parameter
            var result = client.sql().execute(null, querySql, STOPPED_THRESHOLD_MINUTES);
            
            int count = 0;
            // Process each row in the result
            while (result.hasNext()) {
                var row = result.next();
                count++;
                
                String vehicleId = row.stringValue("vehicle_id");
                String routeId = row.stringValue("route_id");
                LocalDateTime timestamp = row.value("time_stamp");
                int stoppedMinutes = row.intValue("stopped_minutes");
                
                // Create and record the alert
                ServiceAlert alert = new ServiceAlert(
                    "DELAYED_VEHICLE",
                    "Vehicle " + vehicleId + " on route " + routeId + 
                    " has been stopped for " + stoppedMinutes + " minutes",
                    routeId,
                    vehicleId,
                    row.doubleValue("latitude"),
                    row.doubleValue("longitude"),
                    stoppedMinutes
                );
                
                recordAlert(alert);
                
                // Log the alert
                System.out.println("[" + LocalDateTime.now().format(timeFormatter) + 
                                  "] ALERT: " + alert.getMessage());
            }
            
            if (count > 0) {
                System.out.println("Found " + count + " delayed vehicles");
            }
        } catch (Exception e) {
            System.err.println("Error checking for delayed vehicles: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Checks for vehicles on the same route that are too close together (bunching).
     */
    private void checkForVehicleBunching() {
        try {
            // This query finds pairs of vehicles on the same route that are close to each other
            String querySql = 
                "WITH latest_positions AS (" +
                "    SELECT v.vehicle_id, v.route_id, v.latitude, v.longitude " +
                "    FROM vehicle_positions v " +
                "    JOIN (" +
                "        SELECT vehicle_id, MAX(time_stamp) as latest_ts " +
                "        FROM vehicle_positions " +
                "        GROUP BY vehicle_id " +
                "    ) l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts " +
                "    WHERE v.current_status = 'IN_TRANSIT_TO' " +  // Only consider moving vehicles
                ") " +
                "SELECT " +
                "    a.vehicle_id as vehicle1, " +
                "    b.vehicle_id as vehicle2, " +
                "    a.route_id, " +
                "    a.latitude as lat1, " +
                "    a.longitude as lon1, " +
                "    b.latitude as lat2, " +
                "    b.longitude as lon2, " +
                "    SQRT(POWER(a.latitude - b.latitude, 2) + POWER(a.longitude - b.longitude, 2)) * 111 as distance_km " +
                "FROM latest_positions a " +
                "JOIN latest_positions b ON a.route_id = b.route_id AND a.vehicle_id < b.vehicle_id " +
                "WHERE SQRT(POWER(a.latitude - b.latitude, 2) + POWER(a.longitude - b.longitude, 2)) * 111 < ? " +
                "ORDER BY distance_km";
            
            var result = client.sql().execute(null, querySql, BUNCHING_DISTANCE_KM);
            
            int count = 0;
            while (result.hasNext()) {
                var row = result.next();
                count++;
                
                String vehicle1 = row.stringValue("vehicle1");
                String vehicle2 = row.stringValue("vehicle2");
                String routeId = row.stringValue("route_id");
                double distanceKm = row.doubleValue("distance_km");
                
                // Create and record the alert
                ServiceAlert alert = new ServiceAlert(
                    "VEHICLE_BUNCHING",
                    "Vehicles " + vehicle1 + " and " + vehicle2 + " on route " + routeId + 
                    " are only " + String.format("%.2f", distanceKm) + " km apart",
                    routeId,
                    vehicle1 + "," + vehicle2,
                    (row.doubleValue("lat1") + row.doubleValue("lat2")) / 2, // Midpoint
                    (row.doubleValue("lon1") + row.doubleValue("lon2")) / 2,
                    (int)(distanceKm * 100) // Convert to integer value for severity (smaller = more severe)
                );
                
                recordAlert(alert);
                
                // Log the alert
                System.out.println("[" + LocalDateTime.now().format(timeFormatter) + 
                                  "] ALERT: " + alert.getMessage());
            }
            
            if (count > 0) {
                System.out.println("Found " + count + " instances of vehicle bunching");
            }
        } catch (Exception e) {
            System.err.println("Error checking for vehicle bunching: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Checks for routes with insufficient vehicle coverage.
     */
    private void checkForLowRouteCoverage() {
        try {
            String querySql = 
                "WITH active_vehicles AS (" +
                "    SELECT DISTINCT v.route_id, v.vehicle_id " +
                "    FROM vehicle_positions v " +
                "    JOIN (" +
                "        SELECT vehicle_id, MAX(time_stamp) as latest_ts " +
                "        FROM vehicle_positions " +
                "        GROUP BY vehicle_id " +
                "    ) l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts " +
                "    WHERE TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) < 15" +  // Only consider recent positions
                ") " +
                "SELECT route_id, COUNT(*) as vehicle_count " +
                "FROM active_vehicles " +
                "GROUP BY route_id " +
                "HAVING COUNT(*) < ? " +
                "ORDER BY vehicle_count";
            
            var result = client.sql().execute(null, querySql, MINIMUM_VEHICLES_PER_ROUTE);
            
            int count = 0;
            while (result.hasNext()) {
                var row = result.next();
                count++;
                
                String routeId = row.stringValue("route_id");
                int vehicleCount = (int)row.longValue("vehicle_count");
                
                // Create and record the alert
                ServiceAlert alert = new ServiceAlert(
                    "LOW_ROUTE_COVERAGE",
                    "Route " + routeId + " has only " + vehicleCount + 
                    " vehicle(s) in service (minimum " + MINIMUM_VEHICLES_PER_ROUTE + " required)",
                    routeId,
                    null,
                    0, 0, // No specific location
                    MINIMUM_VEHICLES_PER_ROUTE - vehicleCount // Severity is the shortage amount
                );
                
                recordAlert(alert);
                
                // Log the alert
                System.out.println("[" + LocalDateTime.now().format(timeFormatter) + 
                                  "] ALERT: " + alert.getMessage());
            }
            
            if (count > 0) {
                System.out.println("Found " + count + " routes with insufficient vehicle coverage");
            }
        } catch (Exception e) {
            System.err.println("Error checking for low route coverage: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Checks for vehicles that haven't reported positions recently.
     */
    private void checkForOfflineVehicles() {
        try {
            String querySql = 
                "WITH latest_timestamps AS (" +
                "    SELECT vehicle_id, MAX(time_stamp) as latest_ts " +
                "    FROM vehicle_positions " +
                "    GROUP BY vehicle_id " +
                "), active_routes AS (" +
                "    SELECT DISTINCT route_id " +
                "    FROM vehicle_positions v " +
                "    JOIN latest_timestamps l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts " +
                "    WHERE TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) < 15" +
                ") " +
                "SELECT v.vehicle_id, v.route_id, v.latitude, v.longitude, v.time_stamp, " +
                "       TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as offline_minutes " +
                "FROM vehicle_positions v " +
                "JOIN latest_timestamps l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts " +
                "WHERE v.route_id IN (SELECT route_id FROM active_routes) " +  // Only check routes with some active vehicles
                "  AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) >= ? " +
                "ORDER BY offline_minutes DESC";
            
            var result = client.sql().execute(null, querySql, OFFLINE_THRESHOLD_MINUTES);
            
            int count = 0;
            while (result.hasNext()) {
                var row = result.next();
                count++;
                
                String vehicleId = row.stringValue("vehicle_id");
                String routeId = row.stringValue("route_id");
                int offlineMinutes = row.intValue("offline_minutes");
                
                // Create and record the alert
                ServiceAlert alert = new ServiceAlert(
                    "OFFLINE_VEHICLE",
                    "Vehicle " + vehicleId + " on route " + routeId + 
                    " has not reported for " + offlineMinutes + " minutes",
                    routeId,
                    vehicleId,
                    row.doubleValue("latitude"),
                    row.doubleValue("longitude"),
                    offlineMinutes
                );
                
                recordAlert(alert);
                
                // Log the alert
                System.out.println("[" + LocalDateTime.now().format(timeFormatter) + 
                                  "] ALERT: " + alert.getMessage());
            }
            
            if (count > 0) {
                System.out.println("Found " + count + " offline vehicles");
            }
        } catch (Exception e) {
            System.err.println("Error checking for offline vehicles: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Records an alert for tracking and statistics.
     */
    private synchronized void recordAlert(ServiceAlert alert) {
        // Increment the count for this alert type
        alertCounts.get(alert.getType()).incrementAndGet();
        
        // Add to recent alerts
        recentAlerts.add(alert);
        
        // Trim list if needed
        while (recentAlerts.size() > maxRecentAlerts) {
            recentAlerts.remove(0);
        }
    }
    
    /**
     * Prints statistics about monitoring activities.
     */
    public void printMonitoringStatistics() {
        System.out.println("\n===== SERVICE MONITORING STATISTICS =====");
        System.out.println("Time: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        System.out.println("\nAlert counts by type:");
        
        alertCounts.forEach((type, count) -> {
            System.out.println("• " + type + ": " + count.get());
        });
        
        int totalAlerts = alertCounts.values().stream()
            .mapToInt(AtomicInteger::get)
            .sum();
            
        System.out.println("\nTotal alerts detected: " + totalAlerts);
        
        if (!recentAlerts.isEmpty()) {
            System.out.println("\nMost recent alerts:");
            recentAlerts.stream()
                .limit(5)
                .forEach(alert -> System.out.println("• " + alert.getMessage()));
        }
        
        System.out.println("\nMonitoring thresholds:");
        System.out.println("• Delayed vehicle: " + STOPPED_THRESHOLD_MINUTES + " minutes");
        System.out.println("• Vehicle bunching: " + BUNCHING_DISTANCE_KM + " km");
        System.out.println("• Minimum vehicles per route: " + MINIMUM_VEHICLES_PER_ROUTE);
        System.out.println("• Offline threshold: " + OFFLINE_THRESHOLD_MINUTES + " minutes");
        
        System.out.println("===========================================\n");
    }
    
    /**
     * Gets the list of recent alerts.
     */
    public synchronized List<ServiceAlert> getRecentAlerts() {
        return new ArrayList<>(recentAlerts);
    }
    
    /**
     * Gets the alert counts by type.
     */
    public Map<String, Integer> getAlertCounts() {
        Map<String, Integer> counts = new HashMap<>();
        alertCounts.forEach((type, count) -> counts.put(type, count.get()));
        return counts;
    }
    
    /**
     * Class representing a service alert in the monitoring system.
     */
    public static class ServiceAlert {
        private final String type;
        private final String message;
        private final String routeId;
        private final String vehicleId;
        private final double latitude;
        private final double longitude;
        private final int severity;
        private final LocalDateTime timestamp;
        
        public ServiceAlert(String type, String message, String routeId, String vehicleId, 
                          double latitude, double longitude, int severity) {
            this.type = type;
            this.message = message;
            this.routeId = routeId;
            this.vehicleId = vehicleId;
            this.latitude = latitude;
            this.longitude = longitude;
            this.severity = severity;
            this.timestamp = LocalDateTime.now();
        }
        
        // Getters
        public String getType() { return type; }
        public String getMessage() { return message; }
        public String getRouteId() { return routeId; }
        public String getVehicleId() { return vehicleId; }
        public double getLatitude() { return latitude; }
        public double getLongitude() { return longitude; }
        public int getSeverity() { return severity; }
        public LocalDateTime getTimestamp() { return timestamp; }
    }
}
```

> [!note]
> This service monitors four different transit conditions: delayed vehicles, vehicle bunching (multiple vehicles too close together), low route coverage, and offline vehicles. Each condition is checked using a separate SQL query executed on a regular schedule. This modular approach makes it easy to add or remove monitoring conditions as needed.

> [!important]
> **Checkpoint**: Take some time to review the `ServiceMonitor` class and understand:
>
> - How it schedules multiple monitoring tasks
> - The four different types of alerts it detects
> - How alerts are recorded and statistics are maintained
> - How the `ServiceAlert` inner class represents alert information

## Understanding the Key Monitoring Conditions

Let's explore each of the four monitoring conditions in more detail:

### Delayed Vehicles

This condition identifies vehicles that have been stopped at a location for longer than expected. Potential causes include:

- Traffic congestion
- Mechanical problems
- Driver breaks or shift changes
- Accidents or road blockages

The query finds the most recent position for each vehicle and checks if it has been stopped for more than the threshold time (5 minutes by default):

```sql
SELECT 
    v.vehicle_id, 
    v.route_id, 
    v.current_status, 
    v.latitude, 
    v.longitude, 
    v.time_stamp, 
    TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as stopped_minutes 
FROM vehicle_positions v 
JOIN (
    SELECT vehicle_id, MAX(time_stamp) as latest_ts 
    FROM vehicle_positions 
    GROUP BY vehicle_id 
) l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts 
WHERE 
    v.current_status = 'STOPPED_AT' 
    AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) >= ?
```

### Vehicle Bunching

Vehicle bunching occurs when multiple vehicles on the same route end up too close together, often resulting in irregular service intervals. Causes include:

- Inconsistent passenger loading times
- Traffic light timing
- Traffic congestion
- Accidents or road closures

The query finds pairs of vehicles on the same route that are closer than the threshold distance (1 km by default):

```sql
WITH latest_positions AS (
    SELECT v.vehicle_id, v.route_id, v.latitude, v.longitude 
    FROM vehicle_positions v 
    JOIN (
        SELECT vehicle_id, MAX(time_stamp) as latest_ts 
        FROM vehicle_positions 
        GROUP BY vehicle_id 
    ) l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts 
    WHERE v.current_status = 'IN_TRANSIT_TO'  -- Only consider moving vehicles
) 
SELECT 
    a.vehicle_id as vehicle1, 
    b.vehicle_id as vehicle2, 
    a.route_id, 
    a.latitude as lat1, 
    a.longitude as lon1, 
    b.latitude as lat2, 
    b.longitude as lon2, 
    SQRT(POWER(a.latitude - b.latitude, 2) + POWER(a.longitude - b.longitude, 2)) * 111 as distance_km 
FROM latest_positions a 
JOIN latest_positions b ON a.route_id = b.route_id AND a.vehicle_id < b.vehicle_id 
WHERE SQRT(POWER(a.latitude - b.latitude, 2) + POWER(a.longitude - b.longitude, 2)) * 111 < ? 
ORDER BY distance_km
```

> [!note]
> The distance calculation multiplies by 111 to convert the degree-based distance to approximate kilometers (there are roughly 111 kilometers per degree of latitude or longitude at the equator). While not perfectly accurate for all locations, this approximation is sufficient for our monitoring purposes.

### Low Route Coverage

This condition detects routes that have fewer than the minimum required number of vehicles in service, which could result in longer wait times for passengers. Causes include:

- Vehicle breakdowns
- Driver shortages
- Scheduled service reductions
- Emergency service diversions

The query counts active vehicles on each route and identifies those with fewer than the threshold (2 by default):

```sql
WITH active_vehicles AS (
    SELECT DISTINCT v.route_id, v.vehicle_id 
    FROM vehicle_positions v 
    JOIN (
        SELECT vehicle_id, MAX(time_stamp) as latest_ts 
        FROM vehicle_positions 
        GROUP BY vehicle_id 
    ) l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts 
    WHERE TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) < 15  -- Only consider recent positions
) 
SELECT route_id, COUNT(*) as vehicle_count 
FROM active_vehicles 
GROUP BY route_id 
HAVING COUNT(*) < ? 
ORDER BY vehicle_count
```

### Offline Vehicles

This condition identifies vehicles that haven't reported their position recently, potentially indicating communication or hardware issues. Causes include:

- GPS equipment failure
- Communication system outages
- Vehicle power issues
- Software malfunctions

The query finds vehicles on active routes that haven't reported in more than the threshold time (15 minutes by default):

```sql
WITH latest_timestamps AS (
    SELECT vehicle_id, MAX(time_stamp) as latest_ts 
    FROM vehicle_positions 
    GROUP BY vehicle_id 
), active_routes AS (
    SELECT DISTINCT route_id 
    FROM vehicle_positions v 
    JOIN latest_timestamps l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts 
    WHERE TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) < 15
) 
SELECT v.vehicle_id, v.route_id, v.latitude, v.longitude, v.time_stamp, 
       TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as offline_minutes 
FROM vehicle_positions v 
JOIN latest_timestamps l ON v.vehicle_id = l.vehicle_id AND v.time_stamp = l.latest_ts 
WHERE v.route_id IN (SELECT route_id FROM active_routes)  -- Only check routes with some active vehicles
  AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) >= ? 
ORDER BY offline_minutes DESC
```

> [!important]
> **Checkpoint**: Make sure you understand:
>
> - The purpose of each monitoring condition
> - How each SQL query works to detect the condition
> - The potential real-world causes for each condition
> - How the monitoring thresholds affect what gets detected

## Testing the Service Monitor

Let's create a simple test application to verify our service monitor. Create a file `ServiceMonitorTest.java`:

```java
package com.example.transit;

import java.util.List;
import java.util.Map;

/**
 * Test application for the service monitor.
 * Demonstrates setting up and running the monitoring service.
 */
public class ServiceMonitorTest {

    public static void main(String[] args) {
        System.out.println("=== Service Monitor Test ===");

        try {
            // First, verify we have data to monitor
            System.out.println("\nVerifying database data...");
            DataVerifier.verifyData();

            // Create and start the service monitor
            System.out.println("\nStarting service monitor...");
            ServiceMonitor monitor = new ServiceMonitor();
            monitor.startMonitoring(60); // Check every 60 seconds

            // Let the monitor run for a while
            System.out.println("\nMonitor is running. Press Enter to stop...");
            System.in.read();

            // Stop the monitor
            System.out.println("\nStopping service monitor...");
            monitor.stopMonitoring();

            // Display final results
            List<ServiceMonitor.ServiceAlert> alerts = monitor.getRecentAlerts();
            Map<String, Integer> alertCounts = monitor.getAlertCounts();

            System.out.println("\n=== Monitoring Results ===");
            System.out.println("Total alerts detected: " + alerts.size());

            alertCounts.forEach((type, count) -> {
                System.out.println("• " + type + ": " + count);
            });

            if (!alerts.isEmpty()) {
                System.out.println("\nSample alerts:");
                alerts.stream()
                        .limit(5)
                        .forEach(alert -> {
                            System.out.println("• " + alert.getMessage() +
                                    " (Severity: " + alert.getSeverity() + ")");
                        });
            }

            System.out.println("\nTest completed successfully!");

        } catch (Exception e) {
            System.err.println("Error during monitor test: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Clean up connection
            IgniteConnection.close();
        }
    }
}
```

Execute the test to validate the service monitor:

```bash
mvn compile exec:java -Dexec.mainClass="com.example.transit.ServiceMonitorTest"
```

> [!note]
> This test will run until you press Enter, giving the monitor time to detect any issues in your transit data. The longer you let it run, the more alerts it may detect, depending on the state of your data.

**Expected Output**: The exact alerts detected will depend on your data, but you should see something like:

```text
=== Service Monitor Test ===

Verifying database data...
[Database verification output...]

Starting service monitor...
Starting service disruption monitoring (polling every 60 seconds)
[Various alert messages as conditions are detected...]

Monitor is running. Press Enter to stop...
[Press Enter when ready to stop]

Stopping service monitor...
Service disruption monitoring stopped

=== SERVICE MONITORING STATISTICS ===
[Statistics output...]
===========================================

=== Monitoring Results ===
Total alerts detected: 42

• DELAYED_VEHICLE: 15
• VEHICLE_BUNCHING: 22
• LOW_ROUTE_COVERAGE: 3
• OFFLINE_VEHICLE: 2

Sample alerts:
• Vehicle 1234 on route 30 has been stopped for 12 minutes (Severity: 12)
• Vehicles 5432 and 5433 on route 14 are only 0.32 km apart (Severity: 32)
• Route 38 has only 1 vehicle(s) in service (minimum 2 required) (Severity: 1)
• Vehicle 9876 on route 22 has not reported for 18 minutes (Severity: 18)
• Vehicle 6543 on route 5 has been stopped for 8 minutes (Severity: 8)

Test completed successfully!
```

> [!important]
> **Checkpoint**: After running the test, verify that:
>
> - The monitor successfully connected to the database
> - At least some alerts were detected (you may need to run the test for longer to see multiple alerts)
> - The statistics were correctly compiled
> - The monitor shut down gracefully

## The Monitoring Process Workflow

When the service monitoring system runs, it follows this workflow:

```mermaid
sequenceDiagram
    participant Scheduler
    participant Monitor as ServiceMonitor
    participant Ignite as Apache Ignite
    participant Alert as Alert Handler
    
    Note over Scheduler: Every N seconds
    Scheduler->>Monitor: Trigger check
    activate Monitor
    
    Monitor->>Ignite: Execute SQL query
    activate Ignite
    Ignite-->>Monitor: Return matching vehicles
    deactivate Ignite
    
    alt Disruptions detected
        Monitor->>Alert: Log alerts for each vehicle
        Note over Alert: In production:<br/>- Send notifications<br/>- Update dashboard<br/>- Log to database
    else No disruptions
        Monitor->>Monitor: No action needed
    end
    
    deactivate Monitor
    
    Note over Scheduler: Wait for next interval
```

This polling-based approach gives us regular checks on system status without overloading the database or application. By adjusting the polling interval, we can balance responsiveness against system load.

## Understanding the Alert Management System

The `ServiceMonitor` class includes a simple but effective alert management system:

1. **Alert Types**: Each alert is categorized by type (DELAYED_VEHICLE, VEHICLE_BUNCHING, etc.)
2. **Alert Tracking**: Alerts are counted by type and the most recent alerts are stored in memory
3. **Severity Rating**: Each alert has a severity value used for prioritization
4. **Timestamp**: Alerts are timestamped when they're created
5. **Geographic Information**: Where relevant, alerts include location coordinates

This structure makes it easy to:

- Track alert trends over time
- Focus on the most critical issues
- Locate problems geographically
- Group related alerts

> [!note]
> In a production system, you would likely extend this basic alert management to include:
>
> - Persistence to a database for historical analysis
> - Alert escalation for unresolved issues
> - Alert de-duplication to avoid repeated notifications for the same issue
> - Integration with external notification systems (email, SMS, etc.)

## Customizing the Monitoring Thresholds

The `ServiceMonitor` class defines several thresholds that control when alerts are triggered:

```java
private static final int STOPPED_THRESHOLD_MINUTES = 5;
private static final int BUNCHING_DISTANCE_KM = 1;
private static final int MINIMUM_VEHICLES_PER_ROUTE = 2;
private static final int OFFLINE_THRESHOLD_MINUTES = 15;
```

These thresholds should be adjusted based on your specific transit system characteristics:

1. **Stopped Threshold**: For systems with longer scheduled stops or congested areas, increase this value
2. **Bunching Distance**: For high-frequency routes, you might use a smaller value; for rural routes, a larger one
3. **Minimum Vehicles**: This depends on your schedule and route lengths
4. **Offline Threshold**: Adjust based on your expected reporting frequency

In a production system, you might want to make these thresholds configurable per route, time of day, or day of week.

## Benefits of SQL-Based Monitoring

Using SQL queries for monitoring provides several advantages:

1. **Declarative Definition**: You can express complex conditions directly in SQL
2. **Server-Side Processing**: Filtering happens on the server, minimizing network traffic
3. **Flexibility**: Easily adjust thresholds or add new conditions
4. **Integration**: Works seamlessly with your existing data model

This SQL-based monitoring approach demonstrates how Ignite can be used not just for data storage but as an intelligent processing platform for real-time applications.

## Next Steps

In this module, we've implemented a comprehensive service monitoring system that:

1. Continuously checks for potential service disruptions
2. Detects multiple types of issues, including:
   - Vehicles stopped for too long
   - Vehicles bunching on routes
   - Routes with insufficient coverage
   - Vehicles that have gone offline

3. Tracks statistics about detected issues
4. Provides a foundation for integration with external systems

This monitoring system transforms our transit application from a passive data collection system into an active monitoring tool that can alert operators to potential problems before they significantly impact service.

The SQL-based approach leverages Ignite's distributed query capabilities to efficiently process large volumes of transit data and detect specific patterns that might indicate service issues.

> [!important]
> **Final Module Checkpoint**: Before proceeding to the next module, ensure:
>
> - You understand the polling-based monitoring approach
> - You can explain the four monitoring conditions and their SQL queries
> - You've successfully run the `ServiceMonitorTest` and seen alerts generated
> - You understand how the alert management system works
> - You've considered how you might extend the system with additional checks

In the next module, we'll bring all the components together to create the complete transit monitoring application, including a simple dashboard to visualize the system status.

> [!tip]
> **Next Steps:** Continue to [Module 8: Putting It All Together](08-putting-together.md) to create the main application that combines all these components into a complete system.
