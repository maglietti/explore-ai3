# Exploring Transit Data with Apache Ignite SQL

In this module, you'll learn how to leverage Apache Ignite's SQL capabilities to extract meaningful insights from your transit data. By understanding key query patterns, you'll be able to answer important operational questions about your transit system in real-time using the Ignite CLI.

> **Note to Readers**
>
> This module on SQL queries is designed to help you understand how to extract insights from your transit data using Apache Ignite's SQL capabilities. While the knowledge gained here will enhance your understanding of the transit monitoring system, **this module is optional** and can be skipped if you'd prefer to complete the application first.
>
> You can always return to this module later to learn how to create custom queries for analyzing your transit data. If you choose to skip ahead, continue to [Module 7: Adding a Service Monitor](07-continuous-query.md) to implement the monitoring system that detects service disruptions.
>
> For those who are interested in data analysis or want to understand how the queries in the monitoring system work, we recommend working through this module now.

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

3. Type `sql` and hit enter. You can now run SQL queries directly:

   ```text
   sql-cli> SELECT COUNT(*) FROM vehicle_positions;
   ```

The CLI enables interactive exploration of your transit data, making it easy to try different queries and immediately see results. Let's explore some useful query patterns.

> **Note**: The Ignite CLI provides an SQL interface similar to tools like MySQL or PostgreSQL clients. You can run standard SQL queries, view results in a tabular format, and explore your data interactively. This is particularly useful for ad-hoc analysis and debugging.

> **Checkpoint #1**: Before proceeding, make sure you've:
>
> - Started the Ignite CLI tool
> - Connected to your Ignite node successfully
> - Entered SQL mode
> - Run a simple query to verify connectivity

## Query: Finding Vehicles on a Specific Route

One of the most common operational needs is to track all vehicles currently operating on a particular route. This query retrieves only the most recent position for each vehicle on the specified route:

```sql
-- Find all vehicles currently on route 30
WITH latest_positions AS (
    SELECT vehicle_id, MAX(time_stamp) as latest_time
    FROM vehicle_positions
    WHERE route_id = '30'
    GROUP BY vehicle_id
)
SELECT 
    vp.vehicle_id, 
    vp.route_id, 
    vp.latitude, 
    vp.longitude, 
    vp.time_stamp, 
    vp.current_status
FROM vehicle_positions vp
JOIN latest_positions lp ON vp.vehicle_id = lp.vehicle_id AND vp.time_stamp = lp.latest_time
ORDER BY vp.vehicle_id;
```

### Understanding This Query

This query uses a Common Table Expression (CTE) rather than a correlated subquery to find the latest position for each vehicle:

1. The CTE `latest_positions` finds the latest timestamp for each vehicle on route 30
2. The main query joins vehicle_positions with this CTE to get only the latest position data
3. Results are ordered by vehicle_id for readability

> **Note**: A Common Table Expression (CTE) is a temporary named result set that you can reference within a SELECT, INSERT, UPDATE, or DELETE statement. It's defined using the `WITH` clause. CTEs make complex queries more readable by breaking them into logical building blocks.

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

### Why Use a CTE Instead of a Subquery?

We use a CTE instead of a correlated subquery for several reasons:

1. **Performance**: CTEs are often more efficient because the database can compute them once and reuse the result
2. **Readability**: The query logic is more clearly separated and easier to understand
3. **Maintainability**: Each logical part is named, making the query easier to modify or debug

## Query: Finding the Nearest Vehicles to a Location

This query is useful for location-based services, finding vehicles closest to a given geographic point:

```sql
-- Find the 10 nearest vehicles to a specific location (e.g., downtown San Francisco coordinates)
WITH latest_positions AS (
    SELECT vehicle_id, MAX(time_stamp) as latest_time
    FROM vehicle_positions
    GROUP BY vehicle_id
)
SELECT 
    vp.vehicle_id, 
    vp.route_id, 
    vp.latitude, 
    vp.longitude, 
    vp.time_stamp, 
    vp.current_status,
    SQRT(POWER(vp.latitude - 37.7749, 2) + POWER(vp.longitude - (-122.4194), 2)) as distance
FROM vehicle_positions vp
JOIN latest_positions lp ON vp.vehicle_id = lp.vehicle_id AND vp.time_stamp = lp.latest_time
ORDER BY distance ASC
LIMIT 10;
```

