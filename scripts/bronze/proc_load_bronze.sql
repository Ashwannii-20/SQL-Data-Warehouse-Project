/* 
====================================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze
====================================================================================
Script Purpose:
This stored procedure loads data into the 'bronze' schema from external CSV files.
It performs the following actions: 
  - Truncates the bronze tables before loading data.
  - Use the 'BULK INSERT' command to load data from csv files to bronze tables.


Parameters:
  None.
This stored procedure does not accept any parameters on return any values.

Usages Exapmle:
  EXEC  bronze.load_bronze
=====================================================================================

*/

CREATE OR ALTER PROCEDURE bronze.load_bronze 
AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start DATETIME;
    
    SET @start_time = GETDATE();
    PRINT '========================================';
    PRINT 'Loading Bronze Layer Started';
    PRINT '========================================';

    BEGIN TRY
        -- ----------------------------------------------------
        -- CRM TABLES
        -- ----------------------------------------------------

        -- 1. Load CRM Customer Info
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.crm_cust_info';
        
        TRUNCATE TABLE bronze.crm_cust_info;
        
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_crm\cust_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- 2. Load CRM Product Info
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.crm_prd_info';
        
        TRUNCATE TABLE bronze.crm_prd_info;
        
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_crm\prd_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- 3. Load CRM Sales Details
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.crm_sales_details';
        
        TRUNCATE TABLE bronze.crm_sales_details;
        
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_crm\sales_details.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- ----------------------------------------------------
        -- ERP TABLES
        -- ----------------------------------------------------

        -- 4. Load ERP Location Info
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.erp_loc_a101';
        
        TRUNCATE TABLE bronze.erp_loc_a101;
        
        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_erp\LOC_A101.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- 5. Load ERP Customer Info
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.erp_cust_az12';
        
        TRUNCATE TABLE bronze.erp_cust_az12;
        
        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_erp\CUST_AZ12.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- 6. Load ERP Product Category Info
        SET @batch_start = GETDATE();
        PRINT '----------------------------------------';
        PRINT '>> Truncating & Loading: bronze.erp_px_cat_g1v2';
        
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\Data warehouse\sql-data-warehouse-project\01_datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        
        PRINT '>> Completed in ' + CAST(DATEDIFF(millisecond, @batch_start, GETDATE()) AS NVARCHAR) + ' ms';


        -- Summary Footer
        SET @end_time = GETDATE();
        PRINT '========================================';
        PRINT 'Loading Bronze Layer Completed Successfully';
        PRINT 'Load Duration ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '========================================';

    END TRY
    BEGIN CATCH
        PRINT '========================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD!';
        PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR(50));
        PRINT 'Error Message : ' + ERROR_MESSAGE();
        PRINT '========================================';
        THROW;
    END CATCH
END;
GO
