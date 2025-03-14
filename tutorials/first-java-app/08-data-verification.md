# Verifying Data in Ignite

Before we continue building our business logic, let's make sure our data is properly stored in Ignite. This step is crucial to validate our data pipeline before developing more complex querying functionality.

Create a simple utility class to verify the data, `DataVerifier.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.SqlClientSession;
import org.apache.ignite.client.SqlResultCursor;
import org.apache.ignite.client.SqlRow;

public class DataVerifier {
    
    public static void verifyData() {
        IgniteClient client = IgniteConnection.getClient();
        SqlClientSession sqlSession = client.sql();
        
        System.out.println("Verifying data in vehicle_positions table...");
        
        // Check if table exists and has data
        try {
            String countSql = "SELECT COUNT(*) as count FROM vehicle_positions";
            SqlResultCursor cursor = sqlSession.execute(countSql);
            
            if (cursor.hasNext()) {
                SqlRow row = cursor.next();
                long count = row.getLong("count");
                
                System.out.println("✓ Table exists");
                System.out.println("✓ Table contains " + count + " records");
                
                if (count > 0) {
                    // Sample some data
                    String sampleSql = "SELECT * FROM vehicle_positions LIMIT 3";
                    cursor = sqlSession.execute(sampleSql);
                    
                    System.out.println("\nSample records:");
                    while (cursor.hasNext()) {
                        SqlRow record = cursor.next();
                        System.out.println("Vehicle: " + record.getString("vehicle_id") + 
                                          ", Route: " + record.getString("route_id") +
                                          ", Time: " + record.getTimestamp("timestamp"));
                    }
                    
                    // Get route statistics
                    String routeStatsSql = "SELECT route_id, COUNT(*) as record_count " +
                                         "FROM vehicle_positions " +
                                         "GROUP BY route_id " +
                                         "ORDER BY record_count DESC " +
                                         "LIMIT 5";
                    
                    cursor = sqlSession.execute(routeStatsSql);
                    
                    System.out.println("\nTop routes by number of records:");
                    while (cursor.hasNext()) {
                        SqlRow record = cursor.next();
                        System.out.println("Route " + record.getString("route_id") + 
                                          ": " + record.getLong("record_count") + " records");
                    }
                    
                    System.out.println("\n✓ Verification complete - data exists in Ignite");
                } else {
                    System.out.println("⚠ Table is empty. Let's start the ingestion service to load some data.");
                }
            }
        } catch (Exception e) {
            System.err.println("❌ Error verifying data: " + e.getMessage());
            e.printStackTrace();
        }
    }
}