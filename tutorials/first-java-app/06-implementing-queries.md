# Exploring Transit Data with Apache Ignite SQL

In this module, you'll learn how to leverage Apache Ignite's SQL capabilities to extract meaningful insights from your transit data. By understanding key query patterns, you'll be able to answer important operational questions about your transit system in real-time using the Ignite CLI.

## Using the Ignite CLI for SQL Queries

The Ignite CLI provides a convenient way to interact with your data using standard SQL. Before diving into specific queries, let's connect to our Ignite cluster:

1. Start the Ignite CLI tool:

   ```bash
   docker run --rm -it --network=host -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli
   ```

2. Connect to your node:

   ```text
   connect http://localhost:10300
   ```

3. You can now run SQL queries directly:

   ```text
   sql> SELECT COUNT(*) FROM vehicle_positions;
   ```

The CLI enables interactive exploration of your transit data, making it easy to try different queries and immediately see results. Let's explore some useful query patterns.

## Query: Finding Vehicles on a Specific Route

One of the most common operational needs is to track all vehicles currently operating on a particular route. This query retrieves only the most recent position for each vehicle on the specified route:

```sql
-- Find all vehicles currently on route 30
SELECT 
    vehicle_id, 
    route_id, 
    latitude, 
    longitude, 
    time_stamp, 
    current_status
FROM vehicle_positions vp
WHERE 
    route_id = '30' AND
    time_stamp = (
        SELECT MAX(time_stamp) 
        FROM vehicle_positions
        WHERE vehicle_id = vp.vehicle_id AND route_id = '30'
    )
ORDER BY vehicle_id
```

### Understanding This Query

This query uses a correlated subquery to find the latest position for each vehicle:

1. The outer query selects position data for vehicles on route 30
2. The subquery `(SELECT MAX(time_stamp)...)` finds the latest timestamp for each vehicle
3. The correlation happens through `vp.vehicle_id` in the subquery
4. Results are ordered by vehicle_id for readability

### Sample Results

Here's what the output might look like:

```text
vehicle_id | route_id | latitude    | longitude    | time_stamp           | current_status
-----------+----------+-------------+--------------+----------------------+--------------
1234       | 30       | 37.7749     | -122.4194    | 2023-03-18 15:42:18  | IN_TRANSIT_TO
1235       | 30       | 37.7833     | -122.4167    | 2023-03-18 15:42:20  | STOPPED_AT
1236       | 30       | 37.7879     | -122.4074    | 2023-03-18 15:42:15  | IN_TRANSIT_TO
...
```

This query pattern is useful for answering questions like:

- How many vehicles are currently serving route 30?
- Where exactly is each vehicle on the route right now?
- What's the current status of vehicles on this route?

## Query: Finding the Nearest Vehicles to a Location

This query is useful for location-based services, finding vehicles closest to a given geographic point:

```sql
-- Find the 10 nearest vehicles to a specific location (e.g., downtown coordinates)
SELECT 
    vp.vehicle_id, 
    vp.route_id, 
    vp.latitude, 
    vp.longitude, 
    vp.time_stamp, 
    vp.current_status,
    SQRT(POWER(vp.latitude - 40.7128, 2) + POWER(vp.longitude - (-74.0060), 2)) as distance
FROM vehicle_positions vp
WHERE 
    vp.time_stamp = (
        SELECT MAX(time_stamp)
        FROM vehicle_positions
        WHERE vehicle_id = vp.vehicle_id
    )
ORDER BY distance ASC
LIMIT 10
```

### Understanding the Distance Calculation

The formula `SQRT(POWER(latitude - 37.7749, 2) + POWER(longitude - (-122.4194), 2))` calculates the straight-line distance between two points:

- `POWER(latitude - 37.7749, 2)` squares the difference in latitudes
- `POWER(longitude - (-122.4194), 2)` squares the difference in longitudes
- `SQRT(...)` takes the square root of the sum

For short distances, this approach works well for sorting by proximity. The coordinates used (37.7749, -122.4194) represent downtown San Francisco.

When executed, you'll see results like:

```text
vehicle_id | route_id | latitude   | longitude    | time_stamp           | current_status | distance
-----------+----------+------------+--------------+----------------------+---------------+----------
1252       | 38       | 37.77512   | -122.41951   | 2025-03-18 14:23:05  | STOPPED_AT    | 0.00134
1098       | 27       | 37.77402   | -122.42015   | 2025-03-18 14:22:47  | IN_TRANSIT_TO | 0.00154
... [additional rows] ...
```

This query is valuable for answering questions like:

- Which vehicles are closest to a specific location?
- Are there any vehicles available near a passenger?
- Which routes have coverage in a specific area?

## Query: Counting Active Vehicles by Route

For operational monitoring, it's often useful to count how many vehicles are currently active on each route:

