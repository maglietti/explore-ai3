-- Customer Retention Rate
WITH CurrentMonthCustomers AS (
    SELECT 
        CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
        CASE 
            WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
            THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
            ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        END AS YearMonth,
        i.CustomerId
    FROM 
        Invoice i
    GROUP BY 
        EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate), i.CustomerId
),
PreviousMonthCustomers AS (
    SELECT 
        CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
        CASE 
            WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
            THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
            ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        END AS YearMonth,
        i.CustomerId
    FROM 
        Invoice i
    GROUP BY 
        EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate), i.CustomerId
)
SELECT 
    curr.YearMonth,
    COUNT(DISTINCT curr.CustomerId) AS CurrentCustomers,
    COUNT(DISTINCT prev.CustomerId) AS ReturnCustomers,
    CASE 
        WHEN COUNT(DISTINCT prev.CustomerId) = 0 THEN 0
        ELSE (COUNT(DISTINCT curr.CustomerId) * 100.0 / COUNT(DISTINCT prev.CustomerId))
    END AS RetentionRate
FROM 
    CurrentMonthCustomers curr
LEFT JOIN 
    PreviousMonthCustomers prev ON 
    curr.CustomerId = prev.CustomerId AND 
    prev.YearMonth = (
        SELECT MAX(pm.YearMonth)
        FROM PreviousMonthCustomers pm
        WHERE pm.YearMonth < curr.YearMonth
    )
GROUP BY 
    curr.YearMonth
ORDER BY 
    curr.YearMonth DESC;