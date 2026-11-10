# SQL Data Warehouse Project

**Author:** Ashwani Tripathi

A data warehouse built in **Microsoft SQL Server** using the **Medallion Architecture** (Bronze, Silver, Gold). It combines sales data from two separate source systems, a CRM and an ERP, into one clean model for reporting.

![Data flow](docs/data_flow.png)

## Status

| Layer | Status | What it does |
|---|---|---|
| Bronze | Done | Loads the 6 raw CSV files exactly as received |
| Silver | Done | Cleans, standardises and aligns keys across CRM and ERP |
| Gold | Built | Star schema views: `dim_customers`, `dim_products`, `fact_sales` |

## Source data

| System | File | Contents | Rows |
|---|---|---|---:|
| CRM | `cust_info.csv` | Customers: name, marital status, gender, created date | 18,493 |
| CRM | `prd_info.csv` | Products: key, name, cost, product line, start date | 397 |
| CRM | `sales_details.csv` | Sales orders: dates, quantity, price, sales amount | 60,398 |
| ERP | `CUST_AZ12.csv` | Customer birthdate and gender | 18,483 |
| ERP | `LOC_A101.csv` | Customer country | 18,484 |
| ERP | `PX_CAT_G1V2.csv` | Product category, subcategory, maintenance flag | 36 |

The files are in [`datasets/`](datasets/). The sample CRM/ERP data comes from the public "SQL Data Warehouse Project" course by Data With Baraa. The cleaning rules, fixes and documentation here are my own.

## Data profiling: issues found

- Leading and trailing spaces in names and keys
- Coded values: `M`/`S` for marital status, `M`/`F` for gender, `R`/`M`/`S`/`T` for product lines
- ERP gender written two ways (`Male`/`Female` and `M`/`F`)
- Countries written several ways (`US`, `USA`, `United States`, `DE`, `Germany`) plus blanks
- Duplicate and missing customer IDs
- Product start dates in `dd-mm-yyyy` text format
- Invalid sales dates (`0`, `5489`, `32154`) stored as integers
- Missing or negative prices and sales amounts that don't equal quantity × price
- Impossible birthdates (for example `9999-11-20`)
- Different customer ID formats between CRM and ERP
- ERP gender came through as all `n/a`/NULL on one load; the Silver gender rule now strips any hidden carriage return (`CHAR(13)`) before mapping, and `tests/quality_checks_silver.sql` checks every last CSV column for it

## Bronze layer

- **`scripts/bronze/ddl_bronze.sql`** creates 6 tables with every column as `NVARCHAR(50)`, so no raw row fails to load. Type conversion happens in Silver.
- **`scripts/bronze/proc_load_bronze.sql`** creates `bronze.load_bronze`, which truncates each table and runs `BULK INSERT` from the CSV files. It prints the load time per table and for the whole batch, and uses `TRY...CATCH` with `THROW` so failures are visible.

## Silver layer

- **`scripts/silver/ddl_silver.sql`** creates 6 typed tables (`INT`, `DATE`), with a new `cat_id` column on products.
- **`scripts/silver/proc_load_silver.sql`** creates `silver.load_silver` (truncate, then `INSERT INTO ... SELECT`), with the same timing and error handling.
- **`scripts/silver/silver_transformations.sql`** has the cleaning queries on their own, for testing.

**Transformations applied**

| Table | Rules |
|---|---|
| crm_cust_info | `TRIM` text; decode marital status and gender; keep the latest record per customer with `ROW_NUMBER()`; drop null IDs |
| crm_prd_info | Split `prd_key` into `cat_id` and `prd_key`; cost `NULL` to 0; decode product line; `CONVERT(DATE, ..., 105)` for dd-mm-yyyy dates; derive `prd_end_dt` with `LEAD()` minus one day |
| crm_sales_details | Invalid integer dates to `NULL`; recalculate sales when missing, negative or not equal to quantity × price; derive missing price |
| erp_cust_az12 | Strip `NAS` prefix from IDs; cast birthdate to `DATE`, future dates to `NULL`; remove `CHAR(13)` and standardise gender |
| erp_loc_a101 | Remove hyphens from IDs; map `US`/`USA` to United States and `DE` to Germany; blanks to `n/a` |
| erp_px_cat_g1v2 | `TRIM` all columns |

Join keys and the full flow are in [`docs/data_flow.md`](docs/data_flow.md). The layer design is in [`docs/architecture.md`](docs/architecture.md).

## Gold layer: star schema

`fact_sales` (one row per order line) links to `dim_customers` and `dim_products` by integer surrogate keys made with `ROW_NUMBER()`. `dim_customers` joins the CRM customer to both ERP tables; gender comes from the CRM, and from the ERP when the CRM has `n/a`. `dim_products` keeps only current products. Full model: [`docs/data_model.md`](docs/data_model.md).

## How to run

1. Run `scripts/init_database.sql`. **Warning:** it drops and recreates the `DataWarehouse` database.
2. Run `scripts/bronze/ddl_bronze.sql`, then `scripts/bronze/proc_load_bronze.sql`.
3. Change the `D:\...` file paths in `proc_load_bronze.sql` to where the `datasets/` folder is on your machine.
4. Run `scripts/silver/ddl_silver.sql`, then `scripts/silver/proc_load_silver.sql`.
5. Load the data:

```sql
EXEC bronze.load_bronze;
EXEC silver.load_silver;
```

6. Run `tests/quality_checks_silver.sql`. Each query says what result to expect; most should return no rows.
7. Run `scripts/gold/ddl_gold.sql` to create the Gold views.
8. Run `tests/quality_checks_gold.sql`.

## Repository structure

```
datasets/
  source_crm/        cust_info.csv, prd_info.csv, sales_details.csv
  source_erp/        CUST_AZ12.csv, LOC_A101.csv, PX_CAT_G1V2.csv
docs/
  data_flow.png      Pipeline diagram
  data_flow.md       Mermaid diagram and join keys
  architecture.md    Medallion layer design
  data_model.md      Gold star schema
scripts/
  init_database.sql
  bronze/            ddl_bronze.sql, proc_load_bronze.sql
  silver/            ddl_silver.sql, proc_load_silver.sql, silver_transformations.sql
  gold/              ddl_gold.sql
tests/
  quality_checks_silver.sql   Checks to run after the Silver load
  quality_checks_gold.sql     Checks to run after creating the Gold views
```

## Next steps

- Power BI report on the Gold layer

## License

MIT, see [LICENSE](LICENSE).
