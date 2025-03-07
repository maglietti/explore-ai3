-- Calculate average invoice value by country
SELECT
    i.BillingCountry,
    AVG(i.Total) AS AvgInvoiceValue,
    COUNT(i.InvoiceId) AS NumberOfInvoices
FROM
    Invoice i
GROUP BY
    i.BillingCountry
ORDER BY
    AvgInvoiceValue DESC;