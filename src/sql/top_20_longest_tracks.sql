SELECT
    t.trackid,
    t.name AS track_name,
    ROUND(t.milliseconds / (1000 * 60), 2) AS duration_minutes
FROM
    track t
WHERE
    t.genreId < 17
ORDER BY
    duration_minutes DESC
LIMIT
    20;