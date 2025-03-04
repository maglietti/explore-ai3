-- Invoices for a specific customer
SELECT
    i.InvoiceId,
    i.InvoiceDate,
    i.Total,
    COUNT(il.InvoiceLineId) AS NumberOfItems
FROM
    Invoice i
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
WHERE
    i.CustomerId = 13
GROUP BY
    i.InvoiceId,
    i.InvoiceDate,
    i.Total
ORDER BY
    i.InvoiceDate DESC;