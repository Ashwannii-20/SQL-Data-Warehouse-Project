# Gold Data Model (Star Schema)

![diagram](data_model.png)

One fact table and two dimensions. Each dimension has an integer surrogate key (`_key`) made with `ROW_NUMBER()`, plus the source business key (`_number`).

**Grain of `fact_sales`:** one row per order line (`order_number` + `product_key`).

```mermaid
erDiagram
    dim_customers ||--o{ fact_sales : "customer_key"
    dim_products  ||--o{ fact_sales : "product_key"

    dim_customers {
        INT customer_key PK
        INT customer_id
        NVARCHAR customer_number
        NVARCHAR first_name
        NVARCHAR last_name
        NVARCHAR country
        NVARCHAR marital_status
        NVARCHAR gender
        DATE birthdate
        DATE create_date
    }
    dim_products {
        INT product_key PK
        INT product_id
        NVARCHAR product_number
        NVARCHAR product_name
        NVARCHAR category_id
        NVARCHAR category
        NVARCHAR subcategory
        NVARCHAR maintenance
        INT cost
        NVARCHAR product_line
        DATE start_date
    }
    fact_sales {
        NVARCHAR order_number
        INT product_key FK
        INT customer_key FK
        DATE order_date
        DATE shipping_date
        DATE due_date
        INT sales_amount
        INT quantity
        INT price
    }
```

## How the keys are built

| Gold column | Built from | Why |
|---|---|---|
| `customer_key` | `ROW_NUMBER() OVER (ORDER BY cst_id)` | Warehouse-owned key, independent of the CRM |
| `customer_number` | `cst_key` (e.g. AW00011000) | Business key, used to join the ERP tables |
| `product_key` | `ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key)` | Warehouse-owned key |
| `product_number` | `prd_key` (e.g. FR-R92B-58) | Business key, used to join sales |

`dim_products` keeps only current products (`prd_end_dt IS NULL`), so each `prd_key` appears once and sales do not duplicate.
