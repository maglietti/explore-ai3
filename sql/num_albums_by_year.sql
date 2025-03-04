SELECT 
    a.ReleaseYear,
    COUNT(DISTINCT a.AlbumId) AS NumberOfAlbums,
    COUNT(t.TrackId) AS NumberOfTracks
FROM 
    Album a
JOIN 
    Track t ON a.AlbumId = t.AlbumId
GROUP BY 
    a.ReleaseYear
ORDER BY 
    a.ReleaseYear;