-- Step 4: preview the Bronze-to-Silver cleaning rules.
-- These SELECT statements do not change data. Review the results before step 5.

USE DataWarehouse;
GO

-- 1. Customers: ignore blank IDs and keep the latest record per customer.
;WITH customer_source AS (
    SELECT
        TRY_CONVERT(INT, NULLIF(TRIM(cst_id), '')) AS cst_id,
        TRIM(REPLACE(cst_key, CHAR(13), '')) AS cst_key,
        TRIM(REPLACE(cst_firstname, CHAR(13), '')) AS cst_firstname,
        TRIM(REPLACE(cst_lastname, CHAR(13), '')) AS cst_lastname,
        TRIM(REPLACE(cst_marital_status, CHAR(13), '')) AS cst_marital_status,
        TRIM(REPLACE(cst_gndr, CHAR(13), '')) AS cst_gndr,
        TRY_CONVERT(DATE, NULLIF(TRIM(REPLACE(cst_create_date, CHAR(13), '')), ''), 23) AS cst_create_date
    FROM bronze.crm_cust_info
),
customer_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC, cst_key) AS flag_last
    FROM customer_source
    WHERE cst_id IS NOT NULL
)
SELECT
    cst_id, cst_key, cst_firstname, cst_lastname,
    CASE
        WHEN UPPER(cst_marital_status) IN ('S', 'SINGLE') THEN 'Single'
        WHEN UPPER(cst_marital_status) IN ('M', 'MARRIED') THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE
        WHEN UPPER(cst_gndr) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(cst_gndr) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
FROM customer_ranked
WHERE flag_last = 1;

-- 2. Products: split the category from the product key and derive end dates.
;WITH product_source AS (
    SELECT
        TRY_CONVERT(INT, NULLIF(TRIM(prd_id), '')) AS prd_id,
        TRIM(REPLACE(prd_key, CHAR(13), '')) AS source_prd_key,
        TRIM(REPLACE(prd_nm, CHAR(13), '')) AS prd_nm,
        TRY_CONVERT(INT, NULLIF(TRIM(REPLACE(prd_cost, CHAR(13), '')), '')) AS prd_cost,
        TRIM(REPLACE(prd_line, CHAR(13), '')) AS prd_line,
        TRY_CONVERT(DATE, NULLIF(TRIM(REPLACE(prd_start_dt, CHAR(13), '')), ''), 105) AS prd_start_dt
    FROM bronze.crm_prd_info
),
product_dates AS (
    SELECT *,
        LEAD(prd_start_dt) OVER (PARTITION BY source_prd_key ORDER BY prd_start_dt) AS next_start_dt
    FROM product_source
)
SELECT
    prd_id,
    REPLACE(SUBSTRING(source_prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(source_prd_key, 7, LEN(source_prd_key)) AS prd_key,
    prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost,
    CASE UPPER(prd_line)
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    prd_start_dt,
    DATEADD(DAY, -1, next_start_dt) AS prd_end_dt
FROM product_dates;

-- 3. Sales: parse values, repair price first, then reconcile sales.
;WITH sales_source AS (
    SELECT
        TRIM(REPLACE(sls_ord_num, CHAR(13), '')) AS sls_ord_num,
        TRIM(REPLACE(sls_prd_key, CHAR(13), '')) AS sls_prd_key,
        TRY_CONVERT(INT, NULLIF(TRIM(sls_cust_id), '')) AS sls_cust_id,
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_order_dt), ''), 112) AS sls_order_dt,
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_ship_dt), ''), 112) AS sls_ship_dt,
        TRY_CONVERT(DATE, NULLIF(TRIM(sls_due_dt), ''), 112) AS sls_due_dt,
        TRY_CONVERT(INT, NULLIF(TRIM(sls_sales), '')) AS sales_value,
        TRY_CONVERT(INT, NULLIF(TRIM(sls_quantity), '')) AS quantity_value,
        TRY_CONVERT(INT, NULLIF(TRIM(REPLACE(sls_price, CHAR(13), '')), '')) AS price_value
    FROM bronze.crm_sales_details
),
sales_with_price AS (
    SELECT *,
        CASE
            WHEN price_value IS NULL OR price_value <= 0
                THEN ABS(sales_value) / NULLIF(quantity_value, 0)
            ELSE ABS(price_value)
        END AS clean_price
    FROM sales_source
)
SELECT
    sls_ord_num, sls_prd_key, sls_cust_id,
    CASE WHEN sls_order_dt BETWEEN '19000101' AND '20500101' THEN sls_order_dt END AS sls_order_dt,
    CASE WHEN sls_ship_dt BETWEEN '19000101' AND '20500101' THEN sls_ship_dt END AS sls_ship_dt,
    CASE WHEN sls_due_dt BETWEEN '19000101' AND '20500101' THEN sls_due_dt END AS sls_due_dt,
    CASE
        WHEN sales_value IS NULL OR sales_value <= 0
          OR sales_value <> quantity_value * clean_price
            THEN quantity_value * clean_price
        ELSE sales_value
    END AS sls_sales,
    quantity_value AS sls_quantity,
    clean_price AS sls_price
FROM sales_with_price;

-- 4. ERP demographics: remove NAS prefix, reject future dates and standardise gender.
SELECT
    CASE WHEN TRIM(cid) LIKE 'NAS%' THEN SUBSTRING(TRIM(cid), 4, LEN(TRIM(cid))) ELSE TRIM(cid) END AS cid,
    CASE
        WHEN TRY_CONVERT(DATE, NULLIF(TRIM(bdate), ''), 23) > CAST(GETDATE() AS DATE) THEN NULL
        ELSE TRY_CONVERT(DATE, NULLIF(TRIM(bdate), ''), 23)
    END AS bdate,
    CASE
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS gen
FROM bronze.erp_cust_az12;

-- 5. ERP locations: standardise customer IDs and country names.
SELECT
    REPLACE(TRIM(cid), '-', '') AS cid,
    CASE
        WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) = 'DE' THEN 'Germany'
        WHEN UPPER(TRIM(REPLACE(cntry, CHAR(13), ''))) IN ('US', 'USA') THEN 'United States'
        WHEN NULLIF(TRIM(REPLACE(cntry, CHAR(13), '')), '') IS NULL THEN 'n/a'
        ELSE TRIM(REPLACE(cntry, CHAR(13), ''))
    END AS cntry
FROM bronze.erp_loc_a101;

-- 6. ERP product categories: trim values and remove the line-ending character.
SELECT
    TRIM(id) AS id,
    TRIM(cat) AS cat,
    TRIM(subcat) AS subcat,
    TRIM(REPLACE(maintenance, CHAR(13), '')) AS maintenance
FROM bronze.erp_px_cat_g1v2;
