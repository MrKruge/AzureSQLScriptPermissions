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
```
This collects the current DB's users, role memberships, and permissions into staging tables.

### 3. Query or Export Permission Scripts
To fetch permissions scripted within the last X days (e.g., last day):

```sql
EXEC dbo.sp_DBA_Script_All_Permissions @returndays = -1; -- last 1 day
```
You can filter further by DB name (not needed in single DB):
```sql
EXEC dbo.sp_DBA_Script_All_Permissions @returndays = -7, @Dbname = N'YOUR_DB_NAME';
```
### 4. Review Results

Result sets show ready-to-execute permission scripts for each captured aspect:
- User creation scripts
- Role membership scripts
- Permission grant/revoke scripts
You can then use these scripts for migration, auditing, or compliance.

### Limitations
- No server-level scripting: Cannot script logins, server-level permissions, or roles on Azure SQL DB.
- No cross-database scripting: Runs within current DB context only.
- For multi-database or automation across servers, consider using Azure Automation, Elastic Jobs, or external scripting.
Credits
Based on original community scripts by Danny Kruge and contributors. Adapted for Azure SQL Database as a GitHub utility.
