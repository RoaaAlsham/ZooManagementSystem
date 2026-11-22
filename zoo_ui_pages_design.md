# Zoo Management System: UI Pages, Components, and Database Mapping

This document proposes the **core user interface** for the 20-table Zoo Database: **10 screens** that cover daily work efficiently. Related actions that used to be separate pages are **merged into hubs** (dialogs, tabs, or admin lookups).

For every screen it gives the purpose, components, content, functions, **SQL** behind each function, and **justification**.

> Conventions
> - `:name` marks a **parameter** supplied by the UI (always use prepared statements / parameterized queries; never build SQL by string concatenation).
> - SQL is PostgreSQL-style. In MySQL use `CURDATE()`, `NOW()`, `CONCAT()`, `LIKE`; in SQL Server use `GETDATE()`, `DATEADD()`.
> - Query names Q1 to Q15 refer to the example queries in the schema documentation.

---

## Table of Contents

1. [Design Principles and Justification](#1-design-principles-and-justification)
2. [Core Screen Scope (10 Screens)](#2-core-screen-scope-10-screens)
3. [Navigation Map and Page List](#3-navigation-map-and-page-list)
4. [Roles and Access Matrix](#4-roles-and-access-matrix)
5. [Page Specifications](#5-page-specifications)
6. [Page-to-Table Matrix](#6-page-to-table-matrix)
7. [Cross-Cutting Rules (Transactions, Validation, Errors)](#7-cross-cutting-rules)
8. [Suggested Build Order](#8-suggested-build-order)

---

## 1. Design Principles and Justification

| Principle | What it means | Why |
|---|---|---|
| **Lean screen set** | Build **10 core screens**; merge secondary flows into hubs. | Faster to implement and demo while still covering all 20 tables. |
| **Task-oriented pages** | Pages follow daily jobs (feed animals, check vaccines, sell tickets), not database tables. | Keepers, vets, and cashiers think in tasks, not in tables. |
| **Animal-centric hub** | Animal Detail holds care, health, feeding plans, transfers, and edit. | ANIMAL is the central entity; most questions start with one animal. |
| **Role-based views** | Each role sees only what it needs. | Reduces mistakes, protects salary and staff data, speeds up daily work. |
| **History is never deleted** | Pages offer *end*, *deactivate*, or *mark deceased* instead of *delete*. | Schema uses RESTRICT on important FKs and keeps history tables. |
| **Safe writes** | Multi-table actions run in one transaction; the UI validates before sending. | Keeps data consistent (e.g. transfer + update animal together). |
| **Forms reflect constraints** | Dropdowns for CHECK lists, date pickers with min/max, required markers for NOT NULL. | Prevents most constraint violations before they reach the database. |

---

## 2. Core Screen Scope (10 Screens)

### Build target

| # | ID | Screen | Absorbs (no separate route) |
|---|---|---|---|
| 1 | **P01** | Login | — |
| 2 | **P03** | Animal List | Entry to add animal (former P05 wizard opens from here) |
| 3 | **P04** | Animal Detail (hub) | Edit animal, transfer dialog, feeding-plan edit, care assign/end (former P05 / P06 / P10 / P11) |
| 4 | **P07** | Habitats and Enclosures | — |
| 5 | **P09** | Feeding Today | Daily logging only; plan edits live on P04 |
| 6 | **P12** | Veterinary Center | Queue work; per-animal history also on P04 |
| 7 | **P13** | Food Inventory | Suppliers tab / delivery form (former P14) |
| 8 | **P15** | Staff Directory | Shifts tab on profile (former P16); keeper workload for care |
| 9 | **P17** | Ticketing | — |
| 10 | **P19** | Admin Settings | Species & conservation lookups (former P08); ticket types; zoo / departments |

### Deferred (stretch — not in the 10)

| Former ID | Feature | If built later |
|---|---|---|
| **P02** | Dashboard (alerts / KPIs) | After ops screens work; reuses their queries |
| **P18** | Reports / exports | Fold into Dashboard or Ticketing history |

### Merged away (not separate screens)

| Former ID | Merged into |
|---|---|
| P05 Add / Edit Animal | P03 (Add) + P04 (Edit) |
| P06 Transfer Animal | P04 dialog |
| P08 Species and Conservation | P19 Admin |
| P10 Feeding Plans | P04 Feeding tab |
| P11 Care Assignments | P04 Care tab (+ workload hints on P15) |
| P14 Suppliers | P13 Suppliers tab |
| P16 Shift Schedule | P15 profile Shifts tab |

---

## 3. Navigation Map and Page List

```
Login (P01)
└── Main layout (sidebar + top bar)
    ├── Animals
    │   ├── P03 Animal List          ← “Add animal” opens wizard/modal
    │   └── P04 Animal Detail (tabs) ← Edit, Transfer, plans, care
    ├── P07 Habitats and Enclosures
    ├── P09 Feeding Today
    ├── P12 Veterinary Center
    ├── P13 Food Inventory           ← includes Suppliers
    ├── P15 Staff Directory          ← includes Shifts on profile
    ├── P17 Ticketing (Point of Sale)
    └── P19 Admin Settings           ← species, ticket types, zoo, departments
```

| ID | Page | Main users | Primary purpose |
|---|---|---|---|
| P01 | Login | Everyone | Authenticate and detect role |
| P03 | Animal List | Manager, Keeper, Vet | Find / filter animals; start Add Animal |
| P04 | Animal Detail | Keeper, Vet, Manager | Hub: overview, care, health, feeding plans, transfers, edit |
| P07 | Habitats and Enclosures | Manager | Manage places and capacity |
| P09 | Feeding Today | Keeper | Daily feeding worksheet and logging |
| P12 | Veterinary Center | Vet | Due vaccines, checkups, treatments |
| P13 | Food Inventory | Manager, Keeper | Stock, expiry, deliveries, suppliers |
| P15 | Staff Directory | Manager | Employees, hierarchy, shifts |
| P17 | Ticketing | Cashier | Sell tickets |
| P19 | Admin Settings | Admin | Lookups: zoo, departments, species, conservation, ticket types |

---

## 4. Roles and Access Matrix

Roles come from `STAFF.Role` (Manager, Keeper, Veterinarian, Cashier). Admin is a manager with settings access.

| Page | Manager / Admin | Keeper | Veterinarian | Cashier |
|---|---|---|---|---|
| P03 Animal List | Read/Write (Add) | Read | Read | No |
| P04 Animal Detail | Full | Read; log notes; limited edit | Full health / plans | No |
| P07 Habitats and Enclosures | Yes | Read | Read | No |
| P09 Feeding Today | Read | Yes (log feeding) | Read | No |
| P12 Veterinary Center | Read | No | Yes | No |
| P13 Food Inventory | Yes (incl. suppliers) | Read stock | Read | No |
| P15 Staff | Yes (incl. shifts, salary) | Own profile / shifts | Own profile / shifts | Own profile / shifts |
| P17 Ticketing | Read | No | No | Yes |
| P19 Admin | Yes | No | Species read/write optional | No |

**Justification:** Salary and supplier prices are manager-only; medical writes are vet-only; keepers need fast feeding; cashiers get one focused POS screen.

---

## 5. Page Specifications

### P01. Login

**Purpose:** Authenticate the user and load role for navigation and permissions.

**Components:** Email/username, password, Sign in, error message.

**Database (illustrative — auth table or STAFF + credentials):**
```sql
SELECT StaffID, FirstName, LastName, Role, DepartmentID
FROM STAFF
WHERE Email = :email;
-- Password check happens in application code against a hashed secret (not stored in plain text).
```

**Justification:** Role detection drives the access matrix for every other screen.

---

### P03. Animal List

**Purpose:** Find and filter animals; launch **Add Animal**.

**Components:** Search (name), filters (species, habitat, enclosure, health, gender), sortable table, pagination, **Add animal** button → wizard/modal (former P05). Row click opens **P04**.

```sql
SELECT a.AnimalID, a.Name, a.Gender, a.HealthStatus, a.BirthDate,
       s.CommonName, e.Name AS Enclosure, h.Name AS Habitat
FROM ANIMAL a
JOIN SPECIES s        ON a.SpeciesID = s.SpeciesID
LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID
LEFT JOIN HABITAT h   ON e.HabitatID = h.HabitatID
WHERE (:name IS NULL OR a.Name ILIKE '%' || :name || '%')
  AND (:species_id IS NULL OR a.SpeciesID = :species_id)
  AND (:health IS NULL OR a.HealthStatus = :health)
ORDER BY a.Name
LIMIT :page_size OFFSET :offset;
```

#### Add Animal (modal / wizard on P03)

**Steps:** (1) Basic info → (2) Placement → (3) Optional arrival health → (4) Optional care & diet.

```sql
-- Species / enclosure dropdowns
SELECT SpeciesID, CommonName, DietType FROM SPECIES ORDER BY CommonName;

SELECT e.EnclosureID, e.Name, h.Name AS Habitat,
       e.Capacity - COUNT(a.AnimalID) AS FreeSpots
FROM ENCLOSURE e
JOIN HABITAT h     ON e.HabitatID = h.HabitatID
LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID
WHERE e.Condition <> 'Under Maintenance'
GROUP BY e.EnclosureID, e.Name, e.Capacity, h.Name
HAVING e.Capacity - COUNT(a.AnimalID) > 0;

-- Save (one transaction)
BEGIN;
INSERT INTO ANIMAL (SpeciesID, EnclosureID, Name, Gender, BirthDate, ArrivalDate, Origin, HealthStatus)
VALUES (:species_id, :enclosure_id, :name, :gender, :birth_date, :arrival_date, :origin, 'Healthy')
RETURNING AnimalID;

INSERT INTO MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup)
VALUES (:new_animal_id, :vet_id, CURRENT_DATE, :diagnosis, :treatment, :next_checkup);

INSERT INTO VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue)
VALUES (:new_animal_id, :vet_id, :vaccine, CURRENT_DATE, :next_due);

INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (:staff_id, :new_animal_id, CURRENT_DATE, :responsibility);

INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
VALUES (:new_animal_id, :food_id, :qty, :time, :frequency);
COMMIT;
```

**Justification:** List + add on one screen removes a dedicated “Add Animal” page while keeping the multi-table registration transaction.

---

### P04. Animal Detail (hub page)

**Purpose:** Everything about one animal: overview, care team, medical, vaccinations, **feeding plans** (edit), transfer history, **edit** and **transfer** actions.

**Header:** Name, species, conservation badge, health, enclosure/habitat, age. Buttons: **Edit**, **Transfer**, **Mark deceased** (Manager).

```sql
SELECT a.AnimalID, a.Name, a.Gender, a.BirthDate, a.ArrivalDate, a.Origin, a.HealthStatus,
       s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears,
       cs.Code AS StatusCode, cs.Name AS ConservationStatus,
       e.Name AS Enclosure, h.Name AS Habitat, h.BiomeType
FROM ANIMAL a
JOIN SPECIES s              ON a.SpeciesID = s.SpeciesID
JOIN CONSERVATION_STATUS cs ON s.StatusID  = cs.StatusID
LEFT JOIN ENCLOSURE e       ON a.EnclosureID = e.EnclosureID
LEFT JOIN HABITAT h         ON e.HabitatID   = h.HabitatID
WHERE a.AnimalID = :animal_id;
```

#### Tab: Care Team *(absorbs former P11 for this animal)*

```sql
SELECT ca.AssignmentID, st.FirstName, st.LastName, ca.Responsibility, ca.StartDate
FROM CARE_ASSIGNMENT ca JOIN STAFF st ON ca.StaffID = st.StaffID
WHERE ca.AnimalID = :animal_id AND ca.EndDate IS NULL;

INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (:staff_id, :animal_id, CURRENT_DATE, :responsibility);

UPDATE CARE_ASSIGNMENT SET EndDate = CURRENT_DATE WHERE AssignmentID = :assignment_id;
```

#### Tab: Medical / Vaccinations

```sql
SELECT m.RecordID, m.CheckupDate, m.Diagnosis, m.Treatment, m.NextCheckup,
       st.FirstName || ' ' || st.LastName AS Vet
FROM MEDICAL_RECORD m JOIN STAFF st ON m.VetID = st.StaffID
WHERE m.AnimalID = :animal_id ORDER BY m.CheckupDate DESC;

SELECT v.VaccinationID, v.VaccineName, v.DateGiven, v.NextDue,
       st.FirstName || ' ' || st.LastName AS Vet
FROM VACCINATION v JOIN STAFF st ON v.VetID = st.StaffID
WHERE v.AnimalID = :animal_id ORDER BY v.DateGiven DESC;
```

#### Tab: Feeding *(absorbs former P10)*

**Components:** Diet lines (food, amount, time, frequency), add/edit/remove plan line, last 10 feedings. Daily logging stays on **P09**.

```sql
SELECT fp.PlanID, ft.Name AS Food, fp.QuantityPerMeal, ft.Unit, fp.FeedingTime, fp.Frequency,
       (SELECT MAX(fl.FedAt) FROM FEEDING_LOG fl WHERE fl.PlanID = fp.PlanID) AS LastFed
FROM FEEDING_PLAN fp JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID
WHERE fp.AnimalID = :animal_id ORDER BY fp.FeedingTime;

INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
VALUES (:animal_id, :food_id, :qty, :time, :frequency);
UPDATE FEEDING_PLAN SET QuantityPerMeal = :qty, FeedingTime = :time, Frequency = :frequency
WHERE PlanID = :plan_id;
-- DELETE may fail (RESTRICT) if logs exist → offer Replace/Update instead
```

#### Tab: Transfers + Transfer dialog *(absorbs former P06)*

```sql
SELECT t.TransferDate, ef.Name AS FromEnclosure, et.Name AS ToEnclosure, t.Reason
FROM ANIMAL_TRANSFER t
JOIN ENCLOSURE ef ON t.FromEnclosureID = ef.EnclosureID
JOIN ENCLOSURE et ON t.ToEnclosureID   = et.EnclosureID
WHERE t.AnimalID = :animal_id ORDER BY t.TransferDate DESC;

-- Confirm transfer (one transaction)
BEGIN;
INSERT INTO ANIMAL_TRANSFER (AnimalID, FromEnclosureID, ToEnclosureID, TransferDate, Reason)
SELECT AnimalID, EnclosureID, :to_enclosure_id, CURRENT_DATE, :reason
FROM ANIMAL WHERE AnimalID = :animal_id AND EnclosureID IS NOT NULL;
UPDATE ANIMAL SET EnclosureID = :to_enclosure_id WHERE AnimalID = :animal_id;
COMMIT;
```

#### Edit animal / Mark deceased

```sql
UPDATE ANIMAL
SET Name = :name, Gender = :gender, BirthDate = :birth_date, Origin = :origin, HealthStatus = :health
WHERE AnimalID = :animal_id;

BEGIN;
UPDATE ANIMAL SET HealthStatus = 'Deceased', EnclosureID = NULL WHERE AnimalID = :animal_id;
UPDATE CARE_ASSIGNMENT SET EndDate = CURRENT_DATE
 WHERE AnimalID = :animal_id AND EndDate IS NULL;
COMMIT;
```

**Justification:** One hub replaces four former pages (edit, transfer, plans, care) without losing SQL coverage.

---

### P07. Habitats and Enclosures

**Purpose:** Manage ecosystem zones and physical enclosures; monitor capacity.

**Components:** Habitat list/cards, enclosure table per habitat, add/edit forms, occupancy vs capacity, condition badge.

```sql
SELECT h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm,
       COUNT(e.EnclosureID) AS Enclosures
FROM HABITAT h
LEFT JOIN ENCLOSURE e ON e.HabitatID = h.HabitatID
WHERE h.ZooID = :zoo_id
GROUP BY h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm;

SELECT e.EnclosureID, e.Name, e.Capacity, e.Condition, e.LastMaintenance,
       COUNT(a.AnimalID) AS Occupancy
FROM ENCLOSURE e
LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID
WHERE e.HabitatID = :habitat_id
GROUP BY e.EnclosureID, e.Name, e.Capacity, e.Condition, e.LastMaintenance;

INSERT INTO HABITAT (ZooID, Name, BiomeType, Climate, AreaSqm)
VALUES (:zoo_id, :name, :biome, :climate, :area);
INSERT INTO ENCLOSURE (HabitatID, Name, Capacity, Condition, LastMaintenance)
VALUES (:habitat_id, :name, :capacity, :condition, :last_maint);
UPDATE ENCLOSURE SET Capacity = :capacity, Condition = :condition, LastMaintenance = :last_maint
WHERE EnclosureID = :enclosure_id;
```

**Justification:** Placement and capacity must exist before animals can be registered or transferred.

---

### P09. Feeding Today (keeper worksheet)

**Purpose:** Daily task list: see what to feed and log it quickly. *(Plan setup is on P04.)*

**Components:** Date, progress (done/total), filters (my animals, habitat, time), checklist, **Mark fed** dialog (quantity, notes).

```sql
SELECT fp.PlanID, fp.FeedingTime, a.AnimalID, a.Name AS Animal, e.Name AS Enclosure,
       ft.Name AS Food, fp.QuantityPerMeal, ft.Unit,
       fl.LogID, fl.FedAt, fl.QuantityGiven,
       CASE WHEN fl.LogID IS NOT NULL THEN 'Done'
            WHEN fp.FeedingTime < CURRENT_TIME THEN 'Late'
            ELSE 'Pending' END AS Status
FROM FEEDING_PLAN fp
JOIN ANIMAL a         ON fp.AnimalID = a.AnimalID
JOIN FOOD_TYPE ft     ON fp.FoodID   = ft.FoodID
LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID
LEFT JOIN FEEDING_LOG fl
       ON fl.PlanID = fp.PlanID AND CAST(fl.FedAt AS DATE) = CURRENT_DATE
WHERE a.HealthStatus <> 'Deceased'
ORDER BY fp.FeedingTime, a.Name;

INSERT INTO FEEDING_LOG (PlanID, StaffID, FedAt, QuantityGiven, Notes)
VALUES (:plan_id, :my_staff_id, CURRENT_TIMESTAMP, :quantity_given, :notes);
```

**Justification:** High-frequency keeper work stays on one fast screen; diet design stays on the animal hub.

---

### P12. Veterinary Center

**Purpose:** Vet work queue: due vaccines, overdue checkups, under treatment, new record.

```sql
SELECT a.AnimalID, a.Name AS Animal, v.VaccineName, v.NextDue,
       CASE WHEN v.NextDue < CURRENT_DATE THEN 'Overdue' ELSE 'Due soon' END AS Status
FROM VACCINATION v
JOIN ANIMAL a ON v.AnimalID = a.AnimalID
WHERE v.NextDue <= CURRENT_DATE + INTERVAL '30 days'
  AND a.HealthStatus <> 'Deceased'
  AND NOT EXISTS (SELECT 1 FROM VACCINATION v2
                  WHERE v2.AnimalID = v.AnimalID
                    AND v2.VaccineName = v.VaccineName
                    AND v2.DateGiven > v.DateGiven)
ORDER BY v.NextDue;

SELECT a.AnimalID, a.Name AS Animal, MAX(m.NextCheckup) AS NextCheckup
FROM ANIMAL a JOIN MEDICAL_RECORD m ON m.AnimalID = a.AnimalID
WHERE a.HealthStatus <> 'Deceased'
GROUP BY a.AnimalID, a.Name
HAVING MAX(m.NextCheckup) < CURRENT_DATE
ORDER BY NextCheckup;

BEGIN;
INSERT INTO MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup)
VALUES (:animal_id, :my_staff_id, CURRENT_DATE, :diagnosis, :treatment, :next_checkup);
UPDATE ANIMAL SET HealthStatus = :new_status WHERE AnimalID = :animal_id;
COMMIT;

INSERT INTO VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue)
VALUES (:animal_id, :my_staff_id, :vaccine, CURRENT_DATE, :next_due);
```

**Justification:** Vets work from queues; per-animal history remains on P04.

---

### P13. Food Inventory *(includes Suppliers — former P14)*

**Purpose:** Stock levels, expiry, deliveries, food types, and **supplier** directory.

**Components:** Stock summary, expiring panel, purchase history, Record delivery form, **Suppliers** tab (contacts + spending).

```sql
SELECT ft.FoodID, ft.Name AS Food, ft.Unit,
       COALESCE(p.Purchased, 0) - COALESCE(c.Consumed, 0) AS EstimatedStock
FROM FOOD_TYPE ft
LEFT JOIN (SELECT FoodID, SUM(Quantity) AS Purchased FROM FOOD_STOCK GROUP BY FoodID) p
       ON p.FoodID = ft.FoodID
LEFT JOIN (SELECT fp.FoodID, SUM(fl.QuantityGiven) AS Consumed
           FROM FEEDING_LOG fl JOIN FEEDING_PLAN fp ON fl.PlanID = fp.PlanID
           GROUP BY fp.FoodID) c ON c.FoodID = ft.FoodID
ORDER BY EstimatedStock;

SELECT ft.Name AS Food, fs.Quantity, fs.ExpiryDate, sp.Name AS Supplier
FROM FOOD_STOCK fs
JOIN FOOD_TYPE ft ON fs.FoodID = ft.FoodID
JOIN SUPPLIER sp  ON fs.SupplierID = sp.SupplierID
WHERE fs.ExpiryDate BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
ORDER BY fs.ExpiryDate;

INSERT INTO FOOD_STOCK (FoodID, SupplierID, Quantity, UnitPrice, PurchaseDate, ExpiryDate)
VALUES (:food_id, :supplier_id, :quantity, :unit_price, :purchase_date, :expiry_date);
INSERT INTO FOOD_TYPE (Name, Category, Unit, CaloriesPerUnit)
VALUES (:name, :category, :unit, :calories);

-- Suppliers tab
SELECT sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone,
       COALESCE(SUM(fs.Quantity * fs.UnitPrice), 0) AS TotalSpent,
       MAX(fs.PurchaseDate) AS LastDelivery
FROM SUPPLIER sp
LEFT JOIN FOOD_STOCK fs ON fs.SupplierID = sp.SupplierID
GROUP BY sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone
ORDER BY TotalSpent DESC;

INSERT INTO SUPPLIER (Name, ContactPerson, Phone, Address)
VALUES (:name, :contact, :phone, :address);
UPDATE SUPPLIER SET Name = :name, ContactPerson = :contact, Phone = :phone, Address = :address
WHERE SupplierID = :supplier_id;
```

**Justification:** Deliveries always need a supplier; one screen avoids a separate supplier-only page.

---

### P15. Staff Directory *(includes Shifts — former P16)*

**Purpose:** Employees, hierarchy, assignments overview, and **shift** scheduling on the profile.

**Components:** Directory filters, Add employee, profile tabs: Details, Assignments, **Shifts**, Subordinates. Optional keeper workload panel (unassigned animals / counts) for care balancing.

```sql
SELECT s.StaffID, s.FirstName, s.LastName, s.Role, d.Name AS Department,
       m.FirstName || ' ' || m.LastName AS Supervisor, s.Phone, s.Email
FROM STAFF s
JOIN DEPARTMENT d ON s.DepartmentID = d.DepartmentID
LEFT JOIN STAFF m ON s.SupervisorID = m.StaffID
WHERE (:dept_id IS NULL OR s.DepartmentID = :dept_id)
  AND (:role    IS NULL OR s.Role = :role)
ORDER BY s.LastName;

INSERT INTO STAFF (DepartmentID, SupervisorID, FirstName, LastName, Role, Phone, Email, HireDate, Salary)
VALUES (:dept_id, :supervisor_id, :first, :last, :role, :phone, :email, :hire_date, :salary);

-- Shifts tab (week view)
SELECT ss.ShiftID, ss.ShiftDate, ss.StartTime, ss.EndTime,
       st.StaffID, st.FirstName, st.LastName, st.Role
FROM STAFF_SHIFT ss JOIN STAFF st ON ss.StaffID = st.StaffID
WHERE ss.ShiftDate BETWEEN :week_start AND :week_end
ORDER BY ss.ShiftDate, ss.StartTime;

INSERT INTO STAFF_SHIFT (StaffID, ShiftDate, StartTime, EndTime)
VALUES (:staff_id, :shift_date, :start_time, :end_time);

-- Workload hint (optional panel)
SELECT st.StaffID, st.FirstName, st.LastName, COUNT(DISTINCT ca.AnimalID) AS AnimalsCaredFor
FROM STAFF st
LEFT JOIN CARE_ASSIGNMENT ca ON ca.StaffID = st.StaffID AND ca.EndDate IS NULL
WHERE st.Role = 'Keeper'
GROUP BY st.StaffID, st.FirstName, st.LastName
ORDER BY AnimalsCaredFor DESC;
```

**Justification:** People + shifts belong together; care workload fits on the same “People” screen.

---

### P17. Ticketing (Point of Sale)

**Purpose:** Sell tickets quickly by type.

**Components:** Ticket type buttons with price, quantity, Visit date, Sell, today’s sales list.

```sql
SELECT TicketTypeID, Name, Price, Description FROM TICKET_TYPE ORDER BY Price;

INSERT INTO TICKET (TicketTypeID, SoldByStaffID, VisitDate, PurchasedAt, Quantity, TotalPrice)
VALUES (:ticket_type_id, :my_staff_id, :visit_date, CURRENT_TIMESTAMP, :quantity,
        (SELECT Price FROM TICKET_TYPE WHERE TicketTypeID = :ticket_type_id) * :quantity);

SELECT t.TicketID, tt.Name, t.Quantity, t.TotalPrice, t.VisitDate, t.PurchasedAt
FROM TICKET t JOIN TICKET_TYPE tt ON t.TicketTypeID = tt.TicketTypeID
WHERE CAST(t.PurchasedAt AS DATE) = CURRENT_DATE
ORDER BY t.PurchasedAt DESC;
```

**Justification:** One focused POS screen for the Cashier role.

---

### P19. Admin Settings *(includes Species — former P08)*

**Purpose:** Rarely changed lookups and zoo structure: zoo profile, departments, **species & conservation**, ticket types, food categories as needed.

```sql
UPDATE ZOO SET Name = :name, City = :city, Address = :address, Phone = :phone WHERE ZooID = :zoo_id;

SELECT d.DepartmentID, d.Name, d.Description, COUNT(s.StaffID) AS Employees
FROM DEPARTMENT d LEFT JOIN STAFF s ON s.DepartmentID = d.DepartmentID
WHERE d.ZooID = :zoo_id GROUP BY d.DepartmentID, d.Name, d.Description;
INSERT INTO DEPARTMENT (ZooID, Name, Description) VALUES (:zoo_id, :name, :description);

-- Species & conservation
SELECT s.SpeciesID, s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears,
       cs.Code, cs.Name AS StatusName
FROM SPECIES s JOIN CONSERVATION_STATUS cs ON s.StatusID = cs.StatusID
ORDER BY s.CommonName;
INSERT INTO SPECIES (StatusID, CommonName, ScientificName, DietType, AvgLifespanYears)
VALUES (:status_id, :common, :scientific, :diet, :lifespan);
INSERT INTO CONSERVATION_STATUS (Code, Name, Description) VALUES (:code, :name, :description);

-- Ticket types
INSERT INTO TICKET_TYPE (Name, Price, Description) VALUES (:name, :price, :description);
UPDATE TICKET_TYPE SET Price = :price, Description = :description WHERE TicketTypeID = :id;
```

**Justification:** Lookup tables control dropdowns everywhere; keeping them admin-only avoids accidental edits. Species does not need a top-level nav item for a 10-screen build.

---

## 6. Page-to-Table Matrix

R = reads, W = writes (INSERT / UPDATE / DELETE). Only the **10 core screens** are columns.

| Table | P03 | P04 | P07 | P09 | P12 | P13 | P15 | P17 | P19 |
|---|---|---|---|---|---|---|---|---|---|
| ZOO | | | R | | | | | | R/W |
| DEPARTMENT | | | | | | | R | | R/W |
| STAFF | | R | | R | R | | R/W | R | |
| STAFF_SHIFT | | | | | | | R/W | | |
| HABITAT | R | R | R/W | | | | | | |
| ENCLOSURE | R | R | R/W | R | R | | | | |
| CONSERVATION_STATUS | | R | | | | | | | R/W |
| SPECIES | R | R | | | | | | | R/W |
| ANIMAL | R/W | R/W | R | R | R/W | | | | |
| ANIMAL_TRANSFER | | W | | | | | | | |
| CARE_ASSIGNMENT | W | R/W | | R | | | R | | |
| MEDICAL_RECORD | W | R | | | R/W | | | | |
| VACCINATION | W | R | | | R/W | | | | |
| FOOD_TYPE | | R | | R | | R/W | | | |
| SUPPLIER | | | | | | R/W | | | |
| FOOD_STOCK | | | | | | R/W | | | |
| FEEDING_PLAN | W | R/W | | R | | R | | | |
| FEEDING_LOG | | R | | R/W | | R | | | |
| TICKET_TYPE | | | | | | | | R | R/W |
| TICKET | | | | | | | | R/W | |

P01 authenticates against STAFF (read). All 20 tables remain covered by the 10 screens.

---

## 7. Cross-Cutting Rules

### 7.1 Transactions (multi-table actions)

| Action | Screen | Tables changed in one transaction |
|---|---|---|
| Register animal | P03 Add wizard | ANIMAL, MEDICAL_RECORD, VACCINATION, CARE_ASSIGNMENT, FEEDING_PLAN |
| Transfer animal | P04 dialog | ANIMAL_TRANSFER, ANIMAL |
| Mark deceased | P04 | ANIMAL, CARE_ASSIGNMENT |
| Checkup with status change | P12 | MEDICAL_RECORD, ANIMAL |

### 7.2 Mapping database errors to friendly messages

| Database error | Message shown |
|---|---|
| UNIQUE violation on `STAFF.Email` | "This email is already registered." |
| UNIQUE violation on `SPECIES.ScientificName` | "This species already exists." |
| CHECK violation on dates | "End date must be after start date." |
| FOREIGN KEY violation on delete (RESTRICT) | "This record is used elsewhere and cannot be deleted." |
| Capacity trigger | "This enclosure is full." |
| CHECK `Capacity > 0` | "Capacity must be at least 1." |

### 7.3 Security and quality

- Use **parameterized queries** everywhere.
- Check **role permissions on the server**, not only by hiding buttons.
- Hash passwords; never store them in plain text.
- Use **pagination** for lists; index filter/join columns.
- Show loading, empty, and error states.
- Make **P09** and **P17** responsive (tablet / phone friendly).

---

## 8. Suggested Build Order

| Phase | Screens | Reason |
|---|---|---|
| 1. Foundation | P01, P19, P15 | Login, lookups (species, ticket types), staff |
| 2. Places & animals | P07, P03, P04 | Habitats → list → detail hub (edit, transfer, plans, care) |
| 3. Daily care | P09 | Feeding worksheet (plans already on P04) |
| 4. Health & supplies | P12, P13 | Vet queues; inventory + suppliers |
| 5. Visitors | P17 | Ticketing POS |
| 6. Stretch (optional) | P02 Dashboard (± reports) | Reuses queries from earlier screens |

**Justification:** Order follows data dependencies and delivers a demonstrable core of **10 screens** before optional insight UI.

---

*End of document.*
