# 🚴 Delivery Distance & Efficiency Analysis
**ABC Incorporated — Distance vs. Travel Time Study**

![SQL](https://img.shields.io/badge/SQL-SQL%20Server-blue?logo=microsoftsqlserver&logoColor=white)
![Power BI](https://img.shields.io/badge/Visualization-Power%20BI%20%2F%20HTML%20Dashboard-yellow?logo=powerbi&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)
![Records](https://img.shields.io/badge/Records-16%2C842-lightgrey)
![Date Range](https://img.shields.io/badge/Period-Dec%202024%20–%20Jan%202025-lightgrey)

---

## 📑 Table of Contents
1. [Executive Summary](#-executive-summary)
2. [Problem Statement](#-problem-statement)
3. [Dataset Overview](#-dataset-overview)
4. [Project Workflow](#-project-workflow)
5. [Key Findings & Insights](#-key-findings--insights)
6. [Tools & Technologies](#-tools--technologies)

---

## 📌 Executive Summary

This project investigates whether **driving distance is a meaningful predictor of delivery efficiency** for ABC Incorporated's rider network. Using a raw operational dataset of **16,842 delivery orders** covering December 14, 2024 to January 3, 2025, SQL Server was used to engineer travel time metrics, decode status codes, and categorize orders — producing a clean, analysis-ready dataset that was then visualized in an interactive dashboard.

The analysis reveals a **strong positive correlation** between store-to-customer distance and delivery travel time: as distance grows from under 2 km to over 10 km, average travel time increases from **13.8 minutes to 48.7 minutes** — a 3.5× increase. Longer-distance orders also carry a **significantly higher late delivery rate** (43.7%) compared to short-distance orders (33.6%).

In contrast, the **rider-to-store leg shows a much weaker correlation** between distance and time, suggesting that factors like store preparation time and order queue delays — not riding distance — dominate that segment of the workflow.

These findings give ABC Incorporated a data-driven basis for improving delivery SLA accuracy, flagging high-risk orders, and refining rider dispatch logic.

---

## ❓ Problem Statement

ABC Incorporated wants to understand whether riding distance has a measurable impact on delivery efficiency. Specifically, the study examines two legs of the delivery journey:

**Leg 1 — Rider Location → Store**
> Is there a correlation between the riding distance from the rider's last known location to the store and the time it takes the rider to reach the store?

**Leg 2 — Store → Customer Location**
> Is there a correlation between the riding distance from the store to the customer's pinned location and the total travel time to complete the delivery?

Answering these questions supports the business in:
- Setting more accurate delivery time estimates per distance tier
- Identifying which orders are statistically most likely to arrive late
- Making smarter rider assignment decisions based on proximity and workload

---

## 📂 Dataset Overview

### Raw Source File
**File:** `SL_vs_Distance.csv`
**Total Records:** 16,842 rows

### Raw Columns (Original Schema)

| Column | Data Type | Description |
|---|---|---|
| `order_id` | INT | Unique identifier for each delivery order |
| `order_status` | INT | Order outcome code: `20` = Completed, `30` = Cancelled, `70` = Other |
| `distance_to_customer` | FLOAT | Distance in km from the store to the customer's pinned location |
| `distance_rider_from_store` | FLOAT | Distance in km from the rider's last location to the store |
| `delivery_service_level` | INT | Delivery punctuality code: `1` = Early, `2` = On Time, `3` = Late, `NULL` = Unknown |
| `rider_arrived_at_pickup_time` | DATETIME | Timestamp when the rider arrived at the store |
| `order_ready_for_pickup_time` | DATETIME | Timestamp when the order was ready for the rider to collect |
| `order_pickup_done_time` | DATETIME | Timestamp when the rider completed store pickup and began the delivery leg |
| `order_delivered_time` | DATETIME | Timestamp when the order was delivered to the customer |

### Raw Data Characteristics

| Metric | Value |
|---|---|
| Total records | 16,842 |
| Completed orders (status 20) | 14,261 (84.7%) |
| Cancelled orders (status 30) | 2,578 (15.3%) |
| Other status (code 70) | 3 (excluded from analysis) |
| Records missing timestamp data | ~2,638–2,982 (cancelled orders have no timestamps) |
| `distance_to_customer` range | 0.06 km – 28.77 km (avg: 5.02 km) |
| `distance_rider_from_store` range | 0.03 km – 19.00 km (avg: 2.98 km) |
| Date range | Dec 14, 2024 – Jan 3, 2025 |

### Transformed Output Columns

After SQL processing, the exported dataset contains the following fields used in the dashboard:

| Column | Description |
|---|---|
| `order_id` | Unique order identifier |
| `Distance_Rider_from_Store` | Distance (km), cast to 2 decimal places |
| `travel_time_to_store` | Engineered: minutes from `rider_arrived_at_pickup_time` to `order_pickup_done_time` |
| `Distance_to_Customer` | Distance (km), cast to 2 decimal places |
| `travel_time_to_customer` | Engineered: minutes from `order_pickup_done_time` to `order_delivered_time` |
| `order_status` | Human-readable: `Completed` or `Cancelled` |
| `delivery_status` | Human-readable: `Early`, `On Time`, `Late`, or `Unknown` |
| `distance_category` | Derived: `Long Distance` (>5 km) or `Short Distance` (≤5 km) |
| `Date` | Formatted delivery date (`yyyy/MM/dd`) |

---

## 🔧 Project Workflow

### Step 1 — Database Setup
Created a SQL Server database to store and manage the raw delivery data. The source CSV file was imported into a table named `SL_vs_Distance` using SQL Server's import wizard.

---

### Step 2 — Feature Engineering: Calculate Travel Times

Two new integer columns were added to the table to capture the travel time in minutes for each leg of the delivery.

```sql
ALTER TABLE SL_vs_Distance
ADD travel_time_to_store      INT,
    travel_time_to_customer   INT;
```

Travel times were computed using `DATEDIFF(MINUTE, ...)` against the existing timestamp columns:

- **Rider → Store:** Time between `rider_arrived_at_pickup_time` and `order_pickup_done_time`
- **Store → Customer:** Time between `order_pickup_done_time` and `order_delivered_time`

```sql
UPDATE SL_vs_Distance
SET travel_time_to_store     = DATEDIFF(MINUTE, rider_arrived_at_pickup_time, order_pickup_done_time),
    travel_time_to_customer  = DATEDIFF(MINUTE, order_pickup_done_time, order_delivered_time);
```

Cancelled orders (status code `30`) have no timestamp data, so their travel time values were explicitly set to zero to avoid NULL propagation errors downstream:

```sql
UPDATE SL_vs_Distance
SET travel_time_to_store    = 0,
    travel_time_to_customer = 0
WHERE order_status = 30;
```

---

### Step 3 — Data Transformation & Export

A final `SELECT` query was written to clean, decode, and categorize the data for dashboard consumption. This query was the source for the exported CSV used in Power BI.

```sql
SELECT 
    order_id,
    CAST(distance_rider_from_store AS DECIMAL(18,2))  AS Distance_Rider_from_Store,
    travel_time_to_store,
    CAST(distance_to_customer AS DECIMAL(18,2))       AS Distance_to_Customer,
    travel_time_to_customer,

    -- Decode order status codes to readable labels
    CASE 
        WHEN order_status = 20 THEN 'Completed'
        ELSE 'Cancelled'
    END AS order_status,

    -- Decode delivery punctuality codes to readable labels
    CASE delivery_service_level 
        WHEN 1 THEN 'Early'
        WHEN 2 THEN 'On Time'
        WHEN 3 THEN 'Late'
        ELSE 'Unknown'
    END AS delivery_status,

    -- Classify orders by customer distance threshold
    CASE 
        WHEN distance_to_customer > 5 THEN 'Long Distance'
        ELSE 'Short Distance'
    END AS distance_category,

    FORMAT(order_pickup_done_time, 'yyyy/MM/dd') AS Delivery_Date

FROM SL_vs_Distance
WHERE order_status = 20 OR order_status = 30;
```

**Key transformation decisions:**

| Decision | Rationale |
|---|---|
| `CAST(... AS DECIMAL(18,2))` | Standardizes floating-point precision for consistent display in Power BI |
| `DATEDIFF(MINUTE, ...)` | Converts raw timestamps into a single numeric metric suitable for correlation analysis |
| `order_status = 70` excluded via `WHERE` clause | Only 3 records with this code exist; excluding them keeps analysis focused on the two primary order outcomes |
| Distance threshold set at 5 km | Used to create a meaningful binary category for comparing short vs. long-distance delivery performance |
| `FORMAT(..., 'yyyy/MM/dd')` | Ensures date field is Power BI-compatible and renders cleanly as a slicer |

---

### Step 4 — Dashboard Development

The transformed CSV was loaded into an interactive HTML/JavaScript dashboard (Power BI-style) built with Chart.js, containing four report pages:

| Page | Contents |
|---|---|
| **Overview** | 8 KPI cards, order/delivery/distance donut charts, performance by distance category, avg travel time by distance bucket |
| **Correlation Analysis** | Scatter plots for both delivery legs, filterable by distance category, side-by-side bucket comparison bar chart |
| **Daily Trends** | Stacked/line toggle chart of daily volumes, on-time vs. late rate trend line, top 5 peak days |
| **Summary Table** | Full date-by-date breakdown with color-coded performance rates and distance category comparison table |

---

## 📊 Key Findings & Insights

### Finding 1 — Strong Positive Correlation: Store → Customer Distance vs. Travel Time

Average travel time to the customer increases consistently and significantly as delivery distance grows:

| Distance Bucket | Avg Travel Time | Orders |
|---|---|---|
| 0 – 2 km | 13.8 min | 1,880 |
| 2 – 4 km | 20.8 min | 4,023 |
| 4 – 6 km | 27.9 min | 3,650 |
| 6 – 8 km | 35.0 min | 2,104 |
| 8 – 10 km | 39.1 min | 1,158 |
| 10 – 15 km | 48.7 min | 800 |

> ✅ **Conclusion:** Distance is a **strong and reliable predictor** of customer-facing travel time (approximate r ≈ 0.96 across buckets). Travel time increases 3.5× from the shortest to the longest distance tier. ABC Inc. can confidently use distance as an input for delivery time estimation on this leg.

---

### Finding 2 — Weak Correlation: Rider → Store Distance vs. Travel Time

Travel time to the store increases only marginally with distance:

| Distance Bucket | Avg Travel Time | Orders |
|---|---|---|
| 0 – 2 km | 27.6 min | 1,634 |
| 2 – 4 km | 28.2 min | 1,590 |
| 4 – 6 km | 30.9 min | 599 |
| 6 – 8 km | 34.2 min | 199 |
| 8 – 10 km | 38.9 min | 61 |

> ⚠️ **Conclusion:** The near-flat curve — especially from 0–4 km — indicates that **store preparation time and order queue wait times dominate this leg**, not riding distance. A large proportion of records also have `travel_time_to_store = 0`, suggesting many riders were already at or near the store when assigned. Distance alone is **not a reliable SLA predictor** for the rider-to-store segment.

---

### Finding 3 — Long Distance Orders Have Significantly Higher Late Rates

| Category | Orders | On Time | Late | Early | On-Time Rate | Late Rate |
|---|---|---|---|---|---|---|
| Short Distance (≤5 km) | 9,558 | 4,832 | 2,728 | 617 | 59.5% | 33.6% |
| Long Distance (>5 km) | 7,281 | 3,071 | 2,661 | 280 | 50.4% | 43.7% |

> ✅ **Conclusion:** Long-distance orders are **10.1 percentage points more likely to be late** than short-distance orders. They also produce fewer early deliveries (3.8% vs. 7.6%), reinforcing that greater distance creates more variability and risk in meeting delivery SLAs.

---

### Finding 4 — Peak Volume Drives Higher Late Counts

The five highest-volume days all showed elevated late delivery counts:

| Date | Total Orders | Late | On Time | Late Rate |
|---|---|---|---|---|
| Dec 23, 2024 | 1,132 | 451 | 434 | 48.8% |
| Dec 30, 2024 | 934 | 315 | 440 | 41.7% |
| Dec 17, 2024 | 855 | 380 | 431 | 46.9% |
| Dec 18, 2024 | 836 | 295 | 449 | 39.6% |
| Dec 19, 2024 | 872 | 299 | 394 | 43.1% |

> ⚠️ **Conclusion:** December 23rd was the single worst day for late deliveries — likely due to Christmas-period demand surge. High volume days consistently correlate with higher late rates, suggesting **rider capacity constraints amplify the distance-driven lateness effect** during peak periods.

---

### Summary of Answers to the Problem Statement

| Question | Answer |
|---|---|
| Does rider-to-store distance correlate with travel time to store? | **Weakly** — store wait/prep time dominates; distance alone is not a reliable predictor |
| Does store-to-customer distance correlate with travel time to customer? | **Strongly** — near-linear relationship confirmed; distance is a reliable predictor for this leg |

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|---|---|
| **SQL Server (T-SQL)** | Database creation, data import, feature engineering (`ALTER TABLE`, `UPDATE`, `DATEDIFF`), data transformation and export (`SELECT`, `CASE`, `FORMAT`, `CAST`) |
| **SQL Server Management Studio (SSMS)** | Query development, table inspection, CSV import via Import Wizard |
| **HTML / CSS / JavaScript** | Interactive dashboard layout, responsive design, tab navigation, filter controls |
| **Chart.js** | Donut charts, bar charts, scatter plots, line charts — all rendered client-side |
| **Google Fonts** | Syne (headings) and DM Sans (body) for dashboard typography |
| **CSV (Excel-compatible)** | Intermediate data format between SQL export and dashboard ingestion |

---

## 📁 Repository Structure

```
├── README.md                        ← This file
├── data/
│   ├── SL_vs_Distance.csv           ← Raw source dataset (original schema)
│   └── PowerBI-Data-Set.csv         ← Cleaned & transformed output from SQL
├── sql/
│   └── delivery_analysis.sql        ← Full SQL script (ALTER, UPDATE, SELECT)
└── dashboard/
    └── ABC_Delivery_Dashboard.html  ← Interactive HTML dashboard
```


---

*Data is property of ABC Incorporated and was provided for academic analysis purposes only.*
