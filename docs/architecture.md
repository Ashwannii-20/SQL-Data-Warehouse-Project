# Architecture

Medallion architecture on SQL Server. GitHub draws the Mermaid diagram automatically.

```mermaid
flowchart LR
    subgraph SRC["Sources"]
        direction TB
        src["📁 CRM<br/>📁 ERP<br/><br/>Object Type: CSV Files"]
    end

    subgraph DWH["Data Warehouse - SQL Server"]
        direction LR
        bronze["<b>Bronze Layer</b><br/>🛢️ Raw Data<br/><br/>Object Type: Tables<br/><br/>Load:<br/>• Batch Processing<br/>• Full Load<br/>• Truncate & Insert<br/><br/>No Transformations<br/><br/>Data Model: None (as-is)"]
        silver["<b>Silver Layer</b><br/>🛢️ Cleaned, Standardized Data<br/><br/>Object Type: Tables<br/><br/>Load:<br/>• Batch Processing<br/>• Full Load<br/>• Truncate & Insert<br/><br/>Transformations:<br/>• Data Cleansing<br/>• Data Standardization<br/>• Data Normalization<br/>• Derived Columns<br/>• Data Enrichment<br/><br/>Data Model: None (as-is)"]
        gold["<b>Gold Layer</b><br/>🛢️ Business-Ready Data<br/><br/>Object Type: Views<br/><br/>No Load<br/><br/>Transformations:<br/>• Data Integration<br/>• Business Logic<br/><br/>Data Model: Star Schema"]
        bronze -- "silver.load_silver<br/>(stored procedure)" --> silver
        silver -- "views<br/>(no load)" --> gold
    end

    subgraph CON["Consume"]
        direction TB
        con["📊 BI & Reporting<br/><br/>🔍 Ad-Hoc SQL Queries<br/><br/>🕸️ Machine Learning"]
    end

    src -- "bronze.load_bronze<br/>(BULK INSERT)" --> bronze
    gold --> con

    classDef bronzeStyle fill:#fae5d3,stroke:#d35400,stroke-width:2px,color:#000
    classDef silverStyle fill:#ebedef,stroke:#7f8c8d,stroke-width:2px,color:#000
    classDef goldStyle fill:#fcf3cf,stroke:#f1c40f,stroke-width:2px,color:#000
    classDef plain fill:#fff,stroke:#fff,color:#000
    class bronze bronzeStyle
    class silver silverStyle
    class gold goldStyle
    class src,con plain
    style SRC fill:#fff,stroke:#ccc,stroke-dasharray:5 5
    style DWH fill:#fff,stroke:#ccc,stroke-dasharray:5 5
    style CON fill:#fff,stroke:#ccc,stroke-dasharray:5 5
```

## Layers

| Layer | Object | How it is loaded | What happens |
|---|---|---|---|
| Bronze | Tables | `bronze.load_bronze`: truncate, then `BULK INSERT` each CSV | Nothing, data kept as received |
| Silver | Tables | `silver.load_silver`: truncate, then `INSERT ... SELECT` from Bronze | Cleaning, standardising, derived columns, key alignment |
| Gold | Views | Not loaded; views read Silver at query time | Joins CRM and ERP into a star schema |
