-- ==============================================================================
-- PROJECT: UCI Online Retail II - E-commerce Sales Analysis & BI Dashboard
-- SCRIPT 02: Analytical Business Queries (Basic, Intermediate, Window Functions)
-- DATABASE: SQLite 3 (ecommerce_analytics.db)
-- ==============================================================================

-- ==============================================================================
-- 1. BASIC BUSINESS QUERIES
-- ==============================================================================

-- Query 1.1: Overall Commercial KPIs
-- Business Question: What is the total gross revenue, order volume, registered customer base, and catalog breadth?
SELECT 
    ROUND(SUM(Revenue), 2) AS total_gross_revenue,
    COUNT(DISTINCT Invoice) AS total_orders,
    COUNT(DISTINCT Customer_ID) AS total_registered_customers,
    COUNT(DISTINCT StockCode) AS total_products_sold,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov
FROM fact_sales;

-- Query 1.2: Revenue by Country
-- Business Question: How is gross sales revenue distributed geographically across countries?
SELECT 
    Country,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    COUNT(DISTINCT Invoice) AS total_orders,
    COUNT(DISTINCT Customer_ID) AS registered_customers,
    ROUND((SUM(Revenue) * 100.0) / (SELECT SUM(Revenue) FROM fact_sales), 2) AS revenue_share_pct
FROM fact_sales
GROUP BY Country
ORDER BY total_revenue DESC;

-- Query 1.3: Monthly Revenue Trajectory
-- Business Question: What is the month-by-month revenue, order count, and average order value?
SELECT 
    strftime('%Y-%m', InvoiceDate) AS sales_month,
    ROUND(SUM(Revenue), 2) AS monthly_revenue,
    COUNT(DISTINCT Invoice) AS order_count,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov
FROM fact_sales
GROUP BY strftime('%Y-%m', InvoiceDate)
ORDER BY sales_month;

-- Query 1.4: Top 10 Products by Revenue
-- Business Question: Which 10 commercial SKUs generate the highest gross monetary sales?
SELECT 
    StockCode,
    MAX(Description) AS Description,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    SUM(Quantity) AS total_units_sold,
    COUNT(DISTINCT Invoice) AS order_occurrences
FROM fact_sales
GROUP BY StockCode
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 1.5: Top 10 Customers by Lifetime Spend
-- Business Question: Who are our top 10 highest-value registered wholesale customers?
SELECT 
    Customer_ID,
    MAX(Country) AS Country,
    ROUND(SUM(Revenue), 2) AS total_spend,
    COUNT(DISTINCT Invoice) AS order_count,
    SUM(Quantity) AS total_items_purchased,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov
FROM fact_sales
WHERE Customer_ID IS NOT NULL
GROUP BY Customer_ID
ORDER BY total_spend DESC
LIMIT 10;

-- ==============================================================================
-- 2. INTERMEDIATE QUERIES (GROUP BY, HAVING, JOINS, CTES, CASE WHEN)
-- ==============================================================================

-- Query 2.1: High-Frequency Repeat Buyers (HAVING clause)
-- Business Question: Which registered customers have completed more than 10 orders?
SELECT 
    Customer_ID,
    Country,
    COUNT(DISTINCT Invoice) AS order_count,
    ROUND(SUM(Revenue), 2) AS total_spend,
    ROUND(SUM(Revenue) / COUNT(DISTINCT Invoice), 2) AS aov
FROM fact_sales
WHERE Customer_ID IS NOT NULL
GROUP BY Customer_ID, Country
HAVING COUNT(DISTINCT Invoice) > 10
ORDER BY order_count DESC;

-- Query 2.2: High Volume but Low Revenue Products (Price Tier Classification using CASE WHEN & CTE)
-- Business Question: Which items move over 20,000 units but generate under £25,000 in revenue?
WITH ProductMetrics AS (
    SELECT 
        StockCode,
        MAX(Description) AS Description,
        SUM(Quantity) AS total_units,
        ROUND(SUM(Revenue), 2) AS total_revenue,
        ROUND(AVG(Price), 2) AS avg_unit_price
    FROM fact_sales
    GROUP BY StockCode
)
SELECT 
    StockCode,
    Description,
    total_units,
    total_revenue,
    avg_unit_price,
    CASE 
        WHEN avg_unit_price < 1.00 THEN 'Impulse / Loss Leader (< £1)'
        WHEN avg_unit_price < 3.00 THEN 'Budget Core (£1 - £3)'
        ELSE 'Premium (£3+)'
    END AS pricing_classification
