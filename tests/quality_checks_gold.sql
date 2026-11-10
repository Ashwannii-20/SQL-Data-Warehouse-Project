/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Purpose:
  Validate Gold dimensions and fact view for:
  - Referential integrity
  - Source-to-Gold row and business-key reconciliation
  - Surrogate/business key uniqueness
  - Fact grain and row preservation
  - NULL and invalid values
  - Sales calculations and date sequence
  - Expected CRM/ERP integration outcomes

Run after: scripts/07_gold_views.sql
Database: DataWarehouse

Known source-data exception:
  19 sales records have NULL order dates in Silver and Gold.
  They are retained as NULL; no dates are fabricated.

Important:
  These are validation queries, not automatic pass/fail assertions.
  Review each result against the expected outcomes in the comments.
===============================================================================
*/

-- =====================================================================
-- 1. Referential integrity: every sale must find its customer and product.
-- Expected: 0 orphan sales.
-- =====================================================================

SELECT
    COUNT(*) AS orphan_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;

-- Optional detail: expected to return no rows.
SELECT
    f.order_number,
    f.customer_key,
    f.product_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;


-- =====================================================================
-- 2. Customer row-count reconciliation.
-- Expected: Gold = Silver = 18,484.
-- A matching count alone does not prove that the same IDs are present.
-- =====================================================================

SELECT
    (SELECT COUNT(*) FROM gold.dim_customers) AS gold_customers,
    (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_customers;

-- Expected: no rows (Silver customer IDs missing from Gold).
SELECT s.cst_id AS missing_customer_id
FROM silver.crm_cust_info s
LEFT JOIN gold.dim_customers g
    ON g.customer_id = s.cst_id
WHERE g.customer_id IS NULL;

-- Expected: no rows (unexpected Gold customer IDs).
SELECT g.customer_id AS extra_customer_id
FROM gold.dim_customers g
LEFT JOIN silver.crm_cust_info s
    ON s.cst_id = g.customer_id
WHERE s.cst_id IS NULL;


-- =====================================================================
-- 3. Surrogate key uniqueness.
-- Expected: both queries return no rows.
-- =====================================================================

SELECT customer_key, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

SELECT product_key, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- =====================================================================
-- 4. Product dimension checks.
-- Expected:
--   Gold current products = 295
--   Silver total = 397 (295 current + 102 historical)
--   Duplicate product numbers = 0
-- =====================================================================

SELECT COUNT(*) AS gold_current_products
FROM gold.dim_products;

SELECT
    COUNT(*) AS silver_total_products,
    SUM(CASE WHEN prd_end_dt IS NULL THEN 1 ELSE 0 END) AS current_products,
    SUM(CASE WHEN prd_end_dt IS NOT NULL THEN 1 ELSE 0 END) AS historical_products
FROM silver.crm_prd_info;

-- Expected: no rows (one current Gold row per product number).
SELECT product_number, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- Expected: 7 products; category_id should be CO_PE.
SELECT product_id, product_number, category_id, category
FROM gold.dim_products
WHERE category IS NULL;


-- =====================================================================
-- 5. Fact row-count reconciliation.
-- Expected: Gold = Silver = 60,398.
-- =====================================================================

SELECT
    (SELECT COUNT(*) FROM gold.fact_sales) AS gold_sales,
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_sales;


-- =====================================================================
-- 6. Fact grain uniqueness.
-- Assumed grain: one row per order_number + product_key.
-- Expected: no rows (no duplicate order/product combinations).
-- =====================================================================

SELECT
    order_number,
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.fact_sales
GROUP BY order_number, product_key
HAVING COUNT(*) > 1;


-- =====================================================================
-- 7. Critical NULL checks.
-- Expected:
--   order_date = 19 (known source-data exception)
--   All other listed columns = 0
-- =====================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_number IS NULL THEN 1 ELSE 0 END) AS null_order_number,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_key,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_key,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN shipping_date IS NULL THEN 1 ELSE 0 END) AS null_shipping_date,
    SUM(CASE WHEN due_date IS NULL THEN 1 ELSE 0 END) AS null_due_date,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN sales_amount IS NULL THEN 1 ELSE 0 END) AS null_sales_amount
FROM gold.fact_sales;


-- =====================================================================
-- 8. Sales calculation and value checks.
-- Expected: no rows.
-- Checks sales = quantity * price, positive quantity, and nonnegative
-- price and sales amount.
-- =====================================================================

SELECT
    order_number,
    quantity,
    price,
    sales_amount
FROM gold.fact_sales
WHERE sales_amount IS NULL
   OR quantity IS NULL
   OR price IS NULL
   OR quantity <= 0
   OR price < 0
   OR sales_amount < 0
   OR sales_amount <> quantity * price;


-- =====================================================================
-- 9. Date sequence checks.
-- Expected:
--   Missing order dates = 19 (known source-data exception)
--   Shipping before order = 0
--   Due date before order = 0
--   Shipping after due date = 0
-- =====================================================================

SELECT
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS missing_order_dates,
    SUM(CASE
        WHEN order_date IS NOT NULL
         AND shipping_date < order_date
        THEN 1 ELSE 0
    END) AS shipping_before_order,
    SUM(CASE
        WHEN order_date IS NOT NULL
         AND due_date < order_date
        THEN 1 ELSE 0
    END) AS due_before_order,
    SUM(CASE
        WHEN shipping_date > due_date
        THEN 1 ELSE 0
    END) AS shipping_after_due
FROM gold.fact_sales;


-- =====================================================================
-- 10. Gender distribution after CRM/ERP integration.
-- Expected based on the validated dataset:
--   Male 9,341; Female 9,128; n/a 15.
-- =====================================================================

SELECT gender, COUNT(*) AS customer_count
FROM gold.dim_customers
GROUP BY gender
ORDER BY gender;


-- =====================================================================
-- End of Gold quality checks
-- =====================================================================
