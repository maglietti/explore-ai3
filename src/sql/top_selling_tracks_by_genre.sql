SELECT 
    g.Name AS Genre,
    t.Name AS TrackName,
    a.Name AS ArtistName,
    SUM(il.Quantity) AS TotalSold
FROM 
    Track t
    JOIN Genre g ON t.GenreId = g.GenreId
    JOIN Album al ON t.AlbumId = al.AlbumId
    JOIN Artist a ON al.ArtistId = a.ArtistId
    JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY 
    g.Name, t.Name, a.Name
ORDER BY 
    g.Name, TotalSold DESC
LIMIT 10;