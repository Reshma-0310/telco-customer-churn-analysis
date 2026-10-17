/* =====================================================================
   Telco Customer Churn - SQL analysis (SQL Server / T-SQL)
   Run 01_load_telco_churn.sql first. Table: dbo.telco_churn
   Each query is numbered; expected results are in the README / notebook.
   ===================================================================== */
USE TelcoChurn;
GO

/* Q1. Overall churn rate */
SELECT
    COUNT(*)                                              AS total_customers,
    SUM(ChurnFlag)                                        AS churned_customers,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn;
GO

/* Q2. Churn by contract type */
SELECT
    Contract,
    COUNT(*)                                              AS customers,
    SUM(ChurnFlag)                                        AS churned,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn
GROUP BY Contract
ORDER BY churn_rate_pct DESC;
GO

/* Q3. Churn by tenure band */
SELECT
    CASE
        WHEN tenure BETWEEN 0  AND 12 THEN '1) 0-12 months'
        WHEN tenure BETWEEN 13 AND 24 THEN '2) 13-24 months'
        WHEN tenure BETWEEN 25 AND 48 THEN '3) 25-48 months'
        ELSE                               '4) 49+ months'
    END                                                   AS tenure_band,
    COUNT(*)                                              AS customers,
    SUM(ChurnFlag)                                        AS churned,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn
GROUP BY
    CASE
        WHEN tenure BETWEEN 0  AND 12 THEN '1) 0-12 months'
        WHEN tenure BETWEEN 13 AND 24 THEN '2) 13-24 months'
        WHEN tenure BETWEEN 25 AND 48 THEN '3) 25-48 months'
        ELSE                               '4) 49+ months'
    END
ORDER BY tenure_band;
GO

/* Q4. Churn by internet service type */
SELECT
    InternetService,
    COUNT(*)                                              AS customers,
    SUM(ChurnFlag)                                        AS churned,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;
GO

/* Q5. Churn by payment method */
SELECT
    PaymentMethod,
    COUNT(*)                                              AS customers,
    SUM(ChurnFlag)                                        AS churned,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;
GO

/* Q6. Do protective services matter? Churn for internet customers with vs without each add-on */
SELECT service, has_service, customers, churned,
       CAST(100.0 * churned / customers AS DECIMAL(5,2)) AS churn_rate_pct
FROM (
    SELECT 'OnlineSecurity' AS service, OnlineSecurity AS has_service, COUNT(*) AS customers, SUM(ChurnFlag) AS churned
    FROM dbo.telco_churn WHERE InternetService <> 'No' GROUP BY OnlineSecurity
    UNION ALL
    SELECT 'TechSupport', TechSupport, COUNT(*), SUM(ChurnFlag)
    FROM dbo.telco_churn WHERE InternetService <> 'No' GROUP BY TechSupport
    UNION ALL
    SELECT 'OnlineBackup', OnlineBackup, COUNT(*), SUM(ChurnFlag)
    FROM dbo.telco_churn WHERE InternetService <> 'No' GROUP BY OnlineBackup
    UNION ALL
    SELECT 'DeviceProtection', DeviceProtection, COUNT(*), SUM(ChurnFlag)
    FROM dbo.telco_churn WHERE InternetService <> 'No' GROUP BY DeviceProtection
) t
ORDER BY service, has_service;
GO

/* Q7. Monthly revenue lost to churn vs retained */
SELECT
    Churn,
    COUNT(*)                                   AS customers,
    CAST(AVG(MonthlyCharges) AS DECIMAL(8,2))  AS avg_monthly_charge,
    CAST(SUM(MonthlyCharges) AS DECIMAL(12,2)) AS total_monthly_revenue
FROM dbo.telco_churn
GROUP BY Churn;
GO

/* Q8. Monthly revenue share lost: churned MRR as % of all MRR */
SELECT
    CAST(SUM(CASE WHEN Churn = 'Yes' THEN MonthlyCharges END) AS DECIMAL(12,2)) AS churned_mrr,
    CAST(SUM(MonthlyCharges) AS DECIMAL(12,2))                                  AS total_mrr,
    CAST(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN MonthlyCharges END)
               / SUM(MonthlyCharges) AS DECIMAL(5,2))                           AS pct_mrr_lost
FROM dbo.telco_churn;
GO

/* Q9. Demographics: senior citizens, partners and dependents */
SELECT 'SeniorCitizen' AS segment, CASE WHEN SeniorCitizen = 1 THEN 'Yes' ELSE 'No' END AS value,
       COUNT(*) AS customers, CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn GROUP BY SeniorCitizen
UNION ALL
SELECT 'Partner', Partner, COUNT(*), CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2))
FROM dbo.telco_churn GROUP BY Partner
UNION ALL
SELECT 'Dependents', Dependents, COUNT(*), CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2))
FROM dbo.telco_churn GROUP BY Dependents;
GO

/* Q10. Highest-risk segments: contract x internet service, ranked (CTE + window function) */
WITH seg AS (
    SELECT
        Contract,
        InternetService,
        COUNT(*)                                              AS customers,
        SUM(ChurnFlag)                                        AS churned,
        CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
    FROM dbo.telco_churn
    GROUP BY Contract, InternetService
)
SELECT
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS risk_rank,
    Contract, InternetService, customers, churned, churn_rate_pct
FROM seg
ORDER BY risk_rank;
GO

/* Q11. The "perfect storm" profile: month-to-month + fiber optic + electronic check */
SELECT
    COUNT(*)                                              AS customers,
    SUM(ChurnFlag)                                        AS churned,
    CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM dbo.telco_churn
WHERE Contract = 'Month-to-month'
  AND InternetService = 'Fiber optic'
  AND PaymentMethod = 'Electronic check';
GO

/* Q12. Early-life churn: of everyone who churned, what share left within their first year? */
SELECT
    CAST(100.0 * SUM(CASE WHEN tenure <= 12 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_of_churners_in_first_12_months
FROM dbo.telco_churn
WHERE Churn = 'Yes';
GO
