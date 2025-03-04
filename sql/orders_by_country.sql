WITH country_stats AS (
    SELECT
        c.country AS country_name,
        SUM(i.total) AS total_order,
        AVG(i.total) AS avg_order,
        COUNT(i.invoiceid) AS no_of_orders,
        COUNT(DISTINCT c.customerid) AS no_of_customers
    FROM
        customer c
    JOIN 
        invoice i ON c.customerid = i.customerid
    GROUP BY
        c.country
    HAVING
        COUNT(DISTINCT c.customerid) > 1
)
SELECT
    country_name AS grouped_country,
    no_of_customers,
    no_of_orders,
    total_order AS total_value_order,
    ROUND(avg_order, 2) AS avg_order
FROM
    country_stats
ORDER BY
    no_of_orders DESC;