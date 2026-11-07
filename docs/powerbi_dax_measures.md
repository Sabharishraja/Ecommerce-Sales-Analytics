# Power BI DAX Measures & Business Logic Specification

**Project:** E-commerce Sales Analysis and Business Intelligence Dashboard  
**Dataset:** UCI Online Retail II  
**Data Model:** Enterprise Star Schema  
**Date:** 2026-11-05  

---

## 1. Overview of DAX Measure Architecture

All DAX measures are centralized in a dedicated, empty measure table named `_Measures` in Power BI Desktop for clean organization, discoverability, and governance.

Measures strictly leverage the underlying **Star Schema** relationships:
- All filters naturally propagate from dimension tables (`dim_date`, `dim_customer`, `dim_product`, `dim_country`) downward to the fact tables (`fact_sales`, `fact_returns`).
- Time intelligence measures utilize `dim_date[Date]` as the official marked Date Table.
- Safe division is enforced using `DIVIDE(numerator, denominator, alternate_result)` to prevent division-by-zero errors.

---

## 2. Sales & Core KPI Measures

### 2.1 Total Gross Revenue
- **DAX Formula:**
  ```dax
  Total Revenue = 
  SUM(fact_sales[Revenue])
  ```
- **Description:** Sum of line-item commercial revenue (`Quantity * Price`) across all valid regular sales transactions.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £20,476,260.45

### 2.2 Total Orders
- **DAX Formula:**
  ```dax
  Total Orders = 
  DISTINCTCOUNT(fact_sales[Invoice])
  ```
- **Description:** Distinct count of valid sales invoices.
- **Format:** Whole Number (`#,##0`)
- **Benchmark Value:** 40,083

### 2.3 Total Registered Customers
- **DAX Formula:**
  ```dax
  Total Customers = 
  CALCULATE(
      DISTINCTCOUNT(fact_sales[Customer_ID]),
      fact_sales[Customer_ID] <> "Guest",
      NOT(ISBLANK(fact_sales[Customer_ID]))
  )
  ```
- **Description:** Distinct count of identified commercial customer accounts (excluding anonymous guest checkouts).
- **Format:** Whole Number (`#,##0`)
- **Benchmark Value:** 5,881

### 2.4 Total Quantity Sold
- **DAX Formula:**
  ```dax
  Total Quantity Sold = 
  SUM(fact_sales[Quantity])
  ```
- **Description:** Total physical volume of units dispatched.
- **Format:** Whole Number (`#,##0`)
- **Benchmark Value:** 11,219,901

### 2.5 Average Order Value (AOV)
- **DAX Formula:**
  ```dax
  Average Order Value = 
  DIVIDE([Total Revenue], [Total Orders], 0)
  ```
- **Description:** Average monetary value generated per sales order invoice.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £510.85

### 2.6 Average Revenue Per Customer (ARPC)
- **DAX Formula:**
  ```dax
  Average Revenue Per Customer = 
  DIVIDE(
      CALCULATE(
          [Total Revenue],
          fact_sales[Customer_ID] <> "Guest",
          NOT(ISBLANK(fact_sales[Customer_ID]))
      ),
      [Total Customers],
      0
  )
  ```
- **Description:** Average cumulative gross spend per registered customer.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £2,954.40

### 2.7 Guest Checkout Revenue & Share
- **DAX Formulas:**
  ```dax
  Guest Checkout Revenue = 
  CALCULATE(
      [Total Revenue],
      fact_sales[Customer_ID] = "Guest"
  )
  ```
  ```dax
  Guest Revenue % = 
  DIVIDE([Guest Checkout Revenue], [Total Revenue], 0)
  ```
- **Benchmark Value:** £3,101,456.18 (15.15% of gross revenue)

---

## 3. Time Intelligence Measures

> [!NOTE]
> Time intelligence functions require `dim_date` to be marked as a Date Table (`Date` column as the primary key).

### 3.1 Monthly Revenue
- **DAX Formula:**
  ```dax
  Monthly Revenue = 
  CALCULATE(
      [Total Revenue],
      DATESMTD(dim_date[Date])
  )
  ```
- **Description:** Month-to-date sales revenue based on current visual filter context.
- **Format:** Currency (`£#,##0.00`)

### 3.2 Previous Month Revenue
- **DAX Formula:**
  ```dax
  Previous Month Revenue = 
  CALCULATE(
      [Total Revenue],
      PREVIOUSMONTH(dim_date[Date])
  )
  ```
- **Description:** Revenue generated in the immediate prior calendar month.
- **Format:** Currency (`£#,##0.00`)

