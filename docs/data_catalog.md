# Gold Layer Data Catalog

## Purpose

The Gold layer presents the cleaned CRM and ERP data as a reporting-oriented star schema. It contains two dimensions and one fact view.

| Gold object | Type | Business purpose | Current row count observed |
|---|---|---|---:|
| `gold.dim_customers` | Dimension view | One row per CRM customer, enriched with ERP attributes | 18,484 |
| `gold.dim_products` | Dimension view | Current product records enriched with ERP category information | 295 |
| `gold.fact_sales` | Fact view | Sales order lines linked to customer and product dimensions | 60,398 |

*Counts are from the validated project dataset and may change if the source data changes.*

## 1. `gold.dim_customers`

**Grain:** One row per CRM customer.

**Source tables:**
- `silver.crm_cust_info` — customer ID, customer business key, name, marital status, CRM gender and creation date.
- `silver.erp_cust_az12` — birthdate and fallback gender.
- `silver.erp_loc_a101` — country.

**Join logic:** The CRM customer is the driving table. ERP demographics and location are left-joined using the standardized customer business key (`cst_key = cid`). The left joins retain CRM customers when an ERP attribute is unavailable.

| Gold column | Data type | Source / derivation | Description |
|---|---|---|---|
| `customer_key` | BIGINT | `ROW_NUMBER() OVER (ORDER BY cst_id)` | Generated dimension key used by the fact view |
| `customer_id` | INT | `crm_cust_info.cst_id` | CRM customer business ID |
| `customer_number` | NVARCHAR(50) | `crm_cust_info.cst_key` | Standardized customer business key |
| `first_name` | NVARCHAR(50) | `crm_cust_info.cst_firstname` | Customer first name |
| `last_name` | NVARCHAR(50) | `crm_cust_info.cst_lastname` | Customer last name |
| `country` | NVARCHAR(50) | `erp_loc_a101.cntry` | Standardized country |
| `marital_status` | NVARCHAR(50) | `crm_cust_info.cst_marital_status` | Standardized marital status |
| `gender` | NVARCHAR(50) | CRM gender; ERP gender fallback when CRM is `n/a`; otherwise `n/a` | Integrated gender |
| `birthdate` | DATE | `erp_cust_az12.bdate` | Validated date of birth |
| `create_date` | DATE | `crm_cust_info.cst_create_date` | CRM customer creation date |

## 2. `gold.dim_products`

**Grain:** One row per current product business key.

**Source tables:**
- `silver.crm_prd_info` — product attributes and effective dates.
- `silver.erp_px_cat_g1v2` — category, subcategory and maintenance flag.

**Join and filter logic:** Product category details are left-joined using `cat_id = id`. The view retains current products only with `prd_end_dt IS NULL`. Historical product versions remain in Silver and are intentionally excluded from this current-state dimension.

| Gold column | Data type | Source / derivation | Description |
|---|---|---|---|
| `product_key` | BIGINT | `ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key)` | Generated dimension key used by the fact view |
| `product_id` | INT | `crm_prd_info.prd_id` | CRM product ID |
| `product_number` | NVARCHAR(50) | `crm_prd_info.prd_key` | Product business key used by sales |
| `product_name` | NVARCHAR(50) | `crm_prd_info.prd_nm` | Product name |
| `category_id` | NVARCHAR(50) | `crm_prd_info.cat_id` | ERP category business key |
| `category` | NVARCHAR(50) | `erp_px_cat_g1v2.cat` | Product category |
| `subcategory` | NVARCHAR(50) | `erp_px_cat_g1v2.subcat` | Product subcategory |
| `maintenance` | NVARCHAR(50) | `erp_px_cat_g1v2.maintenance` | Maintenance indicator |
| `cost` | INT | `crm_prd_info.prd_cost` | Product cost |
| `product_line` | NVARCHAR(50) | `crm_prd_info.prd_line` | Standardized product line |
| `start_date` | DATE | `crm_prd_info.prd_start_dt` | Current product version start date |

## 3. `gold.fact_sales`

**Grain:** One row per order line, identified in this dataset by `order_number + product_key`.

**Source table:** `silver.crm_sales_details`.

**Dimension lookups:**
- Sales product business key (`sls_prd_key`) joins to `dim_products.product_number`.
- Sales customer business ID (`sls_cust_id`) joins to `dim_customers.customer_id`.

Both dimension lookups use LEFT JOINs so the view does not silently discard source sales rows. Referential-integrity checks are used to identify unmatched dimension keys.

| Gold column | Data type | Source / derivation | Description |
|---|---|---|---|
| `order_number` | NVARCHAR(50) | `crm_sales_details.sls_ord_num` | Sales order number |
| `product_key` | BIGINT | `dim_products.product_key` lookup | Product dimension key |
| `customer_key` | BIGINT | `dim_customers.customer_key` lookup | Customer dimension key |
| `order_date` | DATE | `crm_sales_details.sls_order_dt` | Order date |
| `shipping_date` | DATE | `crm_sales_details.sls_ship_dt` | Shipping date |
| `due_date` | DATE | `crm_sales_details.sls_due_dt` | Due date |
| `sales_amount` | INT | `crm_sales_details.sls_sales` | Sales amount measure |
| `quantity` | INT | `crm_sales_details.sls_quantity` | Units sold |
| `price` | INT | `crm_sales_details.sls_price` | Unit price |

## Relationships

| Fact foreign key | Dimension primary key | Relationship |
|---|---|---|
| `fact_sales.customer_key` | `dim_customers.customer_key` | Many sales rows to one customer |
| `fact_sales.product_key` | `dim_products.product_key` | Many sales rows to one product |

The fact view has no separate date dimension in this project.

## Known data-quality observations

These observations apply to the current sample dataset; they are not universal business rules.

- The Gold customer dimension contains 18,484 rows.
- The Silver product table contains 397 rows: 295 current products and 102 historical product versions. Gold includes the 295 current products.
- Seven current Gold products have no ERP category match; their category ID is `CO_PE`. Their category attributes remain NULL because the view uses a LEFT JOIN.
- Nineteen sales records have NULL order dates in Silver and Gold. These are retained as NULL; an order date is not inferred from shipping or due dates.
- The reviewed sales checks found zero unmatched customer/product keys, zero duplicate order/product combinations, zero sales arithmetic mismatches, and zero date-sequence violations.

## Surrogate-key limitation

The dimension keys are generated with `ROW_NUMBER()` inside views. They are repeatable while the underlying rows and ordering remain unchanged, but are not persistent warehouse keys. If the source rows or sort order change, generated keys can shift. This is acceptable for this learning project; a production warehouse would normally persist dimension surrogate keys and maintain business-key mappings during ETL.
