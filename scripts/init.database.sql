# Data Warehouse & Analytics Project

**Author:** Ashwani Tripathi

This project demonstrates a comprehensive data warehousing and analytics solution, from building a data warehouse to generating actionable insights. Designed as a portfolio project, it highlights industry best practices in data engineering and analytics.

---

## 🚀 Project Requirements

### Building the Data Warehouse (Data Engineering)

#### Objective
Develop a modern data warehouse using SQL Server to consolidate sales data, enabling analytical reporting and informed decision-making.

#### Specifications
- **Data Sources**: Import data from two source systems (ERP and CRM) provided as CSV files.
- **Data Quality**: Cleanse and resolve data quality issues prior to analysis[cite: 2].
- **Integration**: Combine both sources into a single, user-friendly data model designed for analytical queries[cite: 2].
- **Scope**: Focus on the latest dataset only; historization of data is not required[cite: 2].
- **Documentation**: Provide clear documentation of the data model to support both business stakeholders and analytics teams[cite: 2].

---

## ⚙️ Database Initialization Script

```sql
/*
===============================================================================
Create Database and Schemas
===============================================================================
Script Purpose:
    This script creates a new database named 'DataWarehouse' after checking if it already exists[cite: 1].
    If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
    within the database: 'bronze', 'silver', and 'gold'[cite: 1].

WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists[cite: 1].
    All data in the database will be permanently deleted. Proceed with caution
    and ensure you have proper backups before running this script[cite: 1].
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouse' database[cite: 3]
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')[cite: 3]
BEGIN[cite: 3]
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;[cite: 3]
    DROP DATABASE DataWarehouse;[cite: 3]
END;[cite: 3]
GO

-- Create the 'DataWarehouse' database[cite: 3]
CREATE DATABASE DataWarehouse;[cite: 3]
GO

USE DataWarehouse;[cite: 3]
GO

-- Create Schemas[cite: 3]
CREATE SCHEMA bronze;[cite: 3]
GO

CREATE SCHEMA silver;[cite: 3]
GO

CREATE SCHEMA gold;[cite: 3]
GO
