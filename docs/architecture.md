# Architecture

![diagram](data_architecture.png)

Medallion architecture on SQL Server. GitHub draws the Mermaid diagram automatically.

```mermaid
flowchart LR
    subgraph SRC["Data Sources"]
        direction TB
        crm["📁 CRM Source<br/>3 CSV files"]
        erp["📁 ERP Source<br/>3 CSV files"]
    end

    subgraph BR["Bronze Layer - Raw Data"]
        bronze["Tables<br/>All columns NVARCHAR<br/>No transformations<br/><br/>Load: Truncate + BULK INSERT"]
    end

    subgraph SV["Silver Layer - Cleaned Data"]
        silver["Tables<br/>Typed columns (INT, DATE)<br/>Cleaning, standardising,<br/>derived columns, key alignment<br/><br/>Load: Truncate + INSERT ... SELECT"]
    end

    subgraph GD["Gold Layer - Star Schema"]
        gold["Views (no load)<br/>dim_customers<br/>dim_products<br/>fact_sales"]
    end

    subgraph US["Use"]
        use["BI & Reporting<br/>Ad-hoc SQL"]
    end

    crm -- "bronze.load_bronze" --> bronze
    erp -- "bronze.load_bronze" --> bronze
    bronze -- "silver.load_silver" --> silver
    silver -- "CREATE VIEW" --> gold
    gold --> use

    classDef crmS fill:#e8f1fd,stroke:#2f6fd6,color:#000
    classDef erpS fill:#fdf0e6,stroke:#d9662b,color:#000
    classDef box fill:#ffffff,stroke:#999,color:#000
    classDef goldB fill:#fbefc4,stroke:#c9a227,color:#000
    class crm crmS
    class erp erpS
    class bronze,silver,use box
    class gold goldB
    style SRC fill:#fdf2fd,stroke:#d58ee0
    style BR fill:#ecfcfa,stroke:#4fc9c0
    style SV fill:#eefbef,stroke:#6ccf7f
    style GD fill:#fefbe8,stroke:#e8d26a
    style US fill:#ffffff,stroke:#bbb,stroke-dasharray:5 5
```

## Layers

| Layer | Object | How it is loaded | What happens |
|---|---|---|---|
| Bronze | Tables | `bronze.load_bronze`: truncate, then `BULK INSERT` each CSV | Nothing, data kept as received |
| Silver | Tables | `silver.load_silver`: truncate, then `INSERT ... SELECT` from Bronze | Cleaning, standardising, derived columns, key alignment |
| Gold | Views | Not loaded; views read Silver at query time | Joins CRM and ERP into a star schema |