## Understanding the Query Structure

This query uses a Common Table Expression (WITH clause) to efficiently find the nearest vehicles in two steps:

1. First, the `latest_positions` subquery finds the most recent timestamp for each vehicle
2. Then, we join this result with the main table to get only the latest position data
3. Finally, we calculate distances and sort to find the closest vehicles

This approach avoids correlated subqueries which can cause transaction-related issues in Ignite.

## Understanding the Distance Calculation

The formula `SQRT(POWER(latitude - 37.7749, 2) + POWER(longitude - (-122.4194), 2))` calculates the straight-line distance between two points:

- `POWER(latitude - 37.7749, 2)` squares the difference in latitudes
- `POWER(longitude - (-122.4194), 2)` squares the difference in longitudes
- `SQRT(...)` takes the square root of the sum

For short distances, this approach works well for sorting by proximity. The coordinates used (37.7749, -122.4194) represent downtown San Francisco.

When executed, you'll see results like:

```text
vehicle_id | route_id | latitude   | longitude    | time_stamp           | current_status | distance
-----------+----------+------------+--------------+----------------------+---------------+----------
8630       | 25       | 37.8204    | -122.3719    | 2025-03-19 16:15:04  | INCOMING_AT   | 0.05412
8918       | 19       | 37.7288    | -122.3672    | 2025-03-19 16:15:04  | STOPPED_AT    | 0.05784
... [additional rows] ...
```

This query is valuable for answering questions like:

- Which vehicles are closest to a specific location?
- Are there any vehicles available near a passenger?
- Which routes have coverage in a specific area?

> **Checkpoint #2**: Try running these first two queries in the Ignite CLI. Make sure you understand:
>
> - How the CTEs are being used to find the latest positions
> - What the distance calculation does and its limitations
> - How to interpret the results

## Query: Counting Active Vehicles by Route

For operational monitoring, it's often useful to count how many vehicles are currently active on each route:

```sql
SELECT 
    route_id, 
    COUNT(DISTINCT vehicle_id) as vehicle_count 
FROM vehicle_positions
WHERE 
    time_stamp > CURRENT_TIMESTAMP - INTERVAL '15' MINUTE
GROUP BY route_id
ORDER BY vehicle_count DESC;
```

This query:

- Filters positions from the last 15 minutes only
- Counts distinct vehicles per route (preventing duplicates if a vehicle reports multiple times)
- Orders results to show the busiest routes first

> **Note**: `CURRENT_TIMESTAMP` returns the current date and time. The `INTERVAL` keyword creates a time interval, which can be added to or subtracted from date/time values. Together with `WHERE` clause filtering, this allows us to create a 15-minute sliding window of recent data.

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

### Understanding GROUP BY and Aggregation

The `GROUP BY` clause divides the data into groups, and the `COUNT` function calculates a value for each group. In this query:

1. `GROUP BY route_id` creates a separate group for each route
2. `COUNT(DISTINCT vehicle_id)` counts unique vehicles in each group
3. `ORDER BY vehicle_count DESC` sorts routes with the most vehicles first

This pattern is extremely useful for summarizing data and identifying patterns or outliers.

## Query: Analyzing Vehicle Statuses

To understand the overall operational status of your transit system:

```sql
-- Analyze the distribution of vehicle statuses for the last 15 minutes
WITH total_count AS (
    SELECT COUNT(*) as total 
    FROM vehicle_positions 
    WHERE time_stamp > CURRENT_TIMESTAMP - INTERVAL '15' MINUTE
)
SELECT 
    current_status, 
    COUNT(*) as status_count,
    (COUNT(*) * 100.0 / (SELECT total FROM total_count)) as percentage
FROM vehicle_positions
WHERE time_stamp > CURRENT_TIMESTAMP - INTERVAL '15' MINUTE
GROUP BY current_status
ORDER BY status_count DESC;
```

This query:

