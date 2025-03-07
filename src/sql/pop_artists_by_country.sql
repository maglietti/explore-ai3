SELECT 
    i.BillingCountry AS Country,
    a.Name AS ArtistName,
    COUNT(*) AS TracksPurchased
FROM 
    Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Album al ON t.AlbumId = al.AlbumId
    JOIN Artist a ON al.ArtistId = a.ArtistId
GROUP BY 
    i.BillingCountry, a.Name
ORDER BY 
    i.BillingCountry, TracksPurchased DESC;