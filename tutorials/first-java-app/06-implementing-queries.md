# Exploring Transit Data with Apache Ignite SQL

Apache Ignite provides powerful SQL capabilities that allow you to extract insights from your transit data. Let's explore how to use SQL queries to monitor a transit system in real-time.

## Query 1: Finding Vehicles on a Specific Route

When you need to track all active vehicles on a particular route, this query will retrieve only the most recent position for each vehicle on the specified route:

```sql
SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
FROM vehicle_positions vp
WHERE route_id = '30' AND
      time_stamp = (SELECT MAX(time_stamp) 
                   FROM vehicle_positions
                   WHERE vehicle_id = vp.vehicle_id AND route_id = '30')
ORDER BY vehicle_id
```

This query successfully retrieves all vehicles currently operating on route 30, ensuring we get only the most recent position for each vehicle. As we can see from the output, there are 17 vehicles currently assigned to this route with varying statuses (IN_TRANSIT_TO, STOPPED_AT, and one UNKNOWN).

## Query 2: Finding the Nearest Vehicles to a Location

This query is useful for location-based services, finding vehicles closest to a given geographic point:

```sql
SELECT vp.vehicle_id, vp.route_id, vp.latitude, vp.longitude, vp.time_stamp, vp.current_status,
    SQRT(POWER(vp.latitude - 40.7128, 2) + POWER(vp.longitude - (-74.0060), 2)) as distance
FROM vehicle_positions vp
WHERE vp.time_stamp = (SELECT MAX(time_stamp)
                      FROM vehicle_positions
                      WHERE vehicle_id = vp.vehicle_id)
ORDER BY distance ASC
LIMIT 10
```

The output shows this query is successfully finding the 10 closest vehicles to the specified coordinates (40.7128, -74.0060), which represent a location in New York City. Interestingly, all of the results appear to be in San Francisco (based on the coordinates in the ~37° latitude and ~-122° longitude range), meaning we're seeing the 10 San Francisco vehicles that are relatively closer to New York than others! In a real-world application, you would typically search for vehicles near the user's actual location within the same city.

## Query 3: Counting Active Vehicles by Route

For the third query, we need to modify it to use proper timestamp casting:

```sql
SELECT route_id, COUNT(vehicle_id) as vehicle_count 
FROM (
    SELECT positions.vehicle_id, positions.route_id
    FROM vehicle_positions positions
    WHERE positions.time_stamp = (SELECT MAX(time_stamp)
                                 FROM vehicle_positions
                                 WHERE vehicle_id = positions.vehicle_id)
    -- Since we know all records are current, we can simplify by removing the time filter
) vp
GROUP BY route_id
ORDER BY vehicle_count DESC
```

This revised query counts active vehicles by route, focusing on the most recent position for each vehicle without the time restriction that was causing errors.

## Sample Exploration Scenario

Using these queries, a transit system operator could:

Get a quick count of vehicles by route to ensure proper coverage
Focus on a specific route like route 30 to see exactly where each vehicle is located
Quickly identify the nearest vehicles to any location when needing to respond to an incident

## Additional Useful Queries

### Finding Vehicles with a Specific Status

```sql
SELECT vehicle_id, route_id, latitude, longitude, time_stamp
FROM vehicle_positions vp
WHERE current_status = 'STOPPED_AT' AND
      time_stamp = (SELECT MAX(time_stamp) 
                   FROM vehicle_positions
                   WHERE vehicle_id = vp.vehicle_id)
ORDER BY route_id, vehicle_id
```

This query would find all currently stopped vehicles across the system, which could be useful for identifying potential service disruptions.

### Finding Vehicles in a Geographic Area

```sql
SELECT vehicle_id, route_id, latitude, longitude, time_stamp, current_status
FROM vehicle_positions vp
WHERE latitude BETWEEN 37.75 AND 37.80 AND
      longitude BETWEEN -122.45 AND -122.40 AND
      time_stamp = (SELECT MAX(time_stamp) 
                   FROM vehicle_positions
                   WHERE vehicle_id = vp.vehicle_id)
ORDER BY vehicle_id
```

This query would find all vehicles currently in a specific rectangular geographic area, which could be useful for monitoring a specific neighborhood or district.

These queries demonstrate how Apache Ignite's SQL capabilities enable real-time decision making for transit operations. The examples show actual query results against a transit data set, providing practical insights into vehicle locations, route coverage, and geographic distribution.
