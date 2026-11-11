# SQL Data Warehouse Project

**Author:** Ashwani Tripathi  
**Platform:** Microsoft SQL Server | **Language:** T-SQL  
**Architecture:** Medallion (Bronze, Silver, Gold)

## Project overview

This project demonstrates the design and implementation of a SQL-based data warehouse using data from two operational source systems: Customer Relationship Management (CRM) and Enterprise Resource Planning (ERP).

The warehouse consolidates raw source data, applies cleansing and standardisation, integrates related entities across systems, and publishes structured analytical data through a Gold-layer star schema.

The objective is to build a reliable, documented and quality-checked data foundation that downstream teams can use for analysis, reporting and business intelligence.

![Data architecture](docs/data_architecture.png)

## Business purpose and intended users

In organisations, operational data is often spread across multiple systems and may not be consistent or ready for analysis. This project demonstrates how a data engineering workflow can bring those sources together and make the resulting data more dependable for analytical use.

The warehouse is designed to provide a central analytical data source for:

- **Data Analysts** — query integrated, trusted data and investigate business performance.
- **BI Analysts and BI Developers** — build reports, dashboards and semantic models using curated warehouse views.
- **Business and Finance Analysts** — analyse sales, customers, products and business trends.
- **Reporting and Analytics Teams** — reuse consistent datasets and business definitions instead of repeatedly preparing raw files.

This repository focuses on the **SQL data engineering and data warehouse layer**. Tools such as Power BI, Tableau or Excel may consume the Gold-layer views, but report and dashboard development is outside this project's scope.

## Architecture

The warehouse follows the Medallion Architecture:

| Layer | Purpose | Implementation |
|---|---|---|
| **Bronze** | Preserve incoming source data in raw form | Six raw tables; source columns initially loaded as NVARCHAR |
| **Silver** | Clean, standardise, validate and integrate data | Typed tables, cleansing rules, key standardisation and CRM/ERP alignment |
| **Gold** | Publish business-ready analytical models | Customer and product dimensions plus a sales fact view |

![Data flow](docs/data_flow.png)

### Gold layer: star schema

The Gold layer exposes three analytical views:

- **gold.dim_customers** — customer attributes integrated from CRM and ERP.
- **gold.dim_products** — current product attributes enriched with ERP category information.
- **gold.fact_sales** — sales transaction lines connected to customer and product dimensions.

The fact view links to the dimensions using surrogate keys. This star-schema structure gives analysts and BI tools a consistent, understandable model to query.

![Star schema](docs/data_model.png)

See the [data model](docs/data_model.md) and [Gold data catalogue](docs/data_catalog.md) for details.

## Source data

The project uses six CSV files representing CRM and ERP source systems.

| System | File | Contents | Rows |
|---|---|---|---:|
| CRM | cust_info.csv | Customer name, marital status, gender and creation date | 18,494 |
| CRM | prd_info.csv | Product key, name, cost, product line and start date | 397 |
| CRM | sales_details.csv | Sales orders, dates, quantity, price and sales amount | 60,398 |
| ERP | CUST_AZ12.csv | Customer birthdate and gender | 18,483 |
| ERP | LOC_A101.csv | Customer country/location | 18,484 |
| ERP | PX_CAT_G1V2.csv | Product category, subcategory and maintenance flag | 37 |

The files are stored in [datasets/](datasets/). The sample data is based on the public SQL Data Warehouse Project learning materials by Data With Baraa. The implementation, transformation decisions, validation and documentation were developed for this repository, with AI assistance used for some code drafting and review.

## Data profiling and transformation

Source profiling identified issues commonly encountered when integrating operational data:

- Leading and trailing spaces in text fields and keys.
- Inconsistent coded values for marital status, gender and product lines.
- Different representations of gender and country across source systems.
- Missing, blank or duplicate customer identifiers.
- Different customer ID formats between CRM and ERP.
- Product start dates stored as text in dd-mm-yyyy format.
- Invalid sales date values stored as integers.
- Missing or negative prices and sales amounts that did not reconcile to quantity multiplied by price.
- Impossible or future birthdates.
- Hidden carriage-return characters in source data.

Transformations include trimming and standardising text, mapping coded values, normalising join keys, safe date and numeric conversion, handling invalid values, deduplicating customer records, deriving product end dates and reconciling sales measures.

