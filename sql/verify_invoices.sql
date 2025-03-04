SELECT
    Invoice.InvoiceId,
    SUM(InvoiceLine.UnitPrice * InvoiceLine.Quantity) AS CalculatedTotal,
    Invoice.Total AS Total
FROM
    InvoiceLine
    INNER JOIN Invoice ON InvoiceLine.InvoiceId = Invoice.InvoiceId
GROUP BY
    Invoice.InvoiceId,
    Invoice.Total
LIMIT 10;

