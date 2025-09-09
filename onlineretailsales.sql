


CREATE TABLE Customers (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  FirstName NVARCHAR(100) NOT NULL,
  LastName NVARCHAR(100) NOT NULL,
  Email NVARCHAR(255) NOT NULL UNIQUE,
  Phone NVARCHAR(30),
  CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Addresses (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  CustomerId INT NOT NULL FOREIGN KEY REFERENCES Customers(Id) ON DELETE CASCADE,
  Line1 NVARCHAR(200) NOT NULL,
  Line2 NVARCHAR(200),
  City NVARCHAR(100) NOT NULL,
  State NVARCHAR(100),
  PostalCode NVARCHAR(20) NOT NULL,
  Country NVARCHAR(100) NOT NULL,
  IsDefault BIT DEFAULT 0,
  CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Categories (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  Name NVARCHAR(120) NOT NULL UNIQUE,
  ParentId INT NULL FOREIGN KEY REFERENCES Categories(Id) 
);

CREATE TABLE Products (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  Sku NVARCHAR(64) NOT NULL UNIQUE,
  Name NVARCHAR(200) NOT NULL,
  Description NVARCHAR(MAX),
  CategoryId INT NULL FOREIGN KEY REFERENCES Categories(Id) ON DELETE SET NULL,
  PriceCents INT NOT NULL CHECK (PriceCents >= 0),
  Currency CHAR(3) NOT NULL DEFAULT 'USD',
  Active BIT DEFAULT 1,
  CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Inventory (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  ProductId INT NOT NULL UNIQUE FOREIGN KEY REFERENCES Products(Id) ON DELETE CASCADE,
  QuantityOnHand INT NOT NULL DEFAULT 0 CHECK (QuantityOnHand >= 0),
  SafetyStock INT NOT NULL DEFAULT 0 CHECK (SafetyStock >= 0),
  UpdatedAt DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Orders (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  CustomerId INT NOT NULL FOREIGN KEY REFERENCES Customers(Id),
  OrderNumber NVARCHAR(30) NOT NULL UNIQUE,
  Status NVARCHAR(20) NOT NULL CHECK (Status IN ('pending','paid','shipped','delivered','cancelled','refunded')),
  SubtotalCents INT NOT NULL CHECK (SubtotalCents >= 0),
  TaxCents INT NOT NULL DEFAULT 0 CHECK (TaxCents >= 0),
  ShippingCents INT NOT NULL DEFAULT 0 CHECK (ShippingCents >= 0),
  DiscountCents INT NOT NULL DEFAULT 0 CHECK (DiscountCents >= 0),
  TotalCents INT NOT NULL CHECK (TotalCents >= 0),
  BillingAddressId INT NULL FOREIGN KEY REFERENCES Addresses(Id) ON DELETE SET NULL,
  ShippingAddressId INT NULL FOREIGN KEY REFERENCES Addresses(Id) ,
  CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE OrderItems (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  OrderId INT NOT NULL FOREIGN KEY REFERENCES Orders(Id) ON DELETE CASCADE,
  ProductId INT NOT NULL FOREIGN KEY REFERENCES Products(Id),
  Quantity INT NOT NULL CHECK (Quantity > 0),
  UnitPriceCents INT NOT NULL CHECK (UnitPriceCents >= 0),
  DiscountCents INT NOT NULL DEFAULT 0 CHECK (DiscountCents >= 0),
  LineTotalCents INT NOT NULL CHECK (LineTotalCents >= 0)
);

CREATE TABLE Payments (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  OrderId INT NOT NULL FOREIGN KEY REFERENCES Orders(Id) ON DELETE CASCADE,
  AmountCents INT NOT NULL CHECK (AmountCents >= 0),
  Currency CHAR(3) NOT NULL DEFAULT 'USD',
  Method NVARCHAR(30) NOT NULL,
  Status NVARCHAR(20) NOT NULL CHECK (Status IN ('authorized','captured','failed','refunded')),
  TransactionRef NVARCHAR(100),
  PaidAt DATETIME2,
  CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);


INSERT INTO Customers (FirstName, LastName, Email, Phone)
VALUES
('Aisha','Khan','aisha.khan@example.com','+91-9000000001'),
('Rohit','Sharma','rohit.sharma@example.com','+91-9000000002');

INSERT INTO Categories (Name) VALUES ('Electronics'), ('Accessories');

INSERT INTO Products (Sku, Name, Description, CategoryId, PriceCents, Currency)
VALUES
('ELEC-1001','Wireless Headphones','BT5.0, ANC', 1, 599900, 'INR'),
('ELEC-1002','USB-C Charger 45W','Fast charging', 2, 199900, 'INR');

INSERT INTO Inventory (ProductId, QuantityOnHand, SafetyStock)
VALUES (1, 50, 5), (2, 80, 10);

INSERT INTO Orders (CustomerId, OrderNumber, Status, SubtotalCents, TaxCents, ShippingCents, DiscountCents, TotalCents)
VALUES (1, 'ORD-2025-0001', 'paid', 799800, 0, 0, 0, 799800);

INSERT INTO OrderItems (OrderId, ProductId, Quantity, UnitPriceCents, DiscountCents, LineTotalCents)
VALUES
(1, 1, 1, 599900, 0, 599900),
(1, 2, 1, 199900, 0, 199900);

INSERT INTO Payments (OrderId, AmountCents, Currency, Method, Status, TransactionRef, PaidAt)
VALUES (1, 799800, 'INR', 'UPI', 'captured', 'TXN-ABC-001', SYSDATETIME());

--Expanded Order Items View -this helps to find order details
CREATE VIEW vw_order_items_expanded AS
SELECT
  oi.Id AS OrderItemId,
  o.OrderNumber,
  o.CreatedAt AS OrderDate,
  c.Id AS CustomerId,
  c.FirstName + ' ' + c.LastName AS CustomerName,
  p.Sku,
  p.Name AS ProductName,
  oi.Quantity,
  oi.UnitPriceCents,
  oi.DiscountCents,
  oi.LineTotalCents
FROM OrderItems oi
JOIN Orders o ON o.Id = oi.OrderId
JOIN Customers c ON c.Id = o.CustomerId
JOIN Products p ON p.Id = oi.ProductId;



--Top Products by Revenue-it Helps management see which products bring the most income.
SELECT TOP 10 Sku, ProductName, SUM(LineTotalCents) AS RevenueCents
FROM vw_order_items_expanded
GROUP BY Sku, ProductName
ORDER BY RevenueCents DESC;



--Monthly Sales Summary-Useful for monthly sales reports to see growth trends over time.
SELECT
  FORMAT(CreatedAt, 'yyyy-MM') AS Month,
  COUNT(*) AS OrdersCount,
  SUM(TotalCents) AS GrossRevenueCents,
  SUM(SubtotalCents) AS SubtotalCents,
  SUM(DiscountCents) AS DiscountsCents
FROM Orders
GROUP BY FORMAT(CreatedAt, 'yyyy-MM')
ORDER BY Month;

--Payments Breakdown by Method-Tells the company which payment options are most popular among customers.

SELECT Method, COUNT(*) AS Payments, SUM(AmountCents) AS AmountCents
FROM Payments
WHERE Status IN ('authorized','captured')
GROUP BY Method
ORDER BY AmountCents DESC;


--Customer Lifetime Value (LTV)--Shows who your most valuable customers are.
SELECT c.Id, (c.FirstName + ' ' + c.LastName) AS Customer,
       COUNT(o.Id) AS OrdersCount,
       COALESCE(SUM(o.TotalCents),0) AS LtvCents
FROM Customers c
LEFT JOIN Orders o ON o.CustomerId = c.Id AND o.Status NOT IN ('cancelled')
GROUP BY c.Id, (c.FirstName + ' ' + c.LastName)
ORDER BY LtvCents DESC;

--Inventory Below Safety Stock-Helps the store know which products need restocking soon.
SELECT p.Sku, p.Name, i.QuantityOnHand, i.SafetyStock
FROM Inventory i
JOIN Products p ON p.Id = i.ProductId
WHERE i.QuantityOnHand < i.SafetyStock
ORDER BY i.QuantityOnHand;