1. Uses a CTE to calculate the total count once
2. Filters for recent positions (last 15 minutes)
3. Groups by the current_status field
4. Calculates both the absolute count and percentage for each status
5. Orders results by count in descending order

> **Note**: By calculating the total count first in a CTE, we avoid having to perform that calculation repeatedly for each row. This is more efficient and ensures consistent percentages even if the underlying data changes during query execution.

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
WITH latest_positions AS (
    SELECT vehicle_id, MAX(time_stamp) as max_time
    FROM vehicle_positions
    GROUP BY vehicle_id
)
SELECT vp.vehicle_id, vp.route_id, vp.latitude, vp.longitude, vp.time_stamp
FROM vehicle_positions vp
JOIN latest_positions latest ON vp.vehicle_id = latest.vehicle_id AND vp.time_stamp = latest.max_time
WHERE vp.current_status = 'STOPPED_AT'
ORDER BY vp.route_id, vp.vehicle_id;
```

This query uses a CTE to find the most recent timestamp for each vehicle, then joins with the main table and filters for vehicles with a 'STOPPED_AT' status.

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
WITH latest_positions AS (
    SELECT vehicle_id, MAX(time_stamp) AS max_time_stamp
    FROM vehicle_positions
    GROUP BY vehicle_id
)
SELECT vp.vehicle_id, vp.route_id, vp.latitude, vp.longitude, vp.time_stamp, vp.current_status
FROM vehicle_positions vp
JOIN latest_positions latest ON vp.vehicle_id = latest.vehicle_id AND vp.time_stamp = latest.max_time_stamp
WHERE vp.latitude BETWEEN 37.75 AND 37.80 AND
      vp.longitude BETWEEN -122.45 AND -122.40
ORDER BY vp.vehicle_id;
```

This query restricts results to vehicles within a rectangular area defined by latitude and longitude boundaries - in this case, covering a portion of downtown San Francisco. The JOIN approach efficiently finds the most recent position for each vehicle by first determining the latest timestamp per vehicle, then joining with the main table.

> **Note**: The `BETWEEN` operator is a shorthand for `>= AND <=` comparisons. It's a convenient way to filter values within a range. Here, we're creating a geographic "bounding box" to find vehicles in a specific area.

Example output:

```text
vehicle_id | route_id | latitude | longitude | time_stamp | current_status
-----------+----------+-------------+---------------+----------------------+---------------
1042 | 5 | 37.78412 | -122.40719 | 2025-03-18 14:22:41 | IN_TRANSIT_TO
1058 | F | 37.77925 | -122.41288 | 2025-03-18 14:22:37 | STOPPED_AT
... [additional rows] ...
```

This query is useful for:

- Monitoring coverage in specific neighborhoods
- Analyzing vehicle distribution in high-traffic areas
- Identifying vehicles that might be affected by localized events

> **Checkpoint #3**: Make sure you understand:
>
> - How to use the `BETWEEN` operator for range filtering
> - How the query uses both geographic and time-based filtering
> - How to create your own bounding box for a different geographic area

## Query: Finding Delayed Vehicles

To detect service disruptions, you can identify vehicles that have been stopped for an extended period:

```sql
-- Find vehicles that have been stopped for too long (possible service disruption)
WITH latest_positions AS (
    SELECT vehicle_id, MAX(time_stamp) as latest_ts
    FROM vehicle_positions
    GROUP BY vehicle_id
)
SELECT v.vehicle_id, v.route_id, v.current_status, v.time_stamp,
       TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as minutes_delayed
FROM vehicle_positions v
JOIN latest_positions latest ON v.vehicle_id = latest.vehicle_id AND v.time_stamp = latest.latest_ts
WHERE v.current_status = 'STOPPED_AT'
AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) > 5
ORDER BY minutes_delayed DESC;
```

This query uses a CTE to find the latest timestamp for each vehicle, then filters for vehicles that have been stopped for more than 5 minutes.

> **Note**: `TIMESTAMPDIFF` is a function that calculates the difference between two timestamps in a specified unit (in this case, minutes). It's a convenient way to calculate time intervals for time-series analysis.

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
LIMIT 20;
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
  EXTRACT(HOUR FROM time_stamp) as hour_of_day, 
  COUNT(DISTINCT vehicle_id) as vehicle_count
