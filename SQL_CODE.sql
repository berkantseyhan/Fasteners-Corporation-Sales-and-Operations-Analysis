--Sales and Performance Analysis for Fasteners Corporation 
--Wind = Represent company name
--1a. What were Wind's top selling products?

SELECT TOP (3) p.ProductName, SUM(os.Subtotal) AS TotalSales, SUM(od.Quantity) AS TotalQuantity
FROM     Wind.dbo.Orders AS o INNER JOIN
                  Wind.dbo.OrderDetailsExtended AS od ON o.OrderID = od.OrderID INNER JOIN
                  Wind.dbo.OrderSubtotals AS os ON o.OrderID = os.OrderID INNER JOIN
                  Wind.dbo.Products AS p ON od.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY TotalQuantity DESC;

--1b. What products make the most profit?

SELECT TOP (3) p.ProductName, SUM(os.Subtotal) AS TotalProfit, SUM(od.Quantity) AS TotalQuantity
FROM     Wind.dbo.Orders AS o INNER JOIN
                  Wind.dbo.OrderDetailsExtended AS od ON o.OrderID = od.OrderID INNER JOIN
                  Wind.dbo.OrderSubtotals AS os ON o.OrderID = os.OrderID INNER JOIN
                  Wind.dbo.Products AS p ON od.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY TotalProfit DESC;

--2. Who are the top customers in terms of sales?

SELECT TOP (3) c.FirstName, c.LastName, p.ProductName, Sales
FROM     (SELECT c.FirstName, c.LastName, p.ProductName, SUM((od.UnitPrice * od.Quantity) * (1 - od.Discount)) AS Sales
                  FROM      Wind.dbo.Orders AS o INNER JOIN
                                    Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID INNER JOIN
                                    Wind.dbo.Products AS p ON p.ProductID = od.ProductID INNER JOIN
                                    Wind.dbo.Customers AS c ON c.CustomerID = o.CustomerID
                  GROUP BY c.FirstName, c.LastName, p.ProductName) AS a
ORDER BY Sales DESC;

--3a. How many orders were shipped on time?

SELECT COUNT(*) AS [Shipped on Time]
FROM     Wind.dbo.Orders
WHERE  (RequiredDate = ShippedDate);

--3b. Late shipments and how late they were:

SELECT TOP 3 RequiredDate, ShippedDate, DATEDIFF(day, RequiredDate, ShippedDate) AS DaysLate, 
		CASE 
			WHEN DATEDIFF(day, RequiredDate, ShippedDate) > 0 THEN 'Late' 
			ELSE 'On Time' 
		END AS Status
FROM     Wind.dbo.Orders
ORDER BY DaysLate DESC;

--4. Top performing shipping company

SELECT COUNT(o.OrderID) AS [Total Orders], s.CompanyName
FROM     Wind.dbo.Orders AS o INNER JOIN
                  Wind.dbo.Shippers AS s ON o.ShipperID = s.ShipperID
GROUP BY s.CompanyName
ORDER BY [Total Orders] DESC;

--5. Total sales by product category

CREATE VIEW [CategorySales] AS
SELECT p.ProductName, MAX(p.CategoryID) AS Category, SUM(od.Quantity) AS TotalSales, 
       ROW_NUMBER() OVER (PARTITION BY MAX(p.CategoryID) ORDER BY SUM(od.Quantity) DESC) AS RankWithinCategory
FROM Wind.dbo.Products AS p INNER JOIN 
     Wind.dbo.OrderDetails AS od ON p.ProductID = od.ProductID INNER JOIN 
     Wind.dbo.Orders AS o ON o.OrderID = od.OrderID 
GROUP BY p.ProductName, p.CategoryID;

GO

SELECT DISTINCT Category, MAX(TotalSales) AS [Max Sales], ProductName
FROM     [CategorySales]
GROUP BY Category, ProductName
ORDER BY Category, [Max Sales] DESC;

-- DROP VIEW [CategorySales]


--6. Employee sales performance (Yearly and Quarterly)
SELECT CONCAT(e.FirstName, ' ', e.LastName) AS [Employee Name],
       [YearRank], [QuarterRank], 
       SUM(od.Quantity) AS TotalQuantitySold
FROM Wind.dbo.Employees AS e INNER JOIN
     Wind.dbo.Orders AS o ON e.EmployeeID = o.EmployeeID INNER JOIN
     Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID INNER JOIN
    (SELECT *,
            DENSE_RANK() OVER (ORDER BY YEAR(OrderDate)) AS [YearRank],
            DENSE_RANK() OVER (ORDER BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate)) AS [QuarterRank]
     FROM Wind.dbo.Orders) AS rankedOrders ON o.OrderID = rankedOrders.OrderID
