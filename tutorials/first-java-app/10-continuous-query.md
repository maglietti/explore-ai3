# Adding a Continuous Query

One of Ignite's powerful features is continuous queries, which can monitor for specific conditions and trigger actions when those conditions are met. Let's implement a service monitor to detect potential service disruptions.

Create a file `ServiceMonitor.java`:

```java
package com.gridgain.transit;

import org.apache.ignite.client.ClientContinuousQueryListener;
import org.apache.ignite.client.ContinuousQuery;
import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlContinuousQueryCursor;
import org.apache.ignite.client.SqlParameters;
import org.apache.ignite.client.SqlRow;

import java.sql.Timestamp;
import java.util.List;

public class ServiceMonitor {
    public void monitorServiceDisruptions() {
        IgniteClient client = IgniteConnection.getClient();
        SqlClientSession sqlSession = client.sql();
        
        // Query to detect vehicles with significant delays
        String continuousQuerySql = "SELECT v.vehicle_id, v.route_id, v.current_status, "
            + "v.latitude, v.longitude, v.timestamp "
            + "FROM vehicle_positions v "
            + "JOIN ("
            + "  SELECT vehicle_id, MAX(timestamp) as latest_ts "
            + "  FROM vehicle_positions "
            + "  GROUP BY vehicle_id"
            + ") latest ON v.vehicle_id = latest.vehicle_id AND v.timestamp = latest.latest_ts "
            + "WHERE v.current_status = 'STOPPED_AT' "
            + "AND v.timestamp < ?";
        
        // Detect vehicles stopped for more than 5 minutes
        long threshold = System.currentTimeMillis() - (5 * 60 * 1000);
        
        try {
            SqlParameters params = sqlSession.prepareNative(continuousQuerySql)
                .addParameter(new Timestamp(threshold));
            
            ClientContinuousQueryListener<SqlRow> listener = new ClientContinuousQueryListener<SqlRow>() {
                @Override
                public void onUpdated(List<SqlRow> rows) {
                    for (SqlRow row : rows) {
                        System.out.println("⚠️ Service disruption detected!");
                        System.out.println("Vehicle ID: " + row.getString("vehicle_id"));
                        System.out.println("Route ID: " + row.getString("route_id"));
                        System.out.println("Status: " + row.getString("current_status"));
                        System.out.println("Last updated: " + row.getTimestamp("timestamp"));
                        System.out.println("--------------------");
                    }
                }
            };
            
            // Create and start the continuous query
            ContinuousQuery<SqlRow> continuousQuery = params.continuousQuery()
                .initialQueryMaxRows(100)
                .listener(listener);
            
            SqlContinuousQueryCursor<SqlRow> cursor = continuousQuery.execute();
            System.out.println("Continuous query for service disruptions started");
            
            // In a real application, you would store this cursor to close it later
            // For this guide, we'll let it run until the application stops
        } catch (Exception e) {
            System.err.println("Error setting up continuous query: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
```

## Understanding Continuous Queries

Continuous queries are a powerful feature of Ignite that allow you to monitor for specific conditions in your data and receive notifications when those conditions are met. Unlike traditional queries that run once and return results, continuous queries keep running and notify you whenever the data changes and matches your criteria.

In our example, we're using a continuous query to detect service disruptions by looking for vehicles that:
1. Are in a "STOPPED_AT" status
2. Haven't updated their position in more than 5 minutes

This could indicate a vehicle that's experiencing a delay or other service issue.

The continuous query has several key components:

1. **The Query**: This defines what we're looking for, using standard SQL syntax.
2. **The Listener**: This is called whenever the query finds matching results.
3. **The Cursor**: This represents the running query and can be used to stop it later.

## Benefits of Continuous Queries

Using continuous queries for monitoring provides several advantages:

1. **Realtime Alerts**: Get immediate notification when conditions are met
2. **Reduced Network Traffic**: Only receive the specific data that matches your criteria
3. **Server-Side Processing**: The filtering happens on the server, not the client
4. **Scalability**: Works well even with large datasets

In a production system, you might extend this with additional functionality like:
- Sending notifications to operators
- Logging incidents to a database
- Triggering automated recovery procedures
- Calculating service level metrics

Continuous queries are just one way Ignite supports realtime monitoring and event processing, making it ideal for applications like our transit monitoring system.
