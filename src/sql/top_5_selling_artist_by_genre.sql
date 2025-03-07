WITH ArtistSalesByGenre AS (
    SELECT 
        g.Name AS Genre,
        a.Name AS ArtistName,
        SUM(il.Quantity) AS TotalSold
    FROM 
        Track t
        JOIN Genre g ON t.GenreId = g.GenreId
        JOIN Album al ON t.AlbumId = al.AlbumId
        JOIN Artist a ON al.ArtistId = a.ArtistId
        JOIN InvoiceLine il ON t.TrackId = il.TrackId
    GROUP BY 
        g.Name, a.Name
)
SELECT * FROM (
    SELECT 
        asg.*,
        (
            SELECT COUNT(*) + 1 
            FROM ArtistSalesByGenre asg2 
            WHERE asg2.Genre = asg.Genre AND asg2.TotalSold > asg.TotalSold
        ) AS RankInGenre
    FROM 
        ArtistSalesByGenre asg
) ranked
WHERE 
    RankInGenre <= 6
ORDER BY 
    Genre, RankInGenre;