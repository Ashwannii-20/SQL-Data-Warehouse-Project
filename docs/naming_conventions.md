# Project Naming Conventions

This project uses consistent database, schema, object, column, and file naming so that the warehouse is easy to navigate and maintain.

## Database and schema names

| Item | Convention | Example |
|---|---|---|
| Database | PascalCase | `DataWarehouse` |
| Layer schemas | Lowercase layer names | `bronze`, `silver`, `gold` |

## Database objects

| Object | Convention | Examples |
|---|---|---|
| Bronze and Silver source tables | Lowercase source-system prefix + source entity name | `crm_cust_info`, `erp_cust_az12` |
| Gold dimensions | `dim_` prefix + business entity | `dim_customers`, `dim_products` |
| Gold facts | `fact_` prefix + business process | `fact_sales` |
| Layer load procedures | Schema-qualified `load_<layer>` name | `bronze.load_bronze`, `silver.load_silver` |

## Column names

- Bronze and Silver retain recognizable source column names where practical (for example, `cst_id`, `prd_key`, `sls_ord_num`).
- Gold uses readable business-facing snake_case aliases (for example, `customer_key`, `product_number`, `sales_amount`).
- Dimension surrogate keys use the `_key` suffix.
- Source/business identifiers use descriptive names such as `customer_id`, `customer_number`, and `product_number`.
- Dates use descriptive event or meaning names, such as `order_date`, `shipping_date`, `due_date`, and `birthdate`.

## SQL script and test file names

- Number implementation scripts in execution order: `NN_<action>_<description>.sql`.
- Keep layer quality checks in separate files: `quality_checks_silver.sql` and `quality_checks_gold.sql`.
- Use descriptive, lowercase file and folder names with underscores.

## Git and documentation conventions

- Keep reusable project documentation in `docs/`.
- Keep executable SQL in `scripts/` and validation queries in `tests/`.
- Use branch names that describe the purpose of the work.
