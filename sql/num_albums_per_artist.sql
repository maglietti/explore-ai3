SELECT 
    Artist.Name AS ArtistName, 
    COUNT(DISTINCT Album.AlbumId) AS NumberOfAlbums,
    COUNT(Track.TrackId) AS NumberOfTracks
FROM 
    Artist 
JOIN 
    Album ON Artist.ArtistId = Album.ArtistId 
JOIN
    Track ON Album.AlbumId = Track.AlbumId
GROUP BY 
    Artist.Name 
ORDER BY 
    NumberOfAlbums DESC, NumberOfTracks DESC
LIMIT 10;