FROM ProductMetrics
WHERE total_units > 20000 AND total_revenue < 25000
ORDER BY total_units DESC;

-- Query 2.3: Dormant Accounts with High Historical Spend (Subquery / Recency Filter)
-- Business Question: Which customers spent over £3,000 historically but placed zero orders in the last 180 days?
SELECT 
    Customer_ID,
    MAX(Country) AS Country,
    ROUND(SUM(Revenue), 2) AS total_historical_spend,
    COUNT(DISTINCT Invoice) AS total_orders,
    MAX(InvoiceDate) AS last_order_date,
    CAST((julianday('2011-12-10') - julianday(MAX(InvoiceDate))) AS INTEGER) AS days_inactive
FROM fact_sales
WHERE Customer_ID IS NOT NULL
GROUP BY Customer_ID
HAVING days_inactive > 180 AND total_historical_spend > 3000
ORDER BY total_historical_spend DESC;

-- ==============================================================================
-- 3. ADVANCED WINDOW FUNCTION ANALYSIS
-- ==============================================================================

-- Query 3.1: Month-over-Month (MoM) Revenue Growth & Cumulative Running Total (LAG & SUM OVER)
-- Business Question: How does revenue trend month-over-month in absolute value, growth rate %, and cumulative progress?
WITH MonthlySales AS (
    SELECT 
        strftime('%Y-%m', InvoiceDate) AS sales_month,
        ROUND(SUM(Revenue), 2) AS monthly_revenue,
        COUNT(DISTINCT Invoice) AS order_count
    FROM fact_sales
    GROUP BY strftime('%Y-%m', InvoiceDate)
)
SELECT 
    sales_month,
    monthly_revenue,
    order_count,
    LAG(monthly_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY sales_month), 2) AS mom_revenue_change,
    ROUND(
        ((monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY sales_month)) / 
        LAG(monthly_revenue, 1) OVER (ORDER BY sales_month)) * 100.0, 
        2
    ) AS mom_growth_pct,
    ROUND(SUM(monthly_revenue) OVER (ORDER BY sales_month), 2) AS cumulative_revenue
FROM MonthlySales
ORDER BY sales_month;

-- Query 3.2: Product Contribution to Global Revenue (Window Ratio with SUM OVER)
-- Business Question: What is each product SKU's percentage contribution to total global sales?
WITH ProductAggregates AS (
    SELECT 
        StockCode,
        MAX(Description) AS Description,
        ROUND(SUM(Revenue), 2) AS product_revenue,
        SUM(Quantity) AS units_sold
    FROM fact_sales
    GROUP BY StockCode
)
SELECT 
    StockCode,
    Description,
    product_revenue,
    units_sold,
    ROUND((product_revenue * 100.0) / SUM(product_revenue) OVER (), 3) AS revenue_contribution_pct,
    ROUND(SUM(product_revenue) OVER (ORDER BY product_revenue DESC) * 100.0 / SUM(product_revenue) OVER (), 2) AS cumulative_revenue_pct,
    DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS global_rank
FROM ProductAggregates
ORDER BY product_revenue DESC
LIMIT 20;

-- Query 3.3: Top 3 Products within Each Major Country (DENSE_RANK OVER PARTITION BY Country)
-- Business Question: What are the top 3 best-selling product SKUs inside each key geographic market?
WITH CountryProductSales AS (
    SELECT 
        Country,
        StockCode,
        MAX(Description) AS Description,
        ROUND(SUM(Revenue), 2) AS product_revenue,
        SUM(Quantity) AS units_sold
    FROM fact_sales
    GROUP BY Country, StockCode
),
RankedByCountry AS (
    SELECT 
        Country,
        StockCode,
        Description,
        product_revenue,
        units_sold,
        DENSE_RANK() OVER (PARTITION BY Country ORDER BY product_revenue DESC) AS rank_in_country
    FROM CountryProductSales
)
SELECT 
    Country,
    rank_in_country,
    StockCode,
    Description,
    product_revenue,
    units_sold
FROM RankedByCountry
WHERE rank_in_country <= 3 AND Country IN ('United Kingdom', 'EIRE', 'Netherlands', 'Germany', 'France', 'Australia')
ORDER BY Country, rank_in_country;

