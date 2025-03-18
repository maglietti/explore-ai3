# Understanding GTFS Data and Creating the Transit Schema

## The GTFS Format: Transit Data in Motion

The [General Transit Feed Specification](https://gtfs.org) (GTFS) is the universal language of public transportation data. Created by Google and Portland's TriMet transit agency in 2006, it has since become the industry standard used by transit agencies worldwide to share their transportation schedules and geographic information in a format that developers and applications can easily digest.

GTFS comes in two flavors, each serving a distinct purpose:

- **GTFS Static**: The foundation – containing the scheduled service information like routes, stops, timetables, and fares. Think of this as the transit system's blueprint.
- **GTFS Realtime**: The living, breathing extension that provides real-time updates including vehicle positions, service alerts, and trip updates. This is the pulse of the transit system as it operates.

For our transit monitoring system, we'll tap into the **GTFS Realtime** feed, specifically the [vehicle positions](https://gtfs.org/documentation/realtime/reference/#message-vehicleposition) data. This feed is our window into seeing where each transit vehicle is at any given moment – a digital twin of the physical transit network in operation.

## Modeling the Data: From Specification to Java Objects

Now that we understand what data we're working with, let's transform these transit concepts into code. We need a clean, intuitive model that captures the essence of a vehicle's position in the transit network with the `VehiclePosition` class:

```java
package com.example.transit;

import java.sql.Timestamp;
import java.time.Instant;
import java.io.Serializable;
import java.util.Objects;

/**
 * POJO representing a vehicle position record.
 */
public class VehiclePosition implements Serializable {
    // Good practice to define a serialVersionUID for Serializable classes
    private static final long serialVersionUID = 1L;

    private String vehicleId;
    private String routeId;
    private double latitude;
    private double longitude;
    private long timestamp;
    private String currentStatus;

    /**
     * Default no-arg constructor required for serialization and ORM frameworks
     */
    public VehiclePosition() {
        // Default constructor required for POJO usage with Ignite
    }

    /**
     * Full constructor for creating a VehiclePosition object
     */
    public VehiclePosition(String vehicleId, String routeId, double latitude,
                           double longitude, long timestamp, String currentStatus) {
        this.vehicleId = vehicleId;
        this.routeId = routeId;
        this.latitude = latitude;
        this.longitude = longitude;
        this.timestamp = timestamp;
        this.currentStatus = currentStatus;
    }

    // Getters and Setters - required for proper POJO
    public String getVehicleId() { return vehicleId; }
    public void setVehicleId(String vehicleId) { this.vehicleId = vehicleId; }

    public String getRouteId() { return routeId; }
    public void setRouteId(String routeId) { this.routeId = routeId; }

    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }

    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }

    public long getTimestamp() { return timestamp; }
    public void setTimestamp(long timestamp) { this.timestamp = timestamp; }

    public String getCurrentStatus() { return currentStatus; }
    public void setCurrentStatus(String currentStatus) { this.currentStatus = currentStatus; }

    public Instant getTimestampAsInstant() { return Instant.ofEpochMilli(this.timestamp); }

    /**
     * Equals method for proper object comparison
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        VehiclePosition that = (VehiclePosition) o;

        return Double.compare(that.latitude, latitude) == 0 &&
                Double.compare(that.longitude, longitude) == 0 &&
                timestamp == that.timestamp &&
                Objects.equals(vehicleId, that.vehicleId) &&
                Objects.equals(routeId, that.routeId) &&
                Objects.equals(currentStatus, that.currentStatus);
    }

    /**
     * Hash code implementation for collections
     */
    @Override
    public int hashCode() {
        return Objects.hash(vehicleId, routeId, latitude, longitude, timestamp, currentStatus);
    }

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

This model is our translator between the GTFS protocol buffer format and a straightforward Java object that's easy to work with in our application. Each instance represents a snapshot of a vehicle at a specific moment in time.

## Creating the Ignite Schema: Persisting Transit Movement

With our Java model defined, we now need a place to store these snapshots. Apache Ignite provides the perfect distributed database for this scenario, offering both the performance for real-time processing and the capacity for historical analysis.

The `SchemaSetup` class will create the schema that will house our transit data:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.catalog.ColumnType;
import org.apache.ignite.catalog.definitions.ColumnDefinition;
import org.apache.ignite.catalog.definitions.TableDefinition;
import org.apache.ignite.table.Table;

/**
 * Creates the database schema for storing vehicle position data.
 * This class handles creating tables for the transit monitoring system.
 */
public class SchemaSetup {
    /**
     * Creates the database schema for storing vehicle position data.
     * This method is idempotent and can be safely run multiple times.
     *
     * Uses the singleton IgniteClient from IgniteConnection.
     *
     * Uses the Catalog API instead of SQL to create tables, which avoids
     * SQL parsing issues and provides better type safety.
     *
     * @return true if the schema setup was successful
     */
    public boolean createSchema() {
        try {
            // Get the singleton client instance
            IgniteClient client = IgniteConnection.getClient();

            // Check if table already exists
            boolean tableExists = false;
            try {
                // Try to directly get the table
                var table = client.tables().table("vehicle_positions");
                if (table != null) {
                    tableExists = true;
                    System.out.println("Vehicle positions table already exists. Schema setup complete.");
                }
            } catch (Exception e) {
                System.out.println("Table does not exist, will create it: " + e.getMessage());
                // Continue with table creation
            }

            if (!tableExists) {
                // Define and create the table using Catalog API
                TableDefinition tableDefinition = TableDefinition.builder("vehicle_positions")
                        .ifNotExists()
                        .columns(
                                ColumnDefinition.column("vehicle_id", ColumnType.VARCHAR),
                                ColumnDefinition.column("route_id", ColumnType.VARCHAR),
                                ColumnDefinition.column("latitude", ColumnType.DOUBLE),
                                ColumnDefinition.column("longitude", ColumnType.DOUBLE),
                                ColumnDefinition.column("time_stamp", ColumnType.TIMESTAMP),
                                ColumnDefinition.column("current_status", ColumnType.VARCHAR)
                        )
                        .primaryKey("vehicle_id", "time_stamp")
                        .build();

                System.out.println("Creating table using Catalog API: " + tableDefinition);
                Table table = client.catalog().createTable(tableDefinition);
                System.out.println("Vehicle positions table created successfully: " + table.name());
            }

            return true;
        } catch (Exception e) {
            System.err.println("Failed to create schema: " + e.getMessage());
            Throwable cause = e;
            while (cause != null) {
                System.err.println("  Caused by: " + cause.getClass().getName() + ": " + cause.getMessage());
                cause = cause.getCause();
            }
            e.printStackTrace();
            return false;
        }
    }
}
```

## Test the Schema

Use the `SchemaSetupTest` class to explore creating tables in Ignite 3, inserting and retrieving data.

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.table.RecordView;
import org.apache.ignite.table.Table;
import org.apache.ignite.table.Tuple;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

/**
 * Test class to verify database connectivity and schema creation.
 * This class demonstrates how to connect to an Ignite cluster and set up
 * the table for the transit monitoring system.
 */
public class SchemaSetupTest {

    public static void main(String[] args) {
        System.out.println("Starting schema setup test...");

        // Test connection to Ignite cluster
        try {
            // Get the client connection
            IgniteClient client = IgniteConnection.getClient();
            System.out.println("Successfully connected to Ignite cluster");

            // Create schema for transit data
            SchemaSetup schemaSetup = new SchemaSetup();
            boolean success = schemaSetup.createSchema();

            if (success) {
                // Verify the table was created by querying it
                System.out.println("Verifying table creation...");
                try {
                    // Get a reference to the vehicle_positions table
                    Table table = client.tables().table("vehicle_positions");
                    System.out.println("Table: " + table.name());
                    System.out.println("Table verification successful.");

                    // Create a VehiclePosition object for testing
                    long currentTime = System.currentTimeMillis();
                    VehiclePosition testVehicle = new VehiclePosition(
                            "test-vehicle-1",
                            "test-route-100",
                            47.6062,
                            -122.3321,
                            currentTime,
                            "STOPPED"
                    );

                    // Convert timestamp to LocalDateTime expected by Ignite
                    LocalDateTime localDateTime = LocalDateTime.ofInstant(
                            Instant.ofEpochMilli(testVehicle.getTimestamp()),
                            ZoneId.systemDefault()
                    );

                    // Use RecordView with Tuple approach for insert
                    RecordView<Tuple> recordView = table.recordView();

                    // Create a tuple with field names that match database columns
                    Tuple vehicleTuple = Tuple.create()
                            .set("vehicle_id", testVehicle.getVehicleId())
                            .set("route_id", testVehicle.getRouteId())
                            .set("latitude", testVehicle.getLatitude())
                            .set("longitude", testVehicle.getLongitude())
                            .set("time_stamp", localDateTime)  // Use LocalDateTime, not Instant
                            .set("current_status", testVehicle.getCurrentStatus());

                    // Insert test data using the recordView
                    recordView.insert(null, vehicleTuple);
                    System.out.println("Test record inserted successfully: " + testVehicle);

                    // Use SQL approach for querying
                    String querySql = "SELECT vehicle_id, route_id, latitude, longitude, " +
                            "time_stamp, current_status FROM vehicle_positions WHERE vehicle_id = ?";

                    var resultSet = client.sql().execute(null, querySql, testVehicle.getVehicleId());

                    List<VehiclePosition> results = new ArrayList<>();
                    resultSet.forEachRemaining(row -> {
                        // Extract timestamp milliseconds from LocalDateTime
                        LocalDateTime resultDateTime = row.value("time_stamp");
                        // Convert LocalDateTime to Instant (requires a ZoneId)
                        Instant instant = resultDateTime.atZone(ZoneId.systemDefault()).toInstant();
                        long timestamp = instant.toEpochMilli();

                        VehiclePosition position = new VehiclePosition(
                                row.stringValue("vehicle_id"),
                                row.stringValue("route_id"),
                                row.doubleValue("latitude"),
                                row.doubleValue("longitude"),
                                timestamp,
                                row.stringValue("current_status")
                        );
                        results.add(position);
                        System.out.println("Found test record: " + position);
                    });

                    System.out.println("Retrieved " + results.size() + " vehicle position records");

                    // Use SQL for delete as well
                    String deleteSql = "DELETE FROM vehicle_positions WHERE vehicle_id = ?";
                    client.sql().execute(null, deleteSql, testVehicle.getVehicleId());
                    System.out.println("Test record deleted successfully.");

                    // Verify deletion using SQL
                    long count = 0;
                    var verifyDeleteRs = client.sql().execute(null,
                            "SELECT COUNT(*) as cnt FROM vehicle_positions WHERE vehicle_id = ?",
                            testVehicle.getVehicleId());

                    if (verifyDeleteRs.hasNext()) {
                        count = verifyDeleteRs.next().longValue("cnt");
                    }

                    System.out.println("Records remaining after delete: " + count);
                    if (count == 0) {
                        System.out.println("Deletion verification successful.");
                    } else {
                        System.out.println("Warning: Test data deletion may have failed.");
                    }

                } catch (Exception e) {
                    System.err.println("Table verification failed: " + e.getMessage());
                    e.printStackTrace();
                }
            } else {
                System.err.println("Schema setup failed.");
            }

        } catch (Exception e) {
            System.err.println("Test failed: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Clean up connection
            try {
                IgniteConnection.close();
                System.out.println("Test completed, resources cleaned up.");
            } catch (Exception e) {
                System.err.println("Error during cleanup: " + e.getMessage());
            }
        }
    }
}
```

## The Architecture Behind the Schema

Our schema design isn't just a collection of columns – it's a carefully considered structure that facilitates powerful queries and analysis:

1. **Historical Tracking**: The composite primary key of `vehicle_id` and `timestamp` allows us to maintain a complete history of each vehicle's movement over time – a digital breadcrumb trail across the city.

2. **Real-time Lookups**: By indexing on vehicle_id, we can quickly answer questions like "Where is bus #1234 right now?" by finding the record with the most recent timestamp.

3. **Route Analysis**: With route_id captured, we can aggregate data to understand performance across different routes, identifying patterns like which routes consistently run late or have unusual vehicle spacing.

4. **Spatial Capabilities**: The latitude and longitude coordinates enable spatial queries – finding all vehicles within a certain area or calculating distances between vehicles.

Apache Ignite's distributed architecture means this schema can handle high-volume transit systems with hundreds or thousands of vehicles reporting positions every few seconds. As vehicles move through the transit network, our database will create a rich, queryable history of their journeys – a dataset that's valuable not just for real-time monitoring but also for long-term transit planning and optimization.

In the next section, we'll create a client to get the GTFS data into our Ignite cluster, bringing our transit monitoring system to life.