### 3.3 Month-over-Month (MoM) Growth %
- **DAX Formula:**
  ```dax
  MoM Growth % = 
  VAR CurrentMonthRev = [Total Revenue]
  VAR PriorMonthRev = [Previous Month Revenue]
  RETURN
  DIVIDE(CurrentMonthRev - PriorMonthRev, PriorMonthRev, BLANK())
  ```
- **Description:** Percentage variance in sales compared to prior month.
- **Format:** Percentage (`+0.00%;-0.00%;0.00%`)

### 3.4 Year-to-Date (YTD) Revenue
- **DAX Formula:**
  ```dax
  YTD Revenue = 
  CALCULATE(
      [Total Revenue],
      DATESYTD(dim_date[Date])
  )
  ```
- **Description:** Cumulative sales within the current calendar year.
- **Format:** Currency (`£#,##0.00`)

### 3.5 Year-over-Year (YoY) Revenue Growth %
- **DAX Formula:**
  ```dax
  Same Period Last Year Revenue = 
  CALCULATE(
      [Total Revenue],
      SAMEPERIODLASTYEAR(dim_date[Date])
  )
  ```
  ```dax
  YoY Growth % = 
  VAR CurrentPeriod = [Total Revenue]
  VAR PriorYearPeriod = [Same Period Last Year Revenue]
  RETURN
  DIVIDE(CurrentPeriod - PriorYearPeriod, PriorYearPeriod, BLANK())
  ```
- **Format:** Percentage (`+0.00%;-0.00%;0.00%`)

---

## 4. Customer Segmentation & RFM Measures

### 4.1 Champions Revenue
- **DAX Formula:**
  ```dax
  Champions Revenue = 
  CALCULATE(
      [Total Revenue],
      dim_customer[Segment] = "Champions"
  )
  ```
- **Description:** Gross revenue generated by the top-tier "Champions" RFM segment.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £11,836,647.75 (68.13% of registered customer spend)

### 4.2 Loyal Customer Revenue
- **DAX Formula:**
  ```dax
  Loyal Customer Revenue = 
  CALCULATE(
      [Total Revenue],
      dim_customer[Segment] = "Loyal Customers"
  )
  ```
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £2,592,612.65 (14.92% of registered spend)

### 4.3 At Risk Customer Count
- **DAX Formula:**
  ```dax
  At Risk Customers = 
  CALCULATE(
      DISTINCTCOUNT(dim_customer[Customer_ID]),
      dim_customer[Segment] = "At Risk"
  )
  ```
- **Description:** Count of high-value historical customers who have lapsed in purchase frequency and recency.
- **Format:** Whole Number (`#,##0`)
- **Benchmark Value:** 841 customers

### 4.4 Customer Segment Contribution %
- **DAX Formula:**
  ```dax
  Customer Segment Contribution % = 
  VAR SegmentSpend = [Total Revenue]
  VAR TotalRegisteredSpend = 
      CALCULATE(
          [Total Revenue],
          ALL(dim_customer[Segment]),
          dim_customer[Customer_ID] <> "Guest"
      )
  RETURN
  DIVIDE(SegmentSpend, TotalRegisteredSpend, 0)
  ```
- **Description:** Percentage share of registered customer revenue attributable to the selected RFM segment.
- **Format:** Percentage (`0.00%`)

---

## 5. Returns, Refunds & Net Sales Measures

### 5.1 Total Refund Value
- **DAX Formula:**
  ```dax
  Total Refund Value = 
  SUM(fact_returns[Abs_Refund_Amount])
  ```
- **Description:** Total monetary value of customer refunds, credit notes, and cancelled orders.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £1,462,050.61

### 5.2 Return Invoice Count
- **DAX Formula:**
  ```dax
  Return Invoice Count = 
  DISTINCTCOUNT(fact_returns[Invoice])
  ```
- **Description:** Number of unique cancellation / credit note invoices (prefix 'C').
- **Format:** Whole Number (`#,##0`)
- **Benchmark Value:** 8,247 distinct return invoices

### 5.3 Refund-to-Gross-Revenue % (Return Rate)
- **DAX Formula:**
  ```dax
  Refund-to-Gross-Revenue % = 
  DIVIDE([Total Refund Value], [Total Revenue], 0)
  ```
- **Description:** Commercial return rate expressing gross refund value as a percentage of gross sales.
- **Format:** Percentage (`0.00%`)
- **Benchmark Value:** 7.14%

### 5.4 Net Sales Revenue
- **DAX Formula:**
  ```dax
  Net Sales Revenue = 
  [Total Revenue] - [Total Refund Value]
  ```
- **Description:** True realized commercial revenue after deducting customer returns.
- **Format:** Currency (`£#,##0.00`)
- **Benchmark Value:** £19,014,209.84

