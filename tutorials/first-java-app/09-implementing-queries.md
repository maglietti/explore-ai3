# Exploring Transit Data with Apache Ignite SQL

Apache Ignite provides powerful SQL capabilities that allow you to extract insights from your transit data. Let's explore the data using three key queries from our transit monitoring system.

## Query 1: Finding Vehicles on a Specific Route

```sql
SELECT DISTINCT ON (vehicle_id) 
    vehicle_id, route_id, latitude, longitude, timestamp, current_status 
FROM vehicle_positions 
WHERE route_id = ? 
ORDER BY vehicle_id, timestamp DESC
```

This query is perfect when you need to track all active vehicles on a particular route. For instance, if you're monitoring Route 42, you'd supply "42" as the parameter. The query uses `DISTINCT ON` to ensure you only get the latest position for each vehicle, avoiding duplicate entries for vehicles that have reported multiple positions.

## Query 2: Finding the Nearest Vehicles to a Location

```sql
SELECT DISTINCT ON (vehicle_id) 
    vehicle_id, route_id, latitude, longitude, timestamp, current_status, 
    SQRT(POWER(latitude - ?, 2) + POWER(longitude - ?, 2)) as distance 
FROM vehicle_positions 
ORDER BY vehicle_id, timestamp DESC, distance ASC 
LIMIT ?
```

This query is useful for location-based services. For example, if a passenger at coordinates (40.7128, -74.0060) wants to know which buses are nearby, this query calculates the distance between each vehicle and that location, then returns the closest ones. While it uses a simple Euclidean distance calculation, this approach works well for smaller geographic areas. In a production environment, you might replace this with a proper geospatial function for more accurate results over larger distances.

## Query 3: Counting Active Vehicles by Route

```sql
SELECT route_id, COUNT(DISTINCT vehicle_id) as vehicle_count 
FROM (
  SELECT DISTINCT ON (vehicle_id) 
    vehicle_id, route_id 
  FROM vehicle_positions 
  WHERE timestamp > ? 
  ORDER BY vehicle_id, timestamp DESC
) AS latest_positions 
GROUP BY route_id
```

This query provides a high-level view of your transit system's current activity. It first finds the most recent position for each vehicle that has reported within the last 5 minutes, then groups these positions by route to count how many active vehicles are operating on each route. This is valuable for dispatchers who need to ensure routes have adequate coverage or to identify routes that might be understaffed.

## Sample Exploration Scenario

Imagine you're a transit system operator during rush hour. You could use these queries to:

1. First, run the counts query to see which routes have fewer vehicles than expected:
   ```
   Route 15: 3 vehicles
   Route 22: 8 vehicles
   Route 42: 2 vehicles (should have 5)
   ```

2. Upon noticing Route 42 is understaffed, use the first query to see exactly where the two active vehicles are:
   ```
   Vehicle 42-101: Latitude 40.7123, Longitude -74.0082, Status "IN_TRANSIT_TO"
   Vehicle 42-103: Latitude 40.7255, Longitude -73.9983, Status "STOPPED_AT"
   ```

3. If you need to divert a vehicle from a nearby route, use the second query to find vehicles close to the understaffed route:
   ```
   Vehicle 38-107: 0.5 miles away
   Vehicle 25-112: 0.8 miles away
   Vehicle 31-104: 1.2 miles away
   ```

4. Based on this data, you might contact the driver of Vehicle 38-107 and ask them to assist with Route 42 once they complete their current segment.

These queries demonstrate how Apache Ignite's SQL capabilities enable real-time decision making for transit operations. By retrieving only the most recent and relevant data through well-crafted queries, you can maintain an efficient and responsive transit monitoring system.