-- ==============================================================================
-- PROJECT: UCI Online Retail II - E-commerce Sales Analysis & BI Dashboard
-- SCRIPT 01: Database Schema, Table Definitions, Indexes, and Analytical Views
-- DATABASE: SQLite 3 (ecommerce_analytics.db)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FACT TABLES & DIMENSION TABLES SCHEMA
-- ------------------------------------------------------------------------------

-- Table: fact_sales (Clean commercial regular transactions)
CREATE TABLE IF NOT EXISTS fact_sales (
    Invoice TEXT NOT NULL,
    StockCode TEXT NOT NULL,
    Description TEXT,
    Quantity INTEGER NOT NULL,
    InvoiceDate TEXT NOT NULL,
    Price REAL NOT NULL,
    Customer_ID TEXT,
    Country TEXT NOT NULL,
    Revenue REAL NOT NULL,
    Is_Promotional INTEGER NOT NULL,
    Year INTEGER NOT NULL,
    Month INTEGER NOT NULL,
    Month_Name TEXT NOT NULL,
    Quarter INTEGER NOT NULL,
    Day INTEGER NOT NULL,
    Day_Name TEXT NOT NULL,
    Hour INTEGER NOT NULL
);

-- Table: fact_returns (Customer cancellations, returns, and credit notes)
CREATE TABLE IF NOT EXISTS fact_returns (
    Invoice TEXT NOT NULL,
    StockCode TEXT NOT NULL,
    Description TEXT,
    Quantity INTEGER NOT NULL,
    InvoiceDate TEXT NOT NULL,
    Price REAL NOT NULL,
    Customer_ID TEXT,
    Country TEXT NOT NULL,
    Revenue REAL NOT NULL,
    Year INTEGER NOT NULL,
    Month INTEGER NOT NULL,
    Month_Name TEXT NOT NULL,
    Quarter INTEGER NOT NULL,
    Day INTEGER NOT NULL,
    Day_Name TEXT NOT NULL,
    Hour INTEGER NOT NULL
);

-- Table: inventory_adjustments (Internal warehouse corrections, damages, lost stock)
CREATE TABLE IF NOT EXISTS inventory_adjustments (
    Invoice TEXT NOT NULL,
    StockCode TEXT NOT NULL,
    Description TEXT,
    Quantity INTEGER NOT NULL,
    InvoiceDate TEXT NOT NULL,
    Price REAL NOT NULL,
    Customer_ID TEXT,
    Country TEXT NOT NULL
);

-- Table: accounting_adjustments (Corporate bad debt write-downs)
CREATE TABLE IF NOT EXISTS accounting_adjustments (
    Invoice TEXT NOT NULL,
    StockCode TEXT NOT NULL,
    Description TEXT,
    Quantity INTEGER NOT NULL,
    InvoiceDate TEXT NOT NULL,
    Price REAL NOT NULL,
    Customer_ID TEXT,
    Country TEXT NOT NULL
);

-- Table: dim_customer_rfm (Customer-level RFM metrics & segment labels)
CREATE TABLE IF NOT EXISTS dim_customer_rfm (
    Customer_ID TEXT PRIMARY KEY,
    LastPurchaseDate TEXT NOT NULL,
    Frequency INTEGER NOT NULL,
    Monetary REAL NOT NULL,
    TotalItems INTEGER NOT NULL,
    Country TEXT NOT NULL,
    Recency INTEGER NOT NULL,
    R_Score INTEGER NOT NULL,
    F_Score INTEGER NOT NULL,
    M_Score INTEGER NOT NULL,
    RFM_Score TEXT NOT NULL,
    RFM_Average REAL NOT NULL,
    Segment TEXT NOT NULL
);

-- ------------------------------------------------------------------------------
-- 2. PERFORMANCE INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_sales_invoice ON fact_sales(Invoice);
CREATE INDEX IF NOT EXISTS idx_sales_stockcode ON fact_sales(StockCode);
CREATE INDEX IF NOT EXISTS idx_sales_customer ON fact_sales(Customer_ID);
CREATE INDEX IF NOT EXISTS idx_sales_date ON fact_sales(InvoiceDate);
CREATE INDEX IF NOT EXISTS idx_sales_country ON fact_sales(Country);

