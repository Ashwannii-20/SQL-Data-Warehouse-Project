/*
====================================================================================
Quality Checks: Silver Layer
====================================================================================
Script Purpose:
  Checks the Silver tables for consistency, accuracy and standardisation:
  - Null or duplicate primary keys
  - Unwanted spaces in text columns
  - Unexpected values in decoded columns
  - Invalid date ranges and date order
  - Sales that don't equal quantity x price
  - Keys that don't join across CRM and ERP

Usage:
  Run after EXEC silver.load_silver;
  Unless a comment says otherwise, every query should return NO rows.
====================================================================================
*/

-- ====================================================================
-- silver.crm_cust_info
-- ====================================================================

-- Null or duplicate customer IDs. Expect: no rows
SELECT cst_id, COUNT(*) AS cnt
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Unwanted spaces. Expect: no rows
SELECT cst_key, cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key)
   OR cst_firstname != TRIM(cst_firstname)
   OR cst_lastname != TRIM(cst_lastname);

-- Standardised values. Expect: only Single, Married, n/a and Male, Female, n/a
SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info;
SELECT DISTINCT cst_gndr FROM silver.crm_cust_info;

-- ====================================================================
-- silver.crm_prd_info
-- ====================================================================

-- Null or duplicate product IDs. Expect: no rows
SELECT prd_id, COUNT(*) AS cnt
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Unwanted spaces in product name. Expect: no rows
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Null or negative cost. Expect: no rows
SELECT prd_id, prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- Standardised product lines. Expect: only Mountain, Road, Other Sales, Touring, n/a
SELECT DISTINCT prd_line FROM silver.crm_prd_info;

-- End date before start date. Expect: no rows
SELECT prd_id, prd_key, prd_start_dt, prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- Start dates read as 1 July, not 7 January (dd-mm-yyyy check). Expect: month 7 only
SELECT DISTINCT MONTH(prd_start_dt) AS start_month
FROM silver.crm_prd_info;

-- ====================================================================
-- silver.crm_sales_details
-- ====================================================================

-- Order date after ship or due date. Expect: no rows
SELECT sls_ord_num, sls_order_dt, sls_ship_dt, sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Dates outside a sensible range. Expect: no rows
SELECT sls_ord_num, sls_order_dt, sls_ship_dt, sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt NOT BETWEEN '1900-01-01' AND '2050-01-01'
   OR sls_ship_dt  NOT BETWEEN '1900-01-01' AND '2050-01-01'
   OR sls_due_dt   NOT BETWEEN '1900-01-01' AND '2050-01-01';

-- Invalid order dates set to NULL. Expect: a small count (19 in the source data)
SELECT COUNT(*) AS null_order_dates
FROM silver.crm_sales_details
WHERE sls_order_dt IS NULL;

-- Sales = quantity x price, and no null, zero or negative values. Expect: no rows
SELECT sls_ord_num, sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;

-- ====================================================================
-- silver.erp_cust_az12
-- ====================================================================

-- Birthdates in the future or before 1924. Expect: no future dates; about 15 very old dates are flagged for review
SELECT cid, bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE() OR bdate < '1924-01-01';

-- Standardised gender. Expect: only Male, Female, n/a
SELECT DISTINCT gen FROM silver.erp_cust_az12;

-- IDs still carrying the NAS prefix. Expect: no rows
SELECT cid FROM silver.erp_cust_az12 WHERE cid LIKE 'NAS%';

-- ====================================================================
-- silver.erp_loc_a101
-- ====================================================================

-- Standardised countries. Expect: full names and n/a only, no US, USA or DE
SELECT DISTINCT cntry FROM silver.erp_loc_a101 ORDER BY cntry;

-- IDs still containing a hyphen. Expect: no rows
SELECT cid FROM silver.erp_loc_a101 WHERE cid LIKE '%-%';

-- ====================================================================
-- silver.erp_px_cat_g1v2
-- ====================================================================

-- Unwanted spaces. Expect: no rows
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Standardised values. Expect: a short clean list; maintenance only Yes or No
SELECT DISTINCT cat, subcat FROM silver.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2;

-- ====================================================================
-- Hidden characters (carriage return from Windows line endings)
-- The last column of each CSV is where CHAR(13) would land. Expect: all 0
-- ====================================================================
SELECT 'erp_cust_az12.gen' AS col, COUNT(*) AS bad_rows
FROM silver.erp_cust_az12
WHERE gen LIKE '%' + CHAR(13) + '%' OR gen != TRIM(gen)
UNION ALL
SELECT 'erp_loc_a101.cntry', COUNT(*)
FROM silver.erp_loc_a101
WHERE cntry LIKE '%' + CHAR(13) + '%' OR cntry != TRIM(cntry)
UNION ALL
SELECT 'erp_px_cat_g1v2.maintenance', COUNT(*)
FROM silver.erp_px_cat_g1v2
WHERE maintenance LIKE '%' + CHAR(13) + '%' OR maintenance != TRIM(maintenance);

-- ====================================================================
-- Cross-system key checks (do the Gold joins work?)
-- ====================================================================

-- CRM customers with no ERP demographics. Expect: no rows
SELECT c.cst_key
FROM silver.crm_cust_info c
LEFT JOIN silver.erp_cust_az12 e ON c.cst_key = e.cid
WHERE e.cid IS NULL;

-- CRM customers with no ERP location. Expect: no rows
SELECT c.cst_key
FROM silver.crm_cust_info c
LEFT JOIN silver.erp_loc_a101 l ON c.cst_key = l.cid
WHERE l.cid IS NULL;

-- Product categories with no match in ERP. Expect: 1 row, CO_PE (not in the ERP category file)
SELECT DISTINCT p.cat_id
FROM silver.crm_prd_info p
LEFT JOIN silver.erp_px_cat_g1v2 x ON p.cat_id = x.id
WHERE x.id IS NULL;

-- Sales pointing to unknown products. Expect: no rows
SELECT s.sls_prd_key
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_prd_info p ON s.sls_prd_key = p.prd_key
WHERE p.prd_key IS NULL;

-- Sales pointing to unknown customers. Expect: no rows
SELECT s.sls_cust_id
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_cust_info c ON s.sls_cust_id = c.cst_id
WHERE c.cst_id IS NULL;
