SELECT
    t.trackId,
    g.name AS genre,
    a.name AS artist,
    al.title AS album,
    t.name AS track,
    t.milliseconds / (1000 * 60) AS duration_minutes
FROM
    track t
    INNER JOIN genre g ON t.genreId = g.genreId
    LEFT JOIN album al ON t.albumId = al.albumId
    LEFT JOIN artist a ON al.artistId = a.artistId
WHERE
    t.genreId < 17
ORDER BY
    duration_minutes DESC
LIMIT
    20;