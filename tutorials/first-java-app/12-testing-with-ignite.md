# Testing with Ignite SQL

While our application is running, you can interact directly with the data in Ignite using SQL. This can be useful for debugging, verifying data, or exploring additional insights beyond what our application provides.

## Using the Ignite CLI

The Ignite CLI provides a convenient way to run SQL queries against your Ignite cluster. Here's how to use it:

1. Open a new terminal window
2. Navigate to your Ignite installation directory
3. Run the Ignite CLI tool:
   ```
   bin/ignite --client
   ```
4. Connect to your node:
   ```
   connect 127.0.0.1:10800
   ```
5. Now you can run SQL queries:
   ```
   sql> SELECT * FROM vehicle_positions LIMIT 5;
   ```

## Useful Verification Queries

Here are some useful SQL queries to verify and explore the data:

### Count total vehicle positions
```sql
SELECT COUNT(*) FROM vehicle_positions;
```

### See active vehicles by route
```sql
SELECT DISTINCT route_id, COUNT(DISTINCT vehicle_id) 
FROM vehicle_positions 
GROUP BY route_id
ORDER BY COUNT(DISTINCT vehicle_id) DESC;
```

### Find the latest position for each vehicle
```sql
SELECT DISTINCT ON (vehicle_id) 
  vehicle_id, route_id, latitude, longitude, current_status, timestamp
FROM vehicle_positions 
ORDER BY vehicle_id, timestamp DESC;
```

### Check for delayed vehicles
```sql
SELECT v.vehicle_id, v.route_id, v.current_status, v.timestamp
FROM vehicle_positions v
JOIN (
  SELECT vehicle_id, MAX(timestamp) as latest_ts
  FROM vehicle_positions
  GROUP BY vehicle_id
) latest ON v.vehicle_id = latest.vehicle_id AND v.timestamp = latest.latest_ts
WHERE v.current_status = 'STOPPED_AT'
AND v.timestamp < DATEADD('MINUTE', -5, CURRENT_TIMESTAMP());
```

### Get hourly vehicle count statistics
```sql
SELECT 
  HOUR(timestamp) as hour_of_day, 
  COUNT(DISTINCT vehicle_id) as vehicle_count
FROM vehicle_positions
GROUP BY HOUR(timestamp)
ORDER BY hour_of_day;
```

## Understanding the Query Results

The results from these queries can tell you a lot about your transit data:

1. **Total vehicle positions**: This shows how much data you've collected
2. **Active vehicles by route**: This shows which routes have the most vehicles
3. **Latest positions**: This shows where each vehicle is right now
4. **Delayed vehicles**: This identifies potential service disruptions
5. **Hourly statistics**: This shows how vehicle counts change throughout the day

These queries demonstrate some of Ignite's SQL capabilities, including:
- Time-based functions (DATEADD, CURRENT_TIMESTAMP)
- Window functions (DISTINCT ON)
- Aggregations (COUNT, GROUP BY)
- Joins and subqueries

Directly querying the data can provide insights that might not be immediately visible through the application's dashboard, making it a valuable debugging and exploration tool.
