# Interview Guide

This guide summarises the decisions in this SQL Server warehouse so I can explain the project clearly in a technical interview.

## 1. What the project does

The project combines six sample CSV files from two source systems:

- CRM: customers, products and sales transactions
- ERP: customer demographics, customer locations and product categories

The data moves through three layers:

1. **Bronze** stores the incoming source values in NVARCHAR(50) columns.
2. **Silver** converts values to useful SQL Server data types, cleans inconsistent values and aligns keys between systems.
3. **Gold** exposes a star schema through customer and product dimensions and a sales fact view.

## 2. Why Bronze uses NVARCHAR

The Bronze tables are a raw landing layer. Loading source values as text reduces the risk that one malformed date or number prevents the whole file from landing. Type conversion and validation happen in Silver, where the rules are explicit.

This is a deliberate design choice for this project. It does not mean every production Bronze layer must use the same data types.

## 3. Important transformations

- NULLIF(TRIM(value), '') treats blank text as missing before conversion.
- TRY_CONVERT safely converts source text. Invalid values become NULL and can be checked instead of stopping the load.
- ROW_NUMBER() identifies duplicate CRM customer IDs so the latest customer record can be retained.
- LEAD() looks at the next product start date. Subtracting one day creates the end date for the previous product version.
- CASE expressions standardise marital status, gender, product line and country values.
- CRM and ERP customer identifiers are normalised so the systems can be joined.
- Sales price is repaired before sales amount is reconciled to quantity multiplied by price. This order matters when a source price is blank but the sales amount is valid.
- CHAR(13) is removed explicitly from text fields that can contain the carriage-return part of Windows line endings. SQL Server TRIM() alone does not remove that character.

## 4. Why the Gold layer uses views

The Gold objects are views, so they present the integrated model without copying another set of rows. The fact view keeps the sales transaction grain and looks up the customer and product surrogate keys from the dimensions.

The customer dimension uses CRM customer attributes and enriches them with ERP birthdate and country. CRM gender is preferred, with ERP gender used as a fallback when CRM gender is n/a.

The product dimension includes only the current product version (prd_end_dt IS NULL) and adds category attributes from ERP.

## 5. Data-quality checks

The Silver checks cover:

- Null and duplicate customer/product identifiers
- Standardised values and trimmed text
- Date validity and chronological order
- Sales arithmetic (sales = quantity × price)
- Carriage returns in final CSV columns
- CRM-to-ERP customer matches
- Sales-to-customer and sales-to-product matches

The Gold checks cover orphan fact rows, dimension key uniqueness, row-count consistency, current product uniqueness and expected unmatched categories.

The sample data contains 19 invalid order dates, which are retained as NULL rather than replaced with invented dates. Seven current product rows have the category ID CO_PE, which is not present in the supplied ERP category file; this is documented as a source-data mismatch.

## 6. Loading and error handling

The Bronze and Silver load scripts use transactions with SET XACT_ABORT ON and TRY...CATCH. If a load fails, the transaction is rolled back and THROW returns the original error.

The CSV paths in the BULK INSERT statements must be changed to the local dataset location. The SQL Server service account must be able to read those files; access from the SSMS desktop alone is not sufficient.

## 7. Design limitation and next production step

The Gold surrogate keys are generated with ROW_NUMBER() in views. They are stable while the underlying rows and sort order stay unchanged, but adding or removing rows can shift key values. This is acceptable for a learning project. A production warehouse would normally persist dimension tables and manage surrogate keys during the load.

A logical next step is to load the Gold model into persisted dimension and fact tables, then build a Power BI report on top.

## 8. A concise project explanation

"I built a SQL Server data warehouse using a Bronze, Silver and Gold architecture. I landed CRM and ERP CSV files as raw text in Bronze, used T-SQL transformations in Silver to validate and standardise the data and align the customer and product keys, then exposed a star schema in Gold. I added quality checks for duplicates, invalid dates, sales arithmetic and cross-system joins. I also documented the trade-offs, including the use of view-generated surrogate keys in this learning project."