GROUP BY e.FirstName, e.LastName, [YearRank], [QuarterRank]
ORDER BY [YearRank], [QuarterRank], TotalQuantitySold DESC;


--7. Order status based on stock availability
SELECT o.OrderID, o.CustomerID, SUM(od.Subtotal) AS TotalValue, SUM(od.Quantity) AS TotalQuantity,
       CASE
           WHEN COUNT(CASE WHEN od.Quantity > p.UnitsInStock OR p.Discontinued = 1 THEN 1 END) > 0 THEN 'Out of Stock'
           ELSE 'In Stock'
       END AS StockStatus
FROM   Wind.dbo.Orders AS o LEFT JOIN
       Wind.dbo.OrderDetailsExtended AS od ON o.OrderID = od.OrderID LEFT JOIN
       Wind.dbo.Products AS p ON od.ProductID = p.ProductID
GROUP BY o.OrderID, o.CustomerID;


-- Analyzing average delivery times for different shipping companies
SELECT s.CompanyName, 
       AVG(DATEDIFF(day, o.OrderDate, o.ShippedDate)) AS AvgDeliveryTime
FROM Wind.dbo.Orders AS o 
INNER JOIN Wind.dbo.Shippers AS s ON o.ShipperID = s.ShipperID
GROUP BY s.CompanyName
ORDER BY AvgDeliveryTime;


-- Analyzing seasonal trends in product sales
SELECT DATEPART(MONTH, o.OrderDate) AS [Month], 
       p.ProductName, 
       SUM(od.Quantity) AS TotalQuantitySold
FROM Wind.dbo.Orders AS o 
INNER JOIN Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID
INNER JOIN Wind.dbo.Products AS p ON od.ProductID = p.ProductID
GROUP BY DATEPART(MONTH, o.OrderDate), p.ProductName
ORDER BY [Month], TotalQuantitySold DESC;


-- Identifying top customers by repeat orders
SELECT c.CustomerID, c.FirstName, c.LastName, 
       COUNT(o.OrderID) AS TotalOrders, 
       SUM(od.Quantity) AS TotalQuantityPurchased
FROM Wind.dbo.Customers AS c 
INNER JOIN Wind.dbo.Orders AS o ON c.CustomerID = o.CustomerID
INNER JOIN Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING COUNT(o.OrderID) > 1
ORDER BY TotalOrders DESC, TotalQuantityPurchased DESC;


-- Analyzing stock turnover for different products
SELECT p.ProductName, 
       SUM(od.Quantity) AS TotalUnitsSold, 
       p.UnitsInStock, 
       CASE 
           WHEN p.UnitsInStock > 0 THEN CAST(SUM(od.Quantity) AS FLOAT) / p.UnitsInStock 
           ELSE 0 
       END AS StockTurnoverRate
FROM Wind.dbo.Products AS p 
INNER JOIN Wind.dbo.OrderDetails AS od ON p.ProductID = od.ProductID
GROUP BY p.ProductName, p.UnitsInStock
ORDER BY StockTurnoverRate DESC;


-- Analyzing how discounts impact the total sales volume
SELECT od.Discount, 
       COUNT(od.OrderID) AS TotalOrders, 
       SUM(od.Quantity) AS TotalQuantitySold, 
       SUM((od.UnitPrice * od.Quantity) * (1 - od.Discount)) AS TotalSales
FROM Wind.dbo.OrderDetails AS od 
GROUP BY od.Discount
ORDER BY od.Discount DESC;


-- Identifying peak hours for order placements
SELECT DATEPART(HOUR, o.OrderDate) AS OrderHour, 
       COUNT(o.OrderID) AS TotalOrders, 
       SUM(od.Quantity) AS TotalItemsSold
FROM Wind.dbo.Orders AS o 
INNER JOIN Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID
GROUP BY DATEPART(HOUR, o.OrderDate)
ORDER BY TotalOrders DESC;


-- Analyzing revenue growth by year
SELECT YEAR(o.OrderDate) AS [Year], 
       SUM((od.UnitPrice * od.Quantity) * (1 - od.Discount)) AS TotalRevenue
FROM Wind.dbo.Orders AS o 
INNER JOIN Wind.dbo.OrderDetails AS od ON o.OrderID = od.OrderID
GROUP BY YEAR(o.OrderDate)
ORDER BY [Year];


-- Identifying products that go out of stock often
SELECT p.ProductName, 
       COUNT(CASE WHEN od.Quantity > p.UnitsInStock THEN 1 END) AS TimesOutOfStock
FROM Wind.dbo.Products AS p 
INNER JOIN Wind.dbo.OrderDetails AS od ON p.ProductID = od.ProductID
GROUP BY p.ProductName
HAVING COUNT(CASE WHEN od.Quantity > p.UnitsInStock THEN 1 END) > 0
ORDER BY TimesOutOfStock DESC;