```sql
-- Count active vehicles by route (vehicles with updates in the last 15 minutes)
SELECT 
    route_id, 
    COUNT(DISTINCT vehicle_id) as vehicle_count 
FROM vehicle_positions
WHERE 
    time_stamp > DATEADD(MINUTE, -15, CURRENT_TIMESTAMP)
GROUP BY route_id
ORDER BY vehicle_count DESC
```

This query uses a subquery to first identify the most recent position for each vehicle, then counts how many vehicles are on each route.

Example output:

```text
route_id | vehicle_count
---------+--------------
14       | 18
38       | 16
22       | 15
5        | 14
... [additional rows] ...
```

This information helps answer:

- Which routes have the most vehicles in service?
- Is there adequate coverage across all routes?
- How is the fleet currently distributed?

## Query: Analyzing Vehicle Statuses

To understand the overall operational status of your transit system:

```sql
-- Analyze the distribution of vehicle statuses
SELECT 
    current_status, 
    COUNT(*) as count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vehicle_positions WHERE time_stamp > DATEADD(MINUTE, -15, CURRENT_TIMESTAMP)) as percentage
FROM vehicle_positions
WHERE time_stamp > DATEADD(MINUTE, -15, CURRENT_TIMESTAMP)
GROUP BY current_status
ORDER BY count DESC
```

This query:

1. Filters for recent positions (last 15 minutes)
2. Groups by the current_status field
3. Calculates both the absolute count and percentage for each status
4. Orders results by count in descending order

The percentage calculation uses a subquery to get the total record count as the denominator.

```text
current_status | count | percentage
--------------+-------+------------
IN_TRANSIT_TO | 342   | 63.3
STOPPED_AT    | 198   | 36.7
UNKNOWN       | 0     | 0.0
```

## Query: Finding Vehicles with a Specific Status

To identify potential service issues, you might want to find all vehicles that are currently stopped:

```sql
-- Find all vehicles currently stopped at a station or stop
SELECT vehicle_id, route_id, latitude, longitude, time_stamp
FROM vehicle_positions vp
WHERE current_status = 'STOPPED_AT' AND
      time_stamp = (SELECT MAX(time_stamp) 
                   FROM vehicle_positions
                   WHERE vehicle_id = vp.vehicle_id)
ORDER BY route_id, vehicle_id
```

This query follows the same pattern as our previous queries but filters on `current_status` instead of `route_id`.

Example results:

```text
vehicle_id | route_id | latitude    | longitude     | time_stamp
-----------+----------+-------------+---------------+----------------------
1056       | 1        | 37.77933    | -122.39491    | 2025-03-18 14:22:38
1089       | 1        | 37.79398    | -122.40518    | 2025-03-18 14:22:51
... [additional rows] ...
```

This query helps identify:

- Which vehicles are currently stopped at stations/stops?
- Are there unusual patterns of stopped vehicles?
- Which routes have the most vehicles stopped?

## Query: Finding Vehicles in a Geographic Area

To monitor specific regions, you can query for vehicles within a geographic boundary:

```sql
-- Find all vehicles currently in downtown San Francisco
SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
FROM vehicle_positions vp
WHERE latitude BETWEEN 37.75 AND 37.80 AND
      longitude BETWEEN -122.45 AND -122.40 AND
      time_stamp = (SELECT MAX(time_stamp) 
                   FROM vehicle_positions
                   WHERE vehicle_id = vp.vehicle_id)
ORDER BY vehicle_id
```

This query restricts results to vehicles within a rectangular area defined by latitude and longitude boundaries - in this case, covering a portion of downtown San Francisco.

Example output:

```text
vehicle_id | route_id | latitude    | longitude     | time_stamp           | current_status
-----------+----------+-------------+---------------+----------------------+---------------
1042       | 5        | 37.78412    | -122.40719    | 2025-03-18 14:22:41  | IN_TRANSIT_TO
1058       | F        | 37.77925    | -122.41288    | 2025-03-18 14:22:37  | STOPPED_AT
... [additional rows] ...
```

This query is useful for:

- Monitoring coverage in specific neighborhoods
- Analyzing vehicle distribution in high-traffic areas
- Identifying vehicles that might be affected by localized events

## Query: Finding Delayed Vehicles

To detect service disruptions, you can identify vehicles that have been stopped for an extended period:

```sql
-- Find vehicles that have been stopped for too long (possible service disruption)
SELECT v.vehicle_id, v.route_id, v.current_status, v.time_stamp,
       TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as minutes_delayed
FROM vehicle_positions v
JOIN (
  SELECT vehicle_id, MAX(time_stamp) as latest_ts
  FROM vehicle_positions
  GROUP BY vehicle_id
) latest ON v.vehicle_id = latest.vehicle_id AND v.time_stamp = latest.latest_ts
WHERE v.current_status = 'STOPPED_AT'
AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) > 5
ORDER BY minutes_delayed DESC
```