-- ==============================================================================
-- 4. RFM SEGMENTATION INTEGRATION (JOIN & SEGMENT PERFORMANCE)
-- ==============================================================================

-- Query 4.1: Commercial Performance by RFM Segment
-- Business Question: How much revenue and order volume is generated by each RFM segment?
SELECT 
    r.Segment,
    COUNT(DISTINCT s.Customer_ID) AS active_customer_count,
    COUNT(DISTINCT s.Invoice) AS total_orders,
    ROUND(SUM(s.Revenue), 2) AS segment_revenue,
    ROUND(SUM(s.Revenue) / COUNT(DISTINCT s.Customer_ID), 2) AS avg_spend_per_customer,
    ROUND(SUM(s.Revenue) / COUNT(DISTINCT s.Invoice), 2) AS aov,
    ROUND((SUM(s.Revenue) * 100.0) / (SELECT SUM(Revenue) FROM fact_sales WHERE Customer_ID IS NOT NULL), 2) AS revenue_share_pct
FROM fact_sales s
INNER JOIN dim_customer_rfm r ON s.Customer_ID = r.Customer_ID
GROUP BY r.Segment
ORDER BY segment_revenue DESC;

-- Query 4.2: Top Customers in the "Cannot Lose Them" Segment
-- Business Question: Who are our highest-value lapsed accounts that require immediate win-back attention?
SELECT 
    r.Customer_ID,
    r.Country,
    r.Monetary AS lifetime_gross_spend,
    r.Frequency AS lifetime_orders,
    r.Recency AS days_since_last_order,
    r.R_Score,
    r.F_Score,
    r.M_Score
FROM dim_customer_rfm r
WHERE r.Segment = 'Cannot Lose Them'
ORDER BY r.Monetary DESC
LIMIT 10;

-- Query 4.3: Geographic Distribution of "Champions" Revenue
-- Business Question: In which countries is our Champions segment most active?
SELECT 
    s.Country,
    COUNT(DISTINCT s.Customer_ID) AS champion_customer_count,
    COUNT(DISTINCT s.Invoice) AS champion_orders,
    ROUND(SUM(s.Revenue), 2) AS champion_revenue,
    ROUND(SUM(s.Revenue) / COUNT(DISTINCT s.Customer_ID), 2) AS avg_spend_per_champion
FROM fact_sales s
INNER JOIN dim_customer_rfm r ON s.Customer_ID = r.Customer_ID
WHERE r.Segment = 'Champions'
GROUP BY s.Country
ORDER BY champion_revenue DESC
LIMIT 10;

-- ==============================================================================
-- 5. RETURNS & REFUND RISK ANALYSIS
-- ==============================================================================

-- Query 5.1: Refund Impact and Net Revenue Reconciliation by Country
-- Business Question: What is the gross revenue, refund value, and net realized revenue for the top 10 countries?
WITH GrossByCountry AS (
    SELECT Country, ROUND(SUM(Revenue), 2) AS gross_sales FROM fact_sales GROUP BY Country
),
ReturnsByCountry AS (
    SELECT Country, ROUND(ABS(SUM(Revenue)), 2) AS total_refunds FROM fact_returns GROUP BY Country
)
SELECT 
    g.Country,
    g.gross_sales,
    COALESCE(r.total_refunds, 0.0) AS total_refunds,
    ROUND(g.gross_sales - COALESCE(r.total_refunds, 0.0), 2) AS net_realized_revenue,
    ROUND((COALESCE(r.total_refunds, 0.0) / g.gross_sales) * 100.0, 2) AS refund_rate_pct
FROM GrossByCountry g
LEFT JOIN ReturnsByCountry r ON g.Country = r.Country
ORDER BY g.gross_sales DESC
LIMIT 10;

-- Query 5.2: Top Products with Highest Monetary Refund Values
-- Business Question: Which product SKUs experience the largest monetary return losses?
SELECT 
    r.StockCode,
    MAX(r.Description) AS Description,
    COUNT(DISTINCT r.Invoice) AS return_orders,
    ABS(SUM(r.Quantity)) AS units_returned,
    ROUND(ABS(SUM(r.Revenue)), 2) AS total_refund_amount
FROM fact_returns r
GROUP BY r.StockCode
ORDER BY total_refund_amount DESC
LIMIT 10;
