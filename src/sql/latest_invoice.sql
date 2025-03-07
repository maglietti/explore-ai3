SELECT i.InvoiceId, i.CustomerId, c.FirstName, c.LastName, 
       i.InvoiceDate, i.Total, i.BillingCountry, i.BillingCity,
       il.InvoiceLineId, t.Name AS TrackName, il.UnitPrice, il.Quantity
FROM Invoice i
JOIN Customer c ON i.CustomerId = c.CustomerId
JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
JOIN Track t ON il.TrackId = t.TrackId
WHERE i.InvoiceId IN (
    SELECT InvoiceId
    FROM Invoice
    ORDER BY InvoiceDate DESC, InvoiceId DESC
    LIMIT 1
)
ORDER BY i.InvoiceDate DESC, i.InvoiceId DESC, il.InvoiceLineId;