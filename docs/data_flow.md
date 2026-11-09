# Data Flow

![Data flow](data_flow.png)

The same flow as a Mermaid diagram (GitHub draws it automatically):

```mermaid
flowchart LR
    subgraph Sources
        CRM[CRM CSVs]
        ERP[ERP CSVs]
    end
    subgraph Bronze["Bronze (raw, all NVARCHAR)"]
        b1[crm_cust_info]
        b2[crm_prd_info]
        b3[crm_sales_details]
        b4[erp_cust_az12]
        b5[erp_loc_a101]
        b6[erp_px_cat_g1v2]
    end
    subgraph Silver["Silver (cleaned, typed)"]
        s1[crm_cust_info]
        s2[crm_prd_info]
        s3[crm_sales_details]
        s4[erp_cust_az12]
        s5[erp_loc_a101]
        s6[erp_px_cat_g1v2]
    end
    subgraph Gold["Gold (star schema, in progress)"]
        g1[dim_customers]
        g2[dim_products]
        g3[fact_sales]
    end
    CRM --> b1 & b2 & b3
    ERP --> b4 & b5 & b6
    b1 --> s1
    b2 --> s2
    b3 --> s3
    b4 --> s4
    b5 --> s5
    b6 --> s6
    s1 & s4 & s5 --> g1
    s2 & s6 --> g2
    s3 --> g3
    g1 & g2 -.surrogate keys.-> g3
```

## Join keys aligned in Silver

| Link | CRM value | ERP value | Silver rule |
|---|---|---|---|
| Customer to ERP demographics | `cst_key` = AW00011000 | `CID` = NASAW00011000 | Strip the `NAS` prefix |
| Customer to ERP location | `cst_key` = AW00011000 | `CID` = AW-00011000 | Remove the hyphen |
| Product to category | `prd_key` = CO-RF-FR-R92B-58 | `ID` = CO_RF | First 5 characters, `-` to `_` |
| Product to sales | `prd_key` (from character 7) = FR-R92B-58 | `sls_prd_key` | Substring from position 7 |
| Sales to customer | `cst_id` | `sls_cust_id` | Direct match |