CREATE INDEX IF NOT EXISTS idx_returns_customer ON fact_returns(Customer_ID);
CREATE INDEX IF NOT EXISTS idx_returns_stockcode ON fact_returns(StockCode);
CREATE INDEX IF NOT EXISTS idx_returns_date ON fact_returns(InvoiceDate);

CREATE INDEX IF NOT EXISTS idx_rfm_customer ON dim_customer_rfm(Customer_ID);
CREATE INDEX IF NOT EXISTS idx_rfm_segment ON dim_customer_rfm(Segment);

-- ------------------------------------------------------------------------------
-- 3. REUSABLE ANALYTICAL VIEWS FOR BI & REPORTING
-- ------------------------------------------------------------------------------

-- View 1: Monthly Sales & Demand Trajectory
DROP VIEW IF EXISTS vw_monthly_sales;
CREATE VIEW vw_monthly_sales AS
SELECT 
    strftime('%Y-%m', InvoiceDate) AS sales_month,
    ROUND(SUM(Revenue), 2) AS gross_revenue,
    COUNT(DISTINCT Invoice) AS total_orders,
    COUNT(DISTINCT Customer_ID) AS active_registered_customers,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov
FROM fact_sales
GROUP BY strftime('%Y-%m', InvoiceDate);

-- View 2: Geographic Market Performance & Country Market Share
DROP VIEW IF EXISTS vw_country_performance;
CREATE VIEW vw_country_performance AS
SELECT 
    Country,
    ROUND(SUM(Revenue), 2) AS gross_revenue,
    COUNT(DISTINCT Invoice) AS total_orders,
    COUNT(DISTINCT Customer_ID) AS total_customers,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov,
    ROUND((SUM(Revenue) * 100.0) / (SELECT SUM(Revenue) FROM fact_sales), 2) AS market_share_pct
FROM fact_sales
GROUP BY Country;

-- View 3: Product Performance & Ranking Catalog
DROP VIEW IF EXISTS vw_top_products;
CREATE VIEW vw_top_products AS
SELECT 
    StockCode,
    MAX(Description) AS Description,
    ROUND(SUM(Revenue), 2) AS gross_revenue,
    SUM(Quantity) AS total_units_sold,
    COUNT(DISTINCT Invoice) AS total_orders,
    ROUND(AVG(Price), 2) AS avg_unit_price,
    DENSE_RANK() OVER (ORDER BY SUM(Revenue) DESC) AS revenue_rank
FROM fact_sales
GROUP BY StockCode;

-- View 4: RFM Customer Segment Financial Performance
DROP VIEW IF EXISTS vw_customer_segments;
CREATE VIEW vw_customer_segments AS
SELECT 
    r.Segment,
    COUNT(DISTINCT r.Customer_ID) AS total_customers,
    COUNT(DISTINCT s.Invoice) AS total_orders,
    ROUND(SUM(s.Revenue), 2) AS segment_revenue,
    ROUND(SUM(s.Revenue) / COUNT(DISTINCT r.Customer_ID), 2) AS avg_customer_spend,
    ROUND(SUM(s.Revenue) / COUNT(DISTINCT s.Invoice), 2) AS aov,
    ROUND((SUM(s.Revenue) * 100.0) / (SELECT SUM(Revenue) FROM fact_sales WHERE Customer_ID IS NOT NULL), 2) AS revenue_contribution_pct
FROM dim_customer_rfm r
LEFT JOIN fact_sales s ON r.Customer_ID = s.Customer_ID
GROUP BY r.Segment;

-- View 5: Monthly Return & Refund Activity
DROP VIEW IF EXISTS vw_monthly_returns;
CREATE VIEW vw_monthly_returns AS
SELECT 
    strftime('%Y-%m', InvoiceDate) AS return_month,
    ROUND(ABS(SUM(Revenue)), 2) AS total_refund_amount,
    ABS(SUM(Quantity)) AS units_returned,
    COUNT(DISTINCT Invoice) AS return_orders,
    COUNT(*) AS return_line_items
FROM fact_returns
GROUP BY strftime('%Y-%m', InvoiceDate);

