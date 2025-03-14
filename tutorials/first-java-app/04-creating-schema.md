# Creating the Transit Schema

Now that we understand our data model, let's create the database schema in Ignite. For our transit monitoring system, we'll need a table to store vehicle positions with appropriate columns and types.

Create a new file `SchemaSetup.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;

public class SchemaSetup {
    public void createSchema() {
        try {
            IgniteClient client = IgniteConnection.getClient();
            
            // Create table for vehicle positions
            SqlClientSession sqlSession = client.sql();
            
            String createTableSql = "CREATE TABLE IF NOT EXISTS vehicle_positions ("
                + "vehicle_id VARCHAR, "
                + "route_id VARCHAR, "
                + "latitude DOUBLE, "
                + "longitude DOUBLE, "
                + "timestamp TIMESTAMP, "
                + "current_status VARCHAR, "
                + "PRIMARY KEY (vehicle_id, timestamp)"
                + ")";
            
            sqlSession.execute(createTableSql);
            System.out.println("Vehicle positions table created successfully");
        } catch (Exception e) {
            System.err.println("Failed to create schema: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
```

This schema uses a composite primary key of `vehicle_id` and `timestamp`, which allows us to efficiently track the position history of each vehicle over time. The `IF NOT EXISTS` clause ensures we don't try to recreate the table if it already exists.

Let's break down the schema design:

1. **vehicle_id (VARCHAR)**: Unique identifier for each transit vehicle
2. **route_id (VARCHAR)**: The route the vehicle is currently servicing
3. **latitude (DOUBLE)**: Geographic coordinate for the vehicle's position
4. **longitude (DOUBLE)**: Geographic coordinate for the vehicle's position
5. **timestamp (TIMESTAMP)**: When the position was recorded
6. **current_status (VARCHAR)**: The operational status of the vehicle

The composite primary key `(vehicle_id, timestamp)` serves multiple purposes:
- It ensures we can store multiple positions for the same vehicle over time
- It allows efficient queries for a vehicle's position history
- It enables us to find the most recent position for each vehicle

In a more advanced application, we might add additional indexes to optimize specific query patterns, but this schema is an excellent starting point for our transit monitoring system.
