-- Clean up Old Objects in [DBA] database
USE [DBA];

-- Drop Tables if Exist
IF OBJECT_ID(N'dbo.tbl_DBA_Object_level_permissions', N'U') IS NOT NULL DROP TABLE dbo.tbl_DBA_Object_level_permissions;
IF OBJECT_ID(N'dbo.tbl_DBA_role_level_permissions', N'U') IS NOT NULL DROP TABLE dbo.tbl_DBA_role_level_permissions;
IF OBJECT_ID(N'dbo.tbl_DBA_User_level_permissions', N'U') IS NOT NULL DROP TABLE dbo.tbl_DBA_User_level_permissions;
IF OBJECT_ID(N'dbo.tbl_DBA_Users_per_db', N'U') IS NOT NULL DROP TABLE dbo.tbl_DBA_Users_per_db;

-- Drop Procs if Exist
IF OBJECT_ID(N'dbo.sp_DBA_Script_All_Permissions', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_DBA_Script_All_Permissions;
IF OBJECT_ID(N'dbo.sp_DBA_Get_All_Permissions', N'P') IS NOT NULL DROP PROCEDURE dbo.sp_DBA_Get_All_Permissions;

-- Create Tables (all NVARCHAR(MAX) for permission scripting)
CREATE TABLE dbo.tbl_DBA_Object_level_permissions(
    [DATE] DATETIME NULL,
    [DBName] NVARCHAR(256) NULL,
    [Object_level_permission] NVARCHAR(MAX) NULL
);

CREATE TABLE dbo.tbl_DBA_role_level_permissions(
    [DATE] DATETIME NULL,
    [DBName] NVARCHAR(256) NULL,
    [role_level_Permissions] NVARCHAR(MAX) NULL
);

CREATE TABLE dbo.tbl_DBA_User_level_permissions(
    [DATE] DATETIME NULL,
    [DBName] NVARCHAR(256) NULL,
    [User_level_Permissions] NVARCHAR(MAX) NULL
);

CREATE TABLE dbo.tbl_DBA_Users_per_db(
    [DATE] DATETIME NULL,
    [DBName] NVARCHAR(256) NULL,
    [User_per_db] NVARCHAR(MAX) NULL
);

-- Main Procedure to Gather All Database Permissions --
GO
CREATE PROCEDURE dbo.sp_DBA_Get_All_Permissions 
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dbName NVARCHAR(256), @sql NVARCHAR(MAX);

    -- Get list of user databases except system DBs (no cross-server access in Azure SQL, just this DB)
    -- For Azure SQL, there is only the current logical DB; no master access to others.
    -- But keep logic in case you have an Elastic Pool or similar setup.
    -- If for a single DB, this is simple:

    SET @dbName = DB_NAME();

    -- 1. Users Per DB
    INSERT INTO dbo.tbl_DBA_Users_per_db ([DATE], [DBName], [User_per_db])
    SELECT 
        GETDATE(),
        @dbName,
        'CREATE USER ' + QUOTENAME([name]) + ' FOR LOGIN ' + QUOTENAME([name])
    FROM sys.database_principals
    WHERE [type] IN ('S', 'G', 'U')    -- SQL user, Windows group, Windows user
      AND [name] NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
      AND [authentication_type] > 0; -- ignore orphaned users

    -- 2. Role Memberships in DB
    INSERT INTO dbo.tbl_DBA_role_level_permissions ([DATE], [DBName], [role_level_Permissions])
    SELECT
        GETDATE(), 
        @dbName, 
        'ALTER ROLE ' + QUOTENAME(r.name) + ' ADD MEMBER ' + QUOTENAME(u.name) + ';'
    FROM sys.database_role_members m
    INNER JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
    INNER JOIN sys.database_principals u ON u.principal_id = m.member_principal_id
    WHERE u.name <> 'dbo'

    -- 3. User-level permissions (GRANT/DENY)
    INSERT INTO dbo.tbl_DBA_User_level_permissions([DATE], [DBName], [User_level_Permissions])
    SELECT
        GETDATE(),
        @dbName,
        state_desc + ' ' + permission_name + ' TO ' + QUOTENAME(u.name) 
            + CASE WHEN state_desc = 'GRANT_WITH_GRANT_OPTION' THEN ' WITH GRANT OPTION' ELSE '' END + ';'
    FROM sys.database_permissions p
    INNER JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id
    WHERE major_id = 0         -- Database level
      AND u.name <> 'dbo';

    -- 4. Object-level permissions (GRANT/DENY on TABLEs, VIEWS, etc)
    INSERT INTO dbo.tbl_DBA_Object_level_permissions([DATE], [DBName], [Object_level_permission])
    SELECT
        GETDATE(),
        @dbName,
        p.state_desc + ' ' 
            + p.permission_name + 
            ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
            + CASE WHEN c.column_id IS NOT NULL THEN '(' + QUOTENAME(c.name) + ')' ELSE '' END
            + ' TO ' + QUOTENAME(u.name)
            + CASE WHEN p.state_desc = 'GRANT_WITH_GRANT_OPTION' THEN ' WITH GRANT OPTION' ELSE '' END + ';'
    FROM sys.database_permissions p
    INNER JOIN sys.objects o ON p.major_id = o.object_id
    INNER JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id
    LEFT JOIN sys.columns c ON c.object_id = p.major_id AND c.column_id = p.minor_id
    WHERE u.name <> 'dbo';
END
GO

-- Reporting Procedure
CREATE PROCEDURE dbo.sp_DBA_Script_All_Permissions
    @returndays INT = -1,
    @Dbname NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @returndays > 0
    BEGIN
        THROW 50001, N'You must enter a negative number of days.', 1;
    END

    DECLARE @daysminus DATETIME = DATEADD(day, @returndays, GETDATE());

    -- Return everything in this DB, filtered by recent records and optional DBName filter (single DB in Azure)
    SELECT [DATE], [DBName], [role_level_Permissions]
    FROM dbo.tbl_DBA_role_level_permissions
    WHERE [DATE] > @daysminus AND (@Dbname IS NULL OR [DBName] = @Dbname);

    SELECT [DATE], [DBName], [User_per_db]
    FROM dbo.tbl_DBA_Users_per_db
    WHERE [DATE] > @daysminus AND (@Dbname IS NULL OR [DBName] = @Dbname);

    SELECT [DATE], [DBName], [User_level_Permissions]
    FROM dbo.tbl_DBA_User_level_permissions
    WHERE [DATE] > @daysminus AND (@Dbname IS NULL OR [DBName] = @Dbname);

    SELECT [DATE], [DBName], [Object_level_permission]
    FROM dbo.tbl_DBA_Object_level_permissions
    WHERE [DATE] > @daysminus AND (@Dbname IS NULL OR [DBName] = @Dbname);

END
GO
