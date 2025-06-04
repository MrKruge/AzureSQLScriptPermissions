# Azure SQL Permission Scripting Utility

This repository provides a set of T-SQL scripts and stored procedures to collect and script out database-level users, roles, and permissions within an **Azure SQL Database** environment. It is adapted for Azure SQL where SQL Agent, server-level permissions, and cross-database scripting are not available.

## Features

- **Capture and script out:**
  - Database users (`CREATE USER ...`)
  - Database role memberships (`ALTER ROLE ... ADD MEMBER`)
  - User-level database permissions (`GRANT`, `DENY`, etc.)
  - Object-level permissions (on tables/views/procs/columns)
- **Query history of permission scripts** for a specified time window
- **No SQL Agent jobs required**; fully T-SQL/stored-procedure based

> **Note:**  
> Server-level logins, server-wide permissions, and roles **cannot** be scripted in Azure SQL Database. Use [Azure SQL Managed Instance](https://docs.microsoft.com/en-us/azure/azure-sql/managed-instance/) or SQL Server for such tasks.

## Usage

### 1. Deploy Objects

Run the `AzureSQLScriptPermisisons.sql` script in your target Azure SQL Database. It will:

- Drop and recreate reporting/staging tables
- Deploy stored procedures for collecting and querying permissions

### 2. Gather Permissions

Execute:
```sql
EXEC dbo.sp_DBA_Get_All_Permissions;