Detailed source-to-target rules are documented in [docs/data_catalog.md](docs/data_catalog.md).

## Implementation workflow

| Step | SQL file | Purpose |
|---|---|---|
| 0 | scripts/00_init_database.sql | Creates the DataWarehouse database and Bronze, Silver and Gold schemas |
| 1 | scripts/01_bronze_create_tables.sql | Creates the six Bronze source tables |
| 2 | scripts/02_bronze_bulk_upload.sql | Loads the six CSV files into Bronze using BULK INSERT |
| 3 | scripts/03_silver_create_tables.sql | Creates structured Silver tables with appropriate data types |
| 4 | scripts/04_silver_clean_data.sql | Defines source-to-target cleansing and transformation logic |
| 5 | scripts/05_silver_insert_tables.sql | Loads transformed data into Silver |
| 6 | scripts/06_load_procedures.sql | Creates Bronze and Silver load procedures with error handling |
| 7 | scripts/07_gold_views.sql | Creates the Gold analytical views |

The implementation uses SQL Server and T-SQL features including BULK INSERT, TRIM, CASE, TRY_CONVERT, ROW_NUMBER(), LEAD(), joins, common table expressions, views, stored procedures and TRY...CATCH error handling.

## Data quality and validation

Validation is part of the warehouse workflow; successful loading alone is not treated as proof of data quality.

The SQL test scripts cover:

- Source-to-layer row-count reconciliation.
- Duplicate and missing business keys.
- Surrogate-key uniqueness.
- Referential integrity and orphaned fact records.
- NULL checks on important analytical columns.
- Date sequence and date validity checks.
- Sales amount and quantity/price consistency.
- Negative or invalid measures.
- Standardisation and transformation rules.

Executed Gold validation results:

| Validation item | Result |
|---|---:|
| Gold customers | 18,484 |
| Gold current products | 295 |
| Gold sales fact rows | 60,398 |
| Historical products excluded from current-product dimension | 102 |
| Duplicate sales order/product combinations | 0 |
| Orphaned sales dimension references | 0 |

### Documented source-data exceptions

The validation process also identified exceptions that were retained and documented rather than silently changed:

- **19 sales rows** have a NULL order date. Other key sales attributes are present; the missing source date was not fabricated.
- **7 current products** have no matching ERP category record. The category remains NULL because the source relationship is missing.

Run the checks in [tests/quality_checks_silver.sql](tests/quality_checks_silver.sql) and [tests/quality_checks_gold.sql](tests/quality_checks_gold.sql).

## Documentation

- [Architecture](docs/architecture.md)
- [Data flow and join keys](docs/data_flow.md)
- [Data model](docs/data_model.md)
- [Data catalogue and source-to-target mappings](docs/data_catalog.md)
- [Naming conventions](docs/naming_conventions.md)
- [Interview guide and design trade-offs](docs/interview_guide.md)

## How to run

1. Use Microsoft SQL Server and SQL Server Management Studio (SSMS).
2. Review the dataset paths in the bulk-load and load-procedure scripts and update them to match the location accessible to the SQL Server service.
3. Run the scripts in numerical order, from 00 through 07.
4. Run the Silver and Gold quality-check scripts to validate the loaded data and analytical views.

**Important:** scripts/00_init_database.sql drops and recreates the DataWarehouse database. Run it only when you intend to initialise or rebuild this project database; do not run it against a database containing data you need to keep.

For BULK INSERT to work, the SQL Server service account must be able to access the CSV files at the configured paths.

## Repository structure

- **datasets/** — CRM and ERP source CSV files.
- **docs/** — architecture, data flow, data model, catalogue, naming conventions and interview guide.
- **scripts/** — database initialisation, Bronze and Silver loading, transformations, procedures and Gold views.
- **tests/** — Silver and Gold data quality checks.

## Project management

Project planning, task tracking and implementation progress are maintained in [the project Notion workspace](https://app.notion.com/p/407738eceaed8012828fe535c37759ef). The Notion page must be shared with anyone who has the link using view-only access before external reviewers can open it.

## Project scope

This repository demonstrates a foundational SQL data engineering workflow: ingesting raw data, transforming and integrating it, modelling it for analysis, and validating the results.

It provides the warehouse layer that downstream analysts and BI teams can build upon. Dashboard development, BI semantic modelling and production orchestration are separate capabilities and are not included in this project's scope.

## License

MIT — see LICENSE.