FROM vehicle_positions
GROUP BY EXTRACT(HOUR FROM time_stamp)
ORDER BY hour_of_day;
```

This query counts unique vehicles by hour, showing how fleet deployment changes throughout the day. Note that we're using `EXTRACT(HOUR FROM time_stamp)` which is the proper syntax for Ignite 3.

> **Note**: The `EXTRACT` function pulls a specific part (like hour, day, or month) from a date or timestamp. This is useful for time-based analysis across different time periods. Here, we're using it to group data by the hour of the day regardless of the date.

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

> **Checkpoint #4**: Try creating a query that:
>
> - Shows the count of vehicles by status for each route
> - Finds delays at a specific geographic location
> - Identifies vehicles that have reported positions most frequently

## Sample Analysis Scenario

Using these queries, a transit system operator could follow this workflow to investigate service quality:

1. **Check system-wide vehicle distribution**

   ```sql
   -- Get current vehicle count per route across the system
   WITH latest_positions AS (
       SELECT vehicle_id, MAX(time_stamp) as latest_time
       FROM vehicle_positions
       GROUP BY vehicle_id
   )
   SELECT vp.route_id, COUNT(vp.vehicle_id) as vehicle_count 
   FROM vehicle_positions vp
   JOIN latest_positions lp ON vp.vehicle_id = lp.vehicle_id AND vp.time_stamp = lp.latest_time
   GROUP BY vp.route_id
   ORDER BY vehicle_count DESC;
   ```

2. **Identify potential service disruptions**

   ```sql
   -- Find vehicles stopped for more than 5 minutes
   WITH latest_positions AS (
       SELECT vehicle_id, MAX(time_stamp) as latest_ts
       FROM vehicle_positions
       GROUP BY vehicle_id
   )
   SELECT v.vehicle_id, v.route_id, v.current_status, v.time_stamp,
          TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) as minutes_delayed
   FROM vehicle_positions v
   JOIN latest_positions latest ON v.vehicle_id = latest.vehicle_id AND v.time_stamp = latest.latest_ts
   WHERE v.current_status = 'STOPPED_AT'
   AND TIMESTAMPDIFF(MINUTE, v.time_stamp, CURRENT_TIMESTAMP) > 5
   ORDER BY minutes_delayed DESC;
   ```

3. **Investigate a specific delayed vehicle**

   ```sql
   -- Get history for a specific vehicle
   SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
   FROM vehicle_positions
   WHERE vehicle_id = '5790'
   ORDER BY time_stamp DESC
   LIMIT 20;
   ```

4. **Check other vehicles on the same route**

   ```sql
   -- Find all current vehicles on route 24
   WITH latest_positions AS (
       SELECT vehicle_id, MAX(time_stamp) as latest_time
       FROM vehicle_positions
       WHERE route_id = '24'
       GROUP BY vehicle_id
   )
   SELECT vp.vehicle_id, vp.route_id, vp.latitude, vp.longitude, vp.time_stamp, vp.current_status
   FROM vehicle_positions vp
   JOIN latest_positions lp ON vp.vehicle_id = lp.vehicle_id AND vp.time_stamp = lp.latest_time
   ORDER BY vp.vehicle_id;
   ```

This workflow demonstrates how SQL queries can provide actionable insights for transit operations, enabling real-time monitoring and decision-making.

## Next Steps

You've now learned how to use Apache Ignite's SQL capabilities through the CLI to extract valuable insights from your transit data. These query patterns form the foundation for more advanced monitoring and analysis features.

In the next module, we'll build on these insights by implementing a continuous monitoring service that watches for specific conditions and triggers alerts when potential issues are detected.

> **Final Module Checkpoint**: Before proceeding, make sure you:
>
> - Understand how to query the most recent vehicle positions
> - Can filter vehicle data by geographic area and time window
> - Know how to detect potential service disruptions
> - Can analyze vehicle distribution across routes and time periods
> - Feel comfortable writing your own SQL queries to answer operational questions

> **Next Steps:** Continue to [Module 7: Adding a Service Monitor](07-continuous-query.md) to implement a monitoring system that detects service disruptions in real-time.
