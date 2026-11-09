-- Silver layer: cleaning and standardisation queries for the 6 Bronze tables
-- 1. crm_cust_info
SELECT
    cst_id,
    TRIM(cst_key) AS cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) IN ('S', 'SINGLE') THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) IN ('M', 'MARRIED') THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    CAST(cst_create_date AS DATE) AS cst_create_date
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1;

-- 2. crm_prd_info
SELECT 
    prd_id,
    REPLACE(SUBSTRING(TRIM(prd_key), 1, 5), '-', '_') AS cat_id,
    SUBSTRING(TRIM(prd_key), 7, LEN(TRIM(prd_key))) AS prd_key,
    TRIM(prd_nm) AS prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost,
    CASE UPPER(TRIM(prd_line)) 
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    CONVERT(DATE, prd_start_dt, 105) AS prd_start_dt,
    CAST(DATEADD(day, -1, LEAD(CONVERT(DATE, prd_start_dt, 105)) OVER (PARTITION BY prd_key ORDER BY CONVERT(DATE, prd_start_dt, 105))) AS DATE) AS prd_end_dt
FROM bronze.crm_prd_info;

-- 3. crm_sales_details
SELECT 
    TRIM(sls_ord_num) AS sls_ord_num,
    TRIM(sls_prd_key) AS sls_prd_key,
    sls_cust_id,
    CASE WHEN sls_order_dt IS NULL OR sls_order_dt <= 0 OR LEN(CAST(sls_order_dt AS NVARCHAR(20))) != 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 THEN NULL ELSE CAST(CAST(sls_order_dt AS NVARCHAR(8)) AS DATE) END AS sls_order_dt,
    CASE WHEN sls_ship_dt IS NULL OR sls_ship_dt <= 0 OR LEN(CAST(sls_ship_dt AS NVARCHAR(20))) != 8 OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101 THEN NULL ELSE CAST(CAST(sls_ship_dt AS NVARCHAR(8)) AS DATE) END AS sls_ship_dt,
    CASE WHEN sls_due_dt IS NULL OR sls_due_dt <= 0 OR LEN(CAST(sls_due_dt AS NVARCHAR(20))) != 8 OR sls_due_dt > 20500101 OR sls_due_dt < 19000101 THEN NULL ELSE CAST(CAST(sls_due_dt AS NVARCHAR(8)) AS DATE) END AS sls_due_dt,
    CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price) ELSE sls_sales END AS sls_sales,
    sls_quantity,
    CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN ABS(sls_sales / NULLIF(sls_quantity, 0)) ELSE sls_price END AS sls_price
FROM bronze.crm_sales_details;

-- 4. erp_cust_az12
SELECT
    CASE WHEN TRIM(cid) LIKE 'NAS%' THEN SUBSTRING(TRIM(cid), 4, LEN(TRIM(cid))) ELSE TRIM(cid) END AS cid,
    CASE WHEN CAST(bdate AS DATE) > GETDATE() THEN NULL ELSE bdate END AS bdate,
    CASE 
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('F', 'FEMALE') THEN 'Female' 
        WHEN UPPER(TRIM(REPLACE(gen, CHAR(13), ''))) IN ('M', 'MALE') THEN 'Male' 
        ELSE 'n/a' 
    END AS gen
FROM bronze.erp_cust_az12;

-- 5. erp_loc_a101
SELECT 
    REPLACE(TRIM(cid), '-', '') AS cid,
    CASE 
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany' 
        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States' 
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a' 
        ELSE TRIM(cntry) 
    END AS cntry
FROM bronze.erp_loc_a101;

-- 6. erp_px_cat_g1v2
SELECT 
    TRIM(id) AS id,
    TRIM(cat) AS cat,
    TRIM(subcat) AS subcat,
    TRIM(maintenance) AS maintenance
FROM bronze.erp_px_cat_g1v2;
