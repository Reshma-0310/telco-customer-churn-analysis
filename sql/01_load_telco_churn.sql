/* =====================================================================
   Telco Customer Churn - one-click load script (SQL Server / SSMS)
   ---------------------------------------------------------------------
   HOW TO USE
   1. Put WA_Fn-UseC_-Telco-Customer-Churn.csv somewhere the SQL Server
      machine can read it (for a local install, e.g. C:\data\).
   2. Change @FilePath below to that full path.
   3. Press F5.

   Result: database TelcoChurn, table dbo.telco_churn (7,043 rows) with
   proper data types. Safe to re-run: it drops and rebuilds everything.

   Needs SQL Server 2017 or later (uses BULK INSERT ... FORMAT = 'CSV').
   ===================================================================== */

DECLARE @FilePath NVARCHAR(500) = N'C:\Customer_Behavior_Analysis\data\WA_Fn-UseC_-Telco-Customer-Churn.csv';  -- <== EDIT THIS

SET NOCOUNT ON;

IF DB_ID(N'TelcoChurn') IS NULL
    CREATE DATABASE TelcoChurn;
USE TelcoChurn;
/* ---------- 1. Staging table: everything as text, so the load never fails ---------- */
DROP TABLE IF EXISTS dbo.stg_telco_churn;
CREATE TABLE dbo.stg_telco_churn (
    customerID       NVARCHAR(50),
    gender           NVARCHAR(50),
    SeniorCitizen    NVARCHAR(50),
    Partner          NVARCHAR(50),
    Dependents       NVARCHAR(50),
    tenure           NVARCHAR(50),
    PhoneService     NVARCHAR(50),
    MultipleLines    NVARCHAR(50),
    InternetService  NVARCHAR(50),
    OnlineSecurity   NVARCHAR(50),
    OnlineBackup     NVARCHAR(50),
    DeviceProtection NVARCHAR(50),
    TechSupport      NVARCHAR(50),
    StreamingTV      NVARCHAR(50),
    StreamingMovies  NVARCHAR(50),
    Contract         NVARCHAR(50),
    PaperlessBilling NVARCHAR(50),
    PaymentMethod    NVARCHAR(50),
    MonthlyCharges   NVARCHAR(50),
    TotalCharges     NVARCHAR(50),
    Churn            NVARCHAR(50)
);
/* ---------- 2. Bulk load the CSV (path is read from the variable set above) ---------- */
/* BULK INSERT cannot take a variable directly, so the statement is built as dynamic SQL. */
DECLARE @sql NVARCHAR(MAX) = N'
BULK INSERT dbo.stg_telco_churn
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH (
    FORMAT          = ''CSV'',
    FIRSTROW        = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    CODEPAGE        = ''65001'',
    TABLOCK
);';
EXEC sys.sp_executesql @sql;
/* ---------- 3. Final table with proper data types ---------- */
DROP TABLE IF EXISTS dbo.telco_churn;
CREATE TABLE dbo.telco_churn (
    customerID       VARCHAR(20)   NOT NULL PRIMARY KEY,
    gender           VARCHAR(10)   NOT NULL,
    SeniorCitizen    BIT           NOT NULL,
    Partner          VARCHAR(3)    NOT NULL,
    Dependents       VARCHAR(3)    NOT NULL,
    tenure           INT           NOT NULL,
    PhoneService     VARCHAR(3)    NOT NULL,
    MultipleLines    VARCHAR(20)   NOT NULL,
    InternetService  VARCHAR(20)   NOT NULL,
    OnlineSecurity   VARCHAR(25)   NOT NULL,
    OnlineBackup     VARCHAR(25)   NOT NULL,
    DeviceProtection VARCHAR(25)   NOT NULL,
    TechSupport      VARCHAR(25)   NOT NULL,
    StreamingTV      VARCHAR(25)   NOT NULL,
    StreamingMovies  VARCHAR(25)   NOT NULL,
    Contract         VARCHAR(20)   NOT NULL,
    PaperlessBilling VARCHAR(3)    NOT NULL,
    PaymentMethod    VARCHAR(30)   NOT NULL,
    MonthlyCharges   DECIMAL(8,2)  NOT NULL,
    TotalCharges     DECIMAL(10,2) NULL,      -- NULL for the 11 customers with tenure = 0 (blank in the CSV)
    Churn            VARCHAR(3)    NOT NULL,
    ChurnFlag        AS (CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) PERSISTED
);

INSERT INTO dbo.telco_churn
    (customerID, gender, SeniorCitizen, Partner, Dependents, tenure, PhoneService,
     MultipleLines, InternetService, OnlineSecurity, OnlineBackup, DeviceProtection,
     TechSupport, StreamingTV, StreamingMovies, Contract, PaperlessBilling,
     PaymentMethod, MonthlyCharges, TotalCharges, Churn)
SELECT
    LTRIM(RTRIM(customerID)),
    LTRIM(RTRIM(gender)),
    CAST(LTRIM(RTRIM(SeniorCitizen)) AS BIT),
    LTRIM(RTRIM(Partner)),
    LTRIM(RTRIM(Dependents)),
    CAST(LTRIM(RTRIM(tenure)) AS INT),
    LTRIM(RTRIM(PhoneService)),
    LTRIM(RTRIM(MultipleLines)),
    LTRIM(RTRIM(InternetService)),
    LTRIM(RTRIM(OnlineSecurity)),
    LTRIM(RTRIM(OnlineBackup)),
    LTRIM(RTRIM(DeviceProtection)),
    LTRIM(RTRIM(TechSupport)),
    LTRIM(RTRIM(StreamingTV)),
    LTRIM(RTRIM(StreamingMovies)),
    LTRIM(RTRIM(Contract)),
    LTRIM(RTRIM(PaperlessBilling)),
    LTRIM(RTRIM(PaymentMethod)),
    CAST(LTRIM(RTRIM(MonthlyCharges)) AS DECIMAL(8,2)),
    TRY_CAST(NULLIF(LTRIM(RTRIM(TotalCharges)), '') AS DECIMAL(10,2)),
    REPLACE(LTRIM(RTRIM(Churn)), CHAR(13), '')      -- strips a stray carriage return if the file has Windows line endings
FROM dbo.stg_telco_churn;

DROP TABLE dbo.stg_telco_churn;
/* ---------- 4. Sanity checks - compare with the expected values ---------- */
SELECT
    COUNT(*)                                        AS total_rows,        -- expect 7043
    SUM(ChurnFlag)                                  AS churned,           -- expect 1869
    SUM(CASE WHEN TotalCharges IS NULL THEN 1 END)  AS null_totalcharges, -- expect 11
    COUNT(DISTINCT customerID)                      AS distinct_ids       -- expect 7043
FROM dbo.telco_churn;
