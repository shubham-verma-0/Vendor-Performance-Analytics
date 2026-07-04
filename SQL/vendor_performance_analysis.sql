/*===========================================================
Vendor Performance Analysis
Author : Shubham Verma
Database : inventory
Description :
This project analyzes vendor purchasing, sales,
profitability, inventory turnover and freight costs
using SQL, Python and Power BI.
===========================================================*/

USE inventory;

-- ==========================================================
-- 1. Total Purchase by Vendor
-- ==========================================================

SELECT
    VendorNumber,
    SUM(PurchaseDollars) AS TotalPurchaseDollars,
    SUM(Quantity) AS TotalPurchaseQuantity
FROM purchases
GROUP BY VendorNumber;


-- ==========================================================
-- 2. Total Sales by Vendor
-- ==========================================================

SELECT
    VendorNo,
    SUM(SalesDollars) AS TotalSalesDollars,
    SUM(SalesQuantity) AS TotalSalesQuantity
FROM sales
GROUP BY VendorNo;


-- ==========================================================
-- 3. Freight Cost by Vendor
-- ==========================================================

SELECT
    VendorNumber,
    SUM(Freight) AS FreightCost
FROM vendor_invoice
GROUP BY VendorNumber;


-- ==========================================================
-- 4. Ending Inventory
-- ==========================================================

SELECT
    VendorNo,
    SUM(OnHand) AS EndingInventory
FROM end_inventory
GROUP BY VendorNo;


-- ==========================================================
-- 5. Beginning Inventory
-- ==========================================================

SELECT
    VendorNo,
    SUM(OnHand) AS BeginningInventory
FROM begin_inventory
GROUP BY VendorNo;


-- ==========================================================
-- 6. Create Vendor Sales Summary Table
-- ==========================================================

DROP TABLE IF EXISTS vendor_sales_summary;

CREATE TABLE vendor_sales_summary AS

WITH PurchaseSummary AS
(
SELECT
VendorNumber,
VendorName,
Brand,
Description,
SUM(PurchasePrice) PurchasePrice,
SUM(PurchaseDollars) TotalPurchaseDollars,
SUM(Quantity) TotalPurchaseQuantity
FROM purchases
GROUP BY VendorNumber,VendorName,Brand,Description
),

SalesSummary AS
(
SELECT
VendorNo,
Brand,
SUM(SalesPrice) ActualPrice,
SUM(SalesDollars) TotalSalesDollars,
SUM(SalesQuantity) TotalSalesQuantity,
SUM(ExciseTax) TotalExciseTax
FROM sales
GROUP BY VendorNo,Brand
),

FreightSummary AS
(
SELECT
VendorNumber,
SUM(Freight) FreightCost
FROM vendor_invoice
GROUP BY VendorNumber
)

SELECT

p.VendorNumber,
p.VendorName,
p.Brand,
p.Description,

p.PurchasePrice,
s.ActualPrice,

p.TotalPurchaseDollars,
s.TotalSalesDollars,

p.TotalPurchaseQuantity,
s.TotalSalesQuantity,

f.FreightCost,

(s.TotalSalesDollars-p.TotalPurchaseDollars-f.FreightCost)
AS GrossProfit,

ROUND(
((s.TotalSalesDollars-p.TotalPurchaseDollars-f.FreightCost)
/s.TotalSalesDollars)*100,2)
AS ProfitMargin,

ROUND(
s.TotalSalesQuantity/
p.TotalPurchaseQuantity,2)
AS StockTurnover

FROM PurchaseSummary p

LEFT JOIN SalesSummary s
ON p.VendorNumber=s.VendorNo
AND p.Brand=s.Brand

LEFT JOIN FreightSummary f
ON p.VendorNumber=f.VendorNumber;


-- ==========================================================
-- 7. View Vendor Sales Summary
-- ==========================================================

SELECT *
FROM vendor_sales_summary;


-- ==========================================================
-- 8. Clean Dataset (Remove Invalid Records)
-- ==========================================================

SELECT *
FROM vendor_sales_summary
WHERE GrossProfit>0
AND ProfitMargin>0
AND TotalSalesQuantity>0;


-- ==========================================================
-- 9. Top 10 Vendors by Sales
-- ==========================================================

SELECT
VendorName,
TotalSalesDollars
FROM vendor_sales_summary
ORDER BY TotalSalesDollars DESC
LIMIT 10;


-- ==========================================================
-- 10. Top 10 Brands by Sales
-- ==========================================================

SELECT
Description,
SUM(TotalSalesDollars) TotalSales
FROM vendor_sales_summary
GROUP BY Description
ORDER BY TotalSales DESC
LIMIT 10;


-- ==========================================================
-- 11. Low Performing Vendors
-- ==========================================================

