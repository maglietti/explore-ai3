-- Monthly Revenue Trend
SELECT 
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT i.CustomerId) AS CustomerCount,
    SUM(i.Total) AS MonthlyRevenue,
    AVG(i.Total) AS AverageOrderValue
FROM 
    Invoice i
WHERE 
    i.InvoiceDate >= CAST('2024-03-01' AS DATE) -- Adjust this date as needed
    AND i.InvoiceDate < CAST('2025-03-01' AS DATE) -- Current date
GROUP BY 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate)
ORDER BY 
    YearMonth DESC;

-- Monthly Top Selling Artists
SELECT 
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    a.Name AS Artist,
    COUNT(DISTINCT il.TrackId) AS UniqueTracksSold,
    SUM(il.Quantity) AS TotalTracksSold,
    SUM(il.UnitPrice * il.Quantity) AS Revenue
FROM 
    Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Album al ON t.AlbumId = al.AlbumId
    JOIN Artist a ON al.ArtistId = a.ArtistId
WHERE 
    i.InvoiceDate >= CAST('2024-03-01' AS DATE) -- Adjust this date as needed
    AND i.InvoiceDate < CAST('2025-03-01' AS DATE) -- Current date
GROUP BY 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate), a.Name
ORDER BY 
    YearMonth DESC, Revenue DESC;

-- Monthly Sales by Country
SELECT 
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    i.BillingCountry AS Country,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT i.CustomerId) AS CustomerCount,
    SUM(i.Total) AS Revenue
FROM 
    Invoice i
WHERE 
    i.InvoiceDate >= CAST('2024-03-01' AS DATE) -- Adjust this date as needed
    AND i.InvoiceDate < CAST('2025-03-01' AS DATE) -- Current date
GROUP BY 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate), i.BillingCountry
ORDER BY 
    YearMonth DESC, Revenue DESC;