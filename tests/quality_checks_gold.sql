/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Run after scripts/gold/ddl_gold.sql. Each check says what result to expect.
===============================================================================
*/

-- 1. Orphan check: every sale must find its customer and product.
-- Expected: no rows.
SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL 
   OR c.customer_key IS NULL;

-- 2. Joins must not duplicate customers.
-- Expected: both counts equal (18,484).
SELECT
    (SELECT COUNT(*) FROM gold.dim_customers) AS gold_customers,
    (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_customers;

-- 3. Surrogate keys must be unique.
-- Expected: no rows.
SELECT customer_key, COUNT(*) FROM gold.dim_customers GROUP BY customer_key HAVING COUNT(*) > 1;
SELECT product_key,  COUNT(*) FROM gold.dim_products  GROUP BY product_key  HAVING COUNT(*) > 1;

-- 4. One current row per product number (295 current products).
-- Expected: no rows.
SELECT product_number, COUNT(*) FROM gold.dim_products GROUP BY product_number HAVING COUNT(*) > 1;

-- 5. Fact must keep every sales row.
-- Expected: both counts equal (60,398).
SELECT
    (SELECT COUNT(*) FROM gold.fact_sales) AS gold_sales,
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_sales;

-- 6. Gender values after CRM/ERP integration.
-- Expected: Male 9,341; Female 9,128; n/a 15.
SELECT gender, COUNT(*) AS customers FROM gold.dim_customers GROUP BY gender;

-- 7. Products with no ERP category.
-- Expected: 7 rows, all cat_id CO_PE (not in erp_px_cat_g1v2).
SELECT * FROM gold.dim_products WHERE category IS NULL;
