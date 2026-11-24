/* =====================================================================
   Zoo Management System - SQL Server (T-SQL)
   ZooDB_Views.sql

   SUBMISSION_PLAN Phase 1 - section 2.1 (Views).

   HOW TO RUN (after ZooDB_FULL.sql, ZooDB_Functions_Procedures.sql,
   and ZooDB_Transactions.sql):
     SSMS > File > Open > File... > choose this file > click inside the
     text (select nothing) > F5.
   The script can be run again at any time (CREATE OR ALTER).

   Contents
     V1  dbo.vw_AnimalDirectory      Animal + species + enclosure + habitat
     V2  dbo.vw_FeedingToday         Feeding plan vs today's feeding log
     V3  dbo.vw_VaccinesDue          Latest vaccine dose due within 30 days
     V4  dbo.vw_FoodStockEstimate    Purchased - consumed per food type
     V5  dbo.vw_TicketSalesToday     Ticket sales purchased today

   "Today" filters use CAST(GETDATE() AS DATE) because views cannot take
   parameters. Status badges (Late / Done / Pending, Overdue / Due soon)
   stay in the desktop application.
   ===================================================================== */

USE ZooDB;
GO

/* =====================================================================
   V1  vw_AnimalDirectory
   Used by: Animals list screen (ui/screens/animals.py) — after app wiring
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_AnimalDirectory
AS
SELECT a.AnimalID,
       a.Name,
       s.CommonName AS Species,
       a.Gender,
       a.BirthDate,
       a.HealthStatus,
       e.Name AS Enclosure,
       h.Name AS Habitat
FROM dbo.ANIMAL a
JOIN dbo.SPECIES s ON a.SpeciesID = s.SpeciesID
LEFT JOIN dbo.ENCLOSURE e ON a.EnclosureID = e.EnclosureID
LEFT JOIN dbo.HABITAT h ON e.HabitatID = h.HabitatID;
GO

/* =====================================================================
   V2  vw_FeedingToday
   Used by: Feeding Today screen (ui/screens/feeding.py) — after app wiring
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_FeedingToday
AS
SELECT fp.PlanID,
       fp.FeedingTime,
       a.AnimalID,
       a.Name AS Animal,
       e.Name AS Enclosure,
       h.Name AS Habitat,
       ft.Name AS Food,
       fp.QuantityPerMeal,
       ft.Unit,
       fl.LogID,
       fl.FedAt,
       fl.QuantityGiven
FROM dbo.FEEDING_PLAN fp
JOIN dbo.ANIMAL a ON fp.AnimalID = a.AnimalID
JOIN dbo.FOOD_TYPE ft ON fp.FoodID = ft.FoodID
LEFT JOIN dbo.ENCLOSURE e ON a.EnclosureID = e.EnclosureID
LEFT JOIN dbo.HABITAT h ON e.HabitatID = h.HabitatID
LEFT JOIN dbo.FEEDING_LOG fl
       ON fl.PlanID = fp.PlanID
      AND CAST(fl.FedAt AS DATE) = CAST(GETDATE() AS DATE)
WHERE a.HealthStatus <> N'Deceased';
GO

/* =====================================================================
   V3  vw_VaccinesDue
   Used by: Veterinary Center vaccines queue (ui/screens/vet.py) — after app wiring
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_VaccinesDue
AS
SELECT a.AnimalID,
       a.Name AS Animal,
       v.VaccineName,
       v.DateGiven,
       v.NextDue
FROM dbo.VACCINATION v
JOIN dbo.ANIMAL a ON v.AnimalID = a.AnimalID
WHERE a.HealthStatus <> N'Deceased'
  AND v.NextDue <= DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.VACCINATION v2
        WHERE v2.AnimalID = v.AnimalID
          AND v2.VaccineName = v.VaccineName
          AND v2.DateGiven > v.DateGiven
      );
GO

/* =====================================================================
   V4  vw_FoodStockEstimate
   Used by: Food Inventory stock tab (ui/screens/inventory.py) — after app wiring
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_FoodStockEstimate
AS
SELECT ft.FoodID,
       ft.Name AS Food,
       ft.Category,
       ft.Unit,
       COALESCE(p.Purchased, 0) AS Purchased,
       COALESCE(c.Consumed, 0) AS Consumed,
       COALESCE(p.Purchased, 0) - COALESCE(c.Consumed, 0) AS EstimatedStock
FROM dbo.FOOD_TYPE ft
LEFT JOIN (
    SELECT FoodID, SUM(Quantity) AS Purchased
    FROM dbo.FOOD_STOCK
    GROUP BY FoodID
) p ON p.FoodID = ft.FoodID
LEFT JOIN (
    SELECT fp.FoodID, SUM(fl.QuantityGiven) AS Consumed
    FROM dbo.FEEDING_LOG fl
    JOIN dbo.FEEDING_PLAN fp ON fl.PlanID = fp.PlanID
    GROUP BY fp.FoodID
) c ON c.FoodID = ft.FoodID;
GO

/* =====================================================================
   V5  vw_TicketSalesToday
   Used by: Ticketing today's sales list (ui/screens/ticketing.py) — after app wiring
   ===================================================================== */
CREATE OR ALTER VIEW dbo.vw_TicketSalesToday
AS
SELECT t.TicketID,
       tt.Name AS TicketType,
       t.Quantity,
       t.TotalPrice,
       t.VisitDate,
       t.PurchasedAt,
       s.FirstName AS SoldBy
FROM dbo.TICKET t
JOIN dbo.TICKET_TYPE tt ON t.TicketTypeID = tt.TicketTypeID
LEFT JOIN dbo.STAFF s ON t.SoldByStaffID = s.StaffID
WHERE CAST(t.PurchasedAt AS DATE) = CAST(GETDATE() AS DATE);
GO

PRINT 'ZooDB: 5 views created.';
GO

-- Quick check: list the views that were created
SELECT name AS ObjectName, create_date, modify_date
FROM sys.views
WHERE name IN (
    'vw_AnimalDirectory',
    'vw_FeedingToday',
    'vw_VaccinesDue',
    'vw_FoodStockEstimate',
    'vw_TicketSalesToday'
)
ORDER BY name;
GO