This query joins the vehicle positions table with a subquery that finds the latest timestamp for each vehicle, then filters for vehicles that have been stopped for more than 5 minutes.

Example results:

```text
vehicle_id | route_id | current_status | time_stamp           | minutes_delayed
-----------+----------+----------------+----------------------+----------------
1112       | 24       | STOPPED_AT     | 2025-03-18 14:10:05  | 13
1074       | 30       | STOPPED_AT     | 2025-03-18 14:12:22  | 11
... [additional rows] ...
```

This query helps identify:

- Which vehicles may be experiencing delays?
- Are there patterns in where delays are occurring?
- Which routes have the most delayed vehicles?

## Query: Analyzing Vehicle Movement Over Time

To understand a vehicle's journey, we can retrieve its position history:

```sql
-- Retrieve the recent movement history for a specific vehicle
SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
FROM vehicle_positions
WHERE vehicle_id = '1056'
ORDER BY time_stamp DESC
LIMIT 20
```

This query shows the 20 most recent positions for a specific vehicle, ordered by timestamp.

Example output:

```text
vehicle_id | route_id | latitude    | longitude     | time_stamp           | current_status
-----------+----------+-------------+---------------+----------------------+---------------
1056       | 1        | 37.77933    | -122.39491    | 2025-03-18 14:22:38  | STOPPED_AT
1056       | 1        | 37.77933    | -122.39491    | 2025-03-18 14:21:08  | STOPPED_AT
1056       | 1        | 37.77845    | -122.39588    | 2025-03-18 14:19:42  | IN_TRANSIT_TO
... [additional rows] ...
```

This history helps answer:

- What path did this vehicle take?
- How long did it spend at each stop?
- Has it been progressing normally along its route?

## Query: Hourly Vehicle Count Statistics

To analyze patterns throughout the day, we can group by hour:

```sql
-- Analyze how many unique vehicles are active during each hour of the day
SELECT 
  HOUR(time_stamp) as hour_of_day, 
  COUNT(DISTINCT vehicle_id) as vehicle_count
FROM vehicle_positions
GROUP BY HOUR(time_stamp)
ORDER BY hour_of_day
```

This query counts unique vehicles by hour, showing how fleet deployment changes throughout the day.

Example results:

```text
hour_of_day | vehicle_count
------------+--------------
6           | 124
7           | 352
8           | 487
... [additional rows] ...
```

This analysis helps understand:

- When are peak service hours?
- How does vehicle deployment change throughout the day?
- Are there any unusual patterns in vehicle availability?

## Sample Analysis Scenario

Using these queries, a transit system operator could follow this workflow to investigate service quality:

1. **Check system-wide vehicle distribution**

   ```sql
   SELECT route_id, COUNT(vehicle_id) as vehicle_count 
   FROM (
       SELECT positions.vehicle_id, positions.route_id
       FROM vehicle_positions positions
       WHERE positions.time_stamp = (SELECT MAX(time_stamp)
                                    FROM vehicle_positions
                                    WHERE vehicle_id = positions.vehicle_id)
   ) vp
   GROUP BY route_id
   ORDER BY vehicle_count DESC
   ```

2. **Identify potential service disruptions**

   ```sql
   SELECT v.vehicle_id, v.route_id, v.current_status, v.time_stamp,
          TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as minutes_delayed
   FROM vehicle_positions v
   JOIN (
     SELECT vehicle_id, MAX(time_stamp) as latest_ts
     FROM vehicle_positions
     GROUP BY vehicle_id
   ) latest ON v.vehicle_id = latest.vehicle_id AND v.time_stamp = latest.latest_ts
   WHERE v.current_status = 'STOPPED_AT'
   AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) > 5
   ORDER BY minutes_delayed DESC
   ```

3. **Investigate a specific delayed vehicle**

   ```sql
   SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
   FROM vehicle_positions
   WHERE vehicle_id = '1112'
   ORDER BY time_stamp DESC
   LIMIT 20
   ```

4. **Check other vehicles on the same route**

   ```sql
   SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
   FROM vehicle_positions vp
   WHERE route_id = '24' AND
         time_stamp = (SELECT MAX(time_stamp) 
                      FROM vehicle_positions
                      WHERE vehicle_id = vp.vehicle_id)
   ORDER BY vehicle_id
   ```

This workflow demonstrates how SQL queries can provide actionable insights for transit operations, enabling real-time monitoring and decision-making.

## Next Steps

You've now learned how to use Apache Ignite's SQL capabilities through the CLI to extract valuable insights from your transit data. These query patterns form the foundation for more advanced monitoring and analysis features.

In the next module, we'll build on these insights by implementing a continuous monitoring service that watches for specific conditions and triggers alerts when potential issues are detected.

> **Next Steps:** Continue to [Module 7: Adding a Service Monitor](07-continuous-query.md) to implement a monitoring system that detects service disruptions in real-time.
