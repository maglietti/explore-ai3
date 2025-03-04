-- Daily Sales Summary
SELECT 
    CAST(i.InvoiceDate AS DATE) AS SalesDate,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT i.CustomerId) AS CustomerCount,
    SUM(i.Total) AS DailyRevenue
FROM 
    Invoice i
WHERE 
    i.InvoiceDate >= CAST('2025-02-01' AS DATE) -- Last 30 days
    AND i.InvoiceDate < CAST('2025-03-01' AS DATE) -- Current date
GROUP BY 
    CAST(i.InvoiceDate AS DATE)
ORDER BY 
    SalesDate DESC;

-- Weekly Sales Trend
SELECT 
    EXTRACT(YEAR FROM i.InvoiceDate) AS YearValue,
    EXTRACT(WEEK FROM i.InvoiceDate) AS WeekNumber,
    MIN(CAST(i.InvoiceDate AS DATE)) AS WeekStartDate,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT i.CustomerId) AS CustomerCount,
    SUM(i.Total) AS WeeklyRevenue
FROM 
    Invoice i
WHERE 
    i.InvoiceDate >= CAST('2024-12-01' AS DATE) -- Last 12 weeks
    AND i.InvoiceDate < CAST('2025-03-01' AS DATE) -- Current date
GROUP BY 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(WEEK FROM i.InvoiceDate)
ORDER BY 
    YearValue DESC, WeekNumber DESC;