SELECT
VendorName,
StockTurnover
FROM vendor_sales_summary
WHERE StockTurnover<1
ORDER BY StockTurnover;


-- ==========================================================
-- 12. Brand Performance Analysis
-- ==========================================================

SELECT
Description,
SUM(TotalSalesDollars) TotalSales,
AVG(ProfitMargin) AvgProfitMargin
FROM vendor_sales_summary
GROUP BY Description;


-- ==========================================================
-- 13. Vendor Wise Profitability
-- ==========================================================

SELECT
VendorName,
SUM(GrossProfit) AS GrossProfit,
AVG(ProfitMargin) AS AvgProfitMargin
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY GrossProfit DESC;


-- ==========================================================
-- 14. Top Vendors by Profit Margin
-- ==========================================================

SELECT
VendorName,
AVG(ProfitMargin) AS AvgProfitMargin
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY AvgProfitMargin DESC
LIMIT 10;


-- ==========================================================
-- 15. Vendor Wise Stock Turnover
-- ==========================================================

SELECT
VendorName,
AVG(StockTurnover) AS AvgStockTurnover
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY AvgStockTurnover DESC;


-- ==========================================================
-- 16. Overall Business KPI
-- ==========================================================
SELECT
SUM(TotalSalesDollars) TotalSales,
SUM(TotalPurchaseDollars) TotalPurchase,
SUM(GrossProfit) GrossProfit,
AVG(ProfitMargin) AvgProfitMargin,
SUM(TotalPurchaseDollars),
SUM(TotalSalesDollars)
AS UnsoldCapital
FROM vendor_sales_summary;

-- ==========================================================
-- 17. Top Vendors by Gross Profit
-- ==========================================================

SELECT
    VendorName,
    SUM(GrossProfit) AS GrossProfit
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY GrossProfit DESC
LIMIT 10;

-- ==========================================================
-- 18. Bottom Vendors by Gross Profit
-- ==========================================================

SELECT
    VendorName,
    SUM(GrossProfit) AS GrossProfit
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY GrossProfit
LIMIT 10;

-- ==========================================================
-- 19. Vendor Sales Contribution
-- ==========================================================

SELECT
VendorName,
ROUND(
SUM(TotalSalesDollars)*100.0/
(
SELECT SUM(TotalSalesDollars)
FROM vendor_sales_summary
),2
) AS SalesContribution
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY SalesContribution DESC;


-- ==========================================================
-- 20. Highest Freight Cost Vendors
-- ==========================================================

SELECT
VendorName,
SUM(FreightCost) FreightCost
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY FreightCost DESC
LIMIT 10;

-- ==========================================================
-- 21. Vendor Efficiency
-- ==========================================================

SELECT
VendorName,
ROUND(
SUM(TotalSalesDollars)/
SUM(TotalPurchaseDollars),2
)
AS SalesPurchaseRatio
FROM vendor_sales_summary
GROUP BY VendorName
ORDER BY SalesPurchaseRatio DESC;

-- ==========================================================
-- 22. Premium Products
-- ==========================================================

SELECT
Description,
ActualPrice
FROM vendor_sales_summary
ORDER BY ActualPrice DESC
LIMIT 20;

-- ==========================================================
-- 23. Slow Moving Products
-- ==========================================================

SELECT
Description,
StockTurnover
FROM vendor_sales_summary
WHERE StockTurnover<1
ORDER BY StockTurnover;

-- ==========================================================
-- 24. High Profit Margin Products
-- ==========================================================

SELECT
Description,
ProfitMargin
FROM vendor_sales_summary
ORDER BY ProfitMargin DESC
LIMIT 20;

-- ==========================================================
-- 25. Loss Making Products
-- ==========================================================

SELECT *
FROM vendor_sales_summary
WHERE GrossProfit<0;

-- ==========================================================
-- 26. Vendor Ranking by Sales
-- ==========================================================

SELECT
VendorName,
SUM(TotalSalesDollars) AS TotalSales,
RANK() OVER(
ORDER BY SUM(TotalSalesDollars) DESC
)
AS VendorRank
FROM vendor_sales_summary
GROUP BY VendorName;

-- 27. Brand Ranking
SELECT
Description,
SUM(TotalSalesDollars),
DENSE_RANK() OVER(
ORDER BY SUM(TotalSalesDollars) DESC
)
AS BrandRank
FROM vendor_sales_summary
GROUP BY Description;

-- KPI'S
SELECT
SUM(TotalSalesDollars) AS TotalSales,
SUM(TotalPurchaseDollars) AS TotalPurchase,
SUM(GrossProfit) AS GrossProfit,
ROUND(AVG(ProfitMargin),2) AS AvgProfitMargin,
ROUND(AVG(StockTurnover),2) AS AvgStockTurnover,
SUM(FreightCost) AS TotalFreightCost
FROM vendor_sales_summary;