SELECT 
    g.Name AS Genre,
    COUNT(DISTINCT t.TrackId) AS UniqueTracksCount,
    SUM(il.Quantity) AS TotalTracksSold,
    SUM(il.Quantity * il.UnitPrice) AS TotalRevenue
FROM 
    Genre g
    JOIN Track t ON g.GenreId = t.GenreId
    JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY 
    g.Name
ORDER BY 
    TotalRevenue DESC;