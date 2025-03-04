-- Create a new invoice with the next available invoice number
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, BillingAddress, BillingCity, 
                    BillingState, BillingCountry, BillingPostalCode, Total)
SELECT 
    (SELECT MAX(InvoiceId) + 1 FROM Invoice), -- Next available invoice ID
    14, -- CustomerID (Mark Philips)
    CURRENT_DATE, 
    '8210 111 ST NW', 
    'Edmonton', 
    'AB', 
    'Canada', 
    'T6G 2C7', 
    0.00; -- Initial total, will be updated

-- Get the new invoice ID for use in the line items
-- Note: We need to capture this in application code or use it directly in subsequent statements
-- For example, if we captured it as @new_invoice_id, we would use that variable below
-- However, in plain SQL without variables, we're using a subquery to get the same value

-- Add invoice line items
INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
SELECT 
    (SELECT MAX(InvoiceLineId) + 1 FROM InvoiceLine),
    (SELECT MAX(InvoiceId) FROM Invoice),
    1, -- TrackId
    0.99, -- UnitPrice
    1; -- Quantity

INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
SELECT 
    (SELECT MAX(InvoiceLineId) + 1 FROM InvoiceLine),
    (SELECT MAX(InvoiceId) FROM Invoice),
    2, -- TrackId
    0.99, -- UnitPrice
    1; -- Quantity

INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
SELECT 
    (SELECT MAX(InvoiceLineId) + 1 FROM InvoiceLine),
    (SELECT MAX(InvoiceId) FROM Invoice),
    3, -- TrackId
    0.99, -- UnitPrice
    1; -- Quantity

-- Calculate and update the total cost on the invoice
UPDATE Invoice
SET Total = (
    SELECT SUM(UnitPrice * Quantity)
    FROM InvoiceLine
    WHERE InvoiceId = (SELECT MAX(InvoiceId) FROM Invoice)
)
WHERE InvoiceId = (SELECT MAX(InvoiceId) FROM Invoice);