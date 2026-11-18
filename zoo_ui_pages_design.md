# Zoo Management System: UI Pages, Components, and Database Mapping

This document proposes the user interface for the 20-table Zoo Database. For every page it gives the purpose, the components, the content shown, the functions available, the **SQL queries and commands** behind each function, and the **justification** for why the page exists and is built that way.

> Conventions
> - `:name` marks a **parameter** supplied by the UI (always use prepared statements / parameterized queries; never build SQL by string concatenation).
> - SQL is PostgreSQL-style. In MySQL use `CURDATE()`, `NOW()`, `CONCAT()`, `LIKE`; in SQL Server use `GETDATE()`, `DATEADD()`.
> - Query names Q1 to Q15 refer to the example queries in the schema documentation.

---

## Table of Contents

1. [Design Principles and Justification](#1-design-principles-and-justification)
2. [Navigation Map and Page List](#2-navigation-map-and-page-list)
3. [Roles and Access Matrix](#3-roles-and-access-matrix)
4. [Page Specifications](#4-page-specifications)
5. [Page-to-Table Matrix](#5-page-to-table-matrix)
6. [Cross-Cutting Rules (Transactions, Validation, Errors)](#6-cross-cutting-rules)
7. [Suggested Build Order](#7-suggested-build-order)

---

## 1. Design Principles and Justification

| Principle | What it means | Why |
|---|---|---|
| **Task-oriented pages** | Pages follow daily jobs (feed animals, check vaccines, sell tickets), not database tables. | Keepers, vets, and cashiers think in tasks, not in tables. A page often reads from many tables. |
| **Dashboard first** | The landing page shows alerts (missed feedings, due vaccines, low stock, full enclosures). | The system's goal is to make care and management *visible*; alerts turn queries into action. |
| **Animal-centric navigation** | The animal detail page is the hub that links to care team, health, feeding, and transfers. | ANIMAL is the central entity of the schema; most questions start with "what about this animal?" |
| **Role-based views** | Each role sees only what it needs. | Reduces mistakes, protects salary and staff data, speeds up daily work. |
| **History is never deleted** | Pages offer *end*, *deactivate*, or *mark deceased* instead of *delete*. | The schema uses RESTRICT on important foreign keys and keeps history tables (transfers, medical records, logs). |
| **Safe writes** | Multi-table actions run in one transaction; the UI validates before sending. | Keeps data consistent (for example, a transfer inserts a history row and updates the animal together). |
| **Forms reflect constraints** | Dropdowns for CHECK lists, date pickers with min/max, required markers for NOT NULL. | Prevents most constraint violations before they reach the database. |

---

## 2. Navigation Map and Page List

```
Login
└── Main layout (sidebar + top bar)
    ├── P02 Dashboard
    ├── Animals
    │   ├── P03 Animal List
    │   ├── P04 Animal Detail (tabs)
    │   ├── P05 Add / Edit Animal
    │   └── P06 Transfer Animal (dialog)
    ├── Places
    │   └── P07 Habitats and Enclosures
    ├── Species
    │   └── P08 Species and Conservation
    ├── Care
    │   ├── P09 Feeding Today
    │   ├── P10 Feeding Plans
    │   └── P11 Care Assignments
    ├── Health
    │   └── P12 Veterinary Center
    ├── Supplies
    │   ├── P13 Food Inventory
    │   └── P14 Suppliers
    ├── People
    │   ├── P15 Staff Directory and Profile
    │   └── P16 Shift Schedule
    ├── Visitors
    │   └── P17 Ticketing (Point of Sale)
    ├── P18 Reports
    └── P19 Admin Settings
```

| ID | Page | Main users | Primary purpose |
|---|---|---|---|
| P01 | Login | Everyone | Authenticate and detect role |
| P02 | Dashboard | Manager, all | Alerts and key numbers |
| P03 | Animal List | Manager, Keeper, Vet | Find and filter animals |
| P04 | Animal Detail | Keeper, Vet, Manager | Everything about one animal |
| P05 | Add / Edit Animal | Manager, Keeper | Register and update animals |
| P06 | Transfer Animal | Manager, Keeper | Move an animal between enclosures |
| P07 | Habitats and Enclosures | Manager | Manage places and capacity |
| P08 | Species and Conservation | Manager, Vet | Species catalog |
| P09 | Feeding Today | Keeper | Daily feeding worksheet and logging |
| P10 | Feeding Plans | Keeper (lead), Vet, Manager | Define diets |
| P11 | Care Assignments | Manager | Assign keepers to animals |
| P12 | Veterinary Center | Vet | Checkups, vaccines, treatments |
| P13 | Food Inventory | Manager, Keeper | Stock, expiry, deliveries |
| P14 | Suppliers | Manager | Supplier directory and spending |
| P15 | Staff Directory and Profile | Manager | Employees and hierarchy |
| P16 | Shift Schedule | Manager | Weekly work schedule |
| P17 | Ticketing | Cashier | Sell tickets |
| P18 | Reports | Manager | Analytics and exports |
| P19 | Admin Settings | Admin | Lookup tables and zoo info |

---

## 3. Roles and Access Matrix

Roles come from `STAFF.Role` (Manager, Keeper, Veterinarian, Cashier). Admin is a manager with settings access.

| Page | Manager / Admin | Keeper | Veterinarian | Cashier |
|---|---|---|---|---|
| P02 Dashboard | Full | Own tasks | Health alerts | Sales summary |
| P03 Animal List | Read/Write | Read | Read | No |
| P04 Animal Detail | Full | Read, add feeding notes | Full health tabs | No |
| P05 Add/Edit Animal | Yes | Limited (basic fields) | No | No |
| P06 Transfer Animal | Yes | Yes | No | No |
| P07 Habitats and Enclosures | Yes | Read | Read | No |
| P08 Species | Yes | Read | Read/Write | No |
| P09 Feeding Today | Read | Yes (log feeding) | Read | No |
| P10 Feeding Plans | Yes | Read | Yes | No |
| P11 Care Assignments | Yes | Read (own) | Read | No |
| P12 Veterinary Center | Read | No | Yes | No |
| P13 Food Inventory | Yes | Read | Read | No |
| P14 Suppliers | Yes | No | No | No |
| P15 Staff | Yes | Own profile | Own profile | Own profile |
| P16 Shifts | Yes | Own shifts | Own shifts | Own shifts |
| P17 Ticketing | Read | No | No | Yes |
| P18 Reports | Yes | No | Limited | Sales only |
| P19 Admin | Yes | No | No | No |

**Justification:** Salary, supplier prices, and revenue are sensitive; medical data is edited only by veterinarians; keepers need quick access to feeding; cashiers need a single focused screen.

> **Note on login:** the schema has no password column. For authentication, add a column such as `STAFF.PasswordHash` (or a separate `APP_USER` table, listed under extensions in the schema documentation). Authorization uses `STAFF.Role`.

---

## 4. Page Specifications

---

### P01. Login

**Purpose:** Identify the employee and load their role.
**Components:** Email field, password field, "Sign in" button, error message area.
**Functions:** Sign in, sign out.

**Database:**
```sql
-- Requires an added PasswordHash column (see note in section 3)
SELECT StaffID, FirstName, LastName, Role, PasswordHash
FROM STAFF
WHERE Email = :email;
```
The application compares the password hash; the query returns the role used for access control.

**Justification:** Role-based access (section 3) depends on knowing who is signed in. Email is chosen because it is already UNIQUE in STAFF.

---

### P02. Dashboard

**Purpose:** One-screen overview of the zoo's state and everything that needs attention today.

**Layout sketch**
```
+-----------------------------------------------------------------+
| KPI cards:  Animals | Under treatment | Staff on duty | Today's  |
|                                                      visitors/$ |
+--------------------------+--------------------------------------+
| ALERTS                   | TODAY                                |
|  - Missed feedings (n)   |  - Feeding progress bar (done/total) |
|  - Vaccines due 7 days   |  - Staff on duty list                |
|  - Overdue checkups      |  - Ticket sales mini-chart           |
|  - Food low / expiring   |                                      |
|  - Enclosures full       |                                      |
+--------------------------+--------------------------------------+
```

**Components:** KPI cards, alert list with counts and "View" links, feeding progress bar, staff-on-duty table, small sales chart.

**Content and database queries**

| Component | Query |
|---|---|
| Total living animals | `SELECT COUNT(*) FROM ANIMAL WHERE HealthStatus <> 'Deceased';` |
| Animals by health status | `SELECT HealthStatus, COUNT(*) AS N FROM ANIMAL GROUP BY HealthStatus;` |
| Staff on duty now | `SELECT st.FirstName, st.LastName, st.Role, ss.StartTime, ss.EndTime FROM STAFF_SHIFT ss JOIN STAFF st ON ss.StaffID = st.StaffID WHERE ss.ShiftDate = CURRENT_DATE AND CURRENT_TIME BETWEEN ss.StartTime AND ss.EndTime;` |
| Today's visitors and revenue | `SELECT COALESCE(SUM(Quantity),0) AS Visitors, COALESCE(SUM(TotalPrice),0) AS Revenue FROM TICKET WHERE VisitDate = CURRENT_DATE;` |
| Feeding progress | Count of rows from the P09 query: total plans vs plans with a log today |
| Missed feedings alert | Q7 (planned feedings without a log today) |
| Vaccines due (7 days) | Q4 with `INTERVAL '7 days'` |
| Overdue checkups | Q5 |
| Low stock | Q8 filtered by a minimum threshold |
| Expiring food | Q9 |
| Full enclosures | Q3 |

**Functions:** Click any alert or card to jump to the related page (P09, P12, P13, P07).

**Justification:** The goal of the project is to make care and management visible. The dashboard reuses the report queries as *alerts*, so managers do not have to run each check manually. All numbers are read-only, so the page is safe and fast.

---

### P03. Animal List

**Purpose:** Find any animal quickly and see its basic status.

**Components:** Search box (name), filter dropdowns (species, habitat, enclosure, health status, gender), sortable table, pagination, "Add animal" button, row click opens P04.

**Content:** ID, name, species, gender, enclosure, habitat, health status badge (Healthy green, Under Treatment orange, Quarantine red, Deceased grey).

**Database:**
```sql
-- Filter dropdown data
SELECT SpeciesID, CommonName FROM SPECIES ORDER BY CommonName;
SELECT HabitatID, Name FROM HABITAT ORDER BY Name;

-- Main list (filters are optional: pass NULL to skip a filter)
SELECT a.AnimalID, a.Name, s.CommonName AS Species, a.Gender,
       e.Name AS Enclosure, h.Name AS Habitat, a.HealthStatus
FROM ANIMAL a
JOIN SPECIES s        ON a.SpeciesID   = s.SpeciesID
LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID
LEFT JOIN HABITAT h   ON e.HabitatID   = h.HabitatID
WHERE (:species_id IS NULL OR a.SpeciesID = :species_id)
  AND (:habitat_id IS NULL OR h.HabitatID = :habitat_id)
  AND (:health     IS NULL OR a.HealthStatus = :health)
  AND (:q          IS NULL OR a.Name ILIKE '%' || :q || '%')
ORDER BY a.Name
LIMIT :page_size OFFSET :offset;
```
(`LEFT JOIN` is used because `ANIMAL.EnclosureID` can be NULL for deceased or off-site animals.)

**Justification:** A searchable list is the entry point for almost every animal task. Server-side filtering and pagination keep the page fast as the number of animals grows.

---

### P04. Animal Detail (hub page)

**Purpose:** Show everything about one animal in one place, organized in tabs.

**Header:** Animal name, species (common and scientific), conservation status badge, health status, current enclosure and habitat, age. Buttons: **Edit** (P05), **Transfer** (P06), **Mark deceased** (Manager).

```sql
-- Header and Overview tab
SELECT a.AnimalID, a.Name, a.Gender, a.BirthDate, a.ArrivalDate, a.Origin, a.HealthStatus,
       s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears,
       cs.Code AS StatusCode, cs.Name AS ConservationStatus,
       e.Name AS Enclosure, h.Name AS Habitat, h.BiomeType
FROM ANIMAL a
JOIN SPECIES s                 ON a.SpeciesID = s.SpeciesID
JOIN CONSERVATION_STATUS cs    ON s.StatusID  = cs.StatusID
LEFT JOIN ENCLOSURE e          ON a.EnclosureID = e.EnclosureID
LEFT JOIN HABITAT h            ON e.HabitatID   = h.HabitatID
WHERE a.AnimalID = :animal_id;
```

#### Tab 1: Overview
Shows the header data above, plus a short summary: next checkup date, next vaccine due, current caretakers count.

#### Tab 2: Care Team
**Components:** Table of current caretakers, history toggle, "Assign keeper" button.
```sql
-- Current team (Q2)
SELECT ca.AssignmentID, st.FirstName, st.LastName, ca.Responsibility, ca.StartDate
FROM CARE_ASSIGNMENT ca
JOIN STAFF st ON ca.StaffID = st.StaffID
WHERE ca.AnimalID = :animal_id AND ca.EndDate IS NULL;

-- Full history (toggle)
SELECT st.FirstName, st.LastName, ca.Responsibility, ca.StartDate, ca.EndDate
FROM CARE_ASSIGNMENT ca
JOIN STAFF st ON ca.StaffID = st.StaffID
WHERE ca.AnimalID = :animal_id
ORDER BY ca.StartDate DESC;

-- Assign a keeper
INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (:staff_id, :animal_id, CURRENT_DATE, :responsibility);

-- End an assignment
UPDATE CARE_ASSIGNMENT SET EndDate = CURRENT_DATE WHERE AssignmentID = :assignment_id;
```

#### Tab 3: Medical
**Components:** Timeline of checkups, "Add record" button (Vet only), next checkup badge.
```sql
SELECT m.RecordID, m.CheckupDate, m.Diagnosis, m.Treatment, m.NextCheckup,
       st.FirstName || ' ' || st.LastName AS Vet
FROM MEDICAL_RECORD m
JOIN STAFF st ON m.VetID = st.StaffID
WHERE m.AnimalID = :animal_id
ORDER BY m.CheckupDate DESC;
```

#### Tab 4: Vaccinations
```sql
SELECT v.VaccinationID, v.VaccineName, v.DateGiven, v.NextDue,
       st.FirstName || ' ' || st.LastName AS Vet,
       CASE WHEN v.NextDue < CURRENT_DATE THEN 'Overdue' ELSE 'OK' END AS Status
FROM VACCINATION v
JOIN STAFF st ON v.VetID = st.StaffID
WHERE v.AnimalID = :animal_id
ORDER BY v.DateGiven DESC;
```

#### Tab 5: Feeding
**Components:** Diet table (food, amount, time, frequency, last fed), "Edit plan" link to P10, last 10 feedings.
```sql
SELECT fp.PlanID, ft.Name AS Food, fp.QuantityPerMeal, ft.Unit, fp.FeedingTime, fp.Frequency,
       (SELECT MAX(fl.FedAt) FROM FEEDING_LOG fl WHERE fl.PlanID = fp.PlanID) AS LastFed
FROM FEEDING_PLAN fp
JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID
WHERE fp.AnimalID = :animal_id
ORDER BY fp.FeedingTime;

-- Recent feedings
SELECT fl.FedAt, ft.Name AS Food, fl.QuantityGiven, fl.Notes,
       st.FirstName || ' ' || st.LastName AS FedBy
FROM FEEDING_LOG fl
JOIN FEEDING_PLAN fp ON fl.PlanID  = fp.PlanID
JOIN FOOD_TYPE ft    ON fp.FoodID  = ft.FoodID
JOIN STAFF st        ON fl.StaffID = st.StaffID
WHERE fp.AnimalID = :animal_id
ORDER BY fl.FedAt DESC
LIMIT 10;
```

#### Tab 6: Transfers
```sql
-- Q11
SELECT t.TransferDate, ef.Name AS FromEnclosure, et.Name AS ToEnclosure, t.Reason
FROM ANIMAL_TRANSFER t
JOIN ENCLOSURE ef ON t.FromEnclosureID = ef.EnclosureID
JOIN ENCLOSURE et ON t.ToEnclosureID   = et.EnclosureID
WHERE t.AnimalID = :animal_id
ORDER BY t.TransferDate DESC;
```

**Justification:** The animal is the center of the schema, so this page is the hub: each tab maps to one related table (CARE_ASSIGNMENT, MEDICAL_RECORD, VACCINATION, FEEDING_PLAN and FEEDING_LOG, ANIMAL_TRANSFER). Tabs load their data only when opened, which keeps the page fast.

---

### P05. Add / Edit Animal

**Purpose:** Register a new animal (with its first care, health, and feeding setup) or correct an existing record.

**Components (new animal as a 4-step wizard):**
1. **Basic info:** name, species (dropdown), gender, birth date, arrival date, origin.
2. **Placement:** enclosure dropdown showing free spots (only enclosures with free capacity and not under maintenance).
3. **Health:** arrival checkup (diagnosis, treatment, next checkup) and initial vaccines (optional).
4. **Care and diet:** choose caretakers, add feeding plan lines (optional).
Buttons: Back, Next, Save, Cancel.

**Database:**
```sql
-- Species dropdown
SELECT SpeciesID, CommonName, DietType FROM SPECIES ORDER BY CommonName;

-- Enclosure dropdown: only those with free space
SELECT e.EnclosureID, e.Name, h.Name AS Habitat,
       e.Capacity - COUNT(a.AnimalID) AS FreeSpots
FROM ENCLOSURE e
JOIN HABITAT h        ON e.HabitatID = h.HabitatID
LEFT JOIN ANIMAL a    ON a.EnclosureID = e.EnclosureID
WHERE e.Condition <> 'Under Maintenance'
GROUP BY e.EnclosureID, e.Name, e.Capacity, h.Name
HAVING e.Capacity - COUNT(a.AnimalID) > 0
ORDER BY h.Name, e.Name;

-- Vet and keeper dropdowns
SELECT StaffID, FirstName, LastName FROM STAFF WHERE Role = 'Veterinarian';
SELECT StaffID, FirstName, LastName FROM STAFF WHERE Role = 'Keeper';
```

**Save (one transaction):**
```sql
BEGIN;

INSERT INTO ANIMAL (SpeciesID, EnclosureID, Name, Gender, BirthDate, ArrivalDate, Origin, HealthStatus)
VALUES (:species_id, :enclosure_id, :name, :gender, :birth_date, :arrival_date, :origin, 'Healthy')
RETURNING AnimalID;                        -- MySQL: use LAST_INSERT_ID()

INSERT INTO MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup)
VALUES (:new_animal_id, :vet_id, CURRENT_DATE, :diagnosis, :treatment, :next_checkup);

INSERT INTO VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue)
VALUES (:new_animal_id, :vet_id, :vaccine, CURRENT_DATE, :next_due);       -- repeat per vaccine

INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (:staff_id, :new_animal_id, CURRENT_DATE, :responsibility);          -- repeat per keeper

INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
VALUES (:new_animal_id, :food_id, :qty, :time, :frequency);                 -- repeat per line

COMMIT;
```

**Edit animal:**
```sql
UPDATE ANIMAL
SET Name = :name, Gender = :gender, BirthDate = :birth_date, Origin = :origin, HealthStatus = :health
WHERE AnimalID = :animal_id;
```
(Moving an animal uses P06, not this form, so transfer history is never skipped.)

**Mark deceased (Manager):**
```sql
BEGIN;
UPDATE ANIMAL SET HealthStatus = 'Deceased', EnclosureID = NULL WHERE AnimalID = :animal_id;
UPDATE CARE_ASSIGNMENT SET EndDate = CURRENT_DATE
 WHERE AnimalID = :animal_id AND EndDate IS NULL;
COMMIT;
```

**Validation:** name and species required; arrival date not before birth date; gender and health from fixed lists; enclosure must have free capacity.

**Justification:** A new animal touches five tables. A wizard guides the user through them in a logical order, and the single transaction guarantees that either everything is saved or nothing is. There is no "Delete animal" button: records are marked deceased so history stays intact (foreign keys use RESTRICT).

---

### P06. Transfer Animal (dialog)

**Purpose:** Move an animal to another enclosure and record it in the history.

**Components:** Animal summary (name, current enclosure), destination enclosure dropdown with free spots, reason text field, Confirm and Cancel buttons, warning area (full or under-maintenance enclosure).

**Database:**
```sql
-- Destination options (free space, not the current enclosure)
SELECT e.EnclosureID, e.Name, h.Name AS Habitat, e.Capacity - COUNT(a.AnimalID) AS FreeSpots
FROM ENCLOSURE e
JOIN HABITAT h     ON e.HabitatID = h.HabitatID
LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID
WHERE e.EnclosureID <> (SELECT EnclosureID FROM ANIMAL WHERE AnimalID = :animal_id)
  AND e.Condition <> 'Under Maintenance'
GROUP BY e.EnclosureID, e.Name, e.Capacity, h.Name
HAVING e.Capacity - COUNT(a.AnimalID) > 0;

-- Confirm (one transaction)
BEGIN;

INSERT INTO ANIMAL_TRANSFER (AnimalID, FromEnclosureID, ToEnclosureID, TransferDate, Reason)
SELECT AnimalID, EnclosureID, :to_enclosure_id, CURRENT_DATE, :reason
FROM ANIMAL
WHERE AnimalID = :animal_id AND EnclosureID IS NOT NULL;

UPDATE ANIMAL SET EnclosureID = :to_enclosure_id WHERE AnimalID = :animal_id;

COMMIT;
```
The "from" enclosure is read from ANIMAL itself, so the history always matches reality (business rule 4 in the schema documentation).

**Justification:** ANIMAL stores only the *current* enclosure, so every move must also be written to ANIMAL_TRANSFER. Doing both in one transaction, with the source taken from the database rather than the form, prevents inconsistent history.

---

### P07. Habitats and Enclosures

**Purpose:** Manage the zoo's places and see how full they are.

**Components:** Habitat cards or table (name, biome, climate, area, number of enclosures, number of animals), expandable enclosure list per habitat with an occupancy bar (animals / capacity) and condition badge, buttons: Add habitat, Add enclosure, Edit, "Set maintenance".

**Database:**
```sql
-- Habitat overview
SELECT h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm,
       COUNT(DISTINCT e.EnclosureID) AS Enclosures,
       COUNT(a.AnimalID)             AS Animals
FROM HABITAT h
LEFT JOIN ENCLOSURE e ON e.HabitatID   = h.HabitatID
LEFT JOIN ANIMAL a    ON a.EnclosureID = e.EnclosureID
WHERE h.ZooID = :zoo_id
GROUP BY h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm
ORDER BY h.Name;

-- Enclosures of one habitat with occupancy (Q3 style)
SELECT e.EnclosureID, e.Name, e.Capacity, e.Condition, e.LastMaintenance,
       COUNT(a.AnimalID) AS CurrentAnimals
FROM ENCLOSURE e
LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID
WHERE e.HabitatID = :habitat_id
GROUP BY e.EnclosureID, e.Name, e.Capacity, e.Condition, e.LastMaintenance
ORDER BY e.Name;

-- Animals inside an enclosure (when a row is expanded)
SELECT a.AnimalID, a.Name, s.CommonName
FROM ANIMAL a JOIN SPECIES s ON a.SpeciesID = s.SpeciesID
WHERE a.EnclosureID = :enclosure_id;

-- Enclosures needing maintenance (no maintenance in 180 days)
SELECT EnclosureID, Name, LastMaintenance
FROM ENCLOSURE
WHERE LastMaintenance IS NULL OR LastMaintenance < CURRENT_DATE - INTERVAL '180 days';

-- Commands
INSERT INTO HABITAT (ZooID, Name, BiomeType, Climate, AreaSqm) VALUES (:zoo_id, :name, :biome, :climate, :area);
UPDATE HABITAT SET Name = :name, BiomeType = :biome, Climate = :climate, AreaSqm = :area WHERE HabitatID = :habitat_id;
INSERT INTO ENCLOSURE (HabitatID, Name, Capacity, Condition, LastMaintenance) VALUES (:habitat_id, :name, :capacity, 'Good', NULL);
UPDATE ENCLOSURE SET Condition = :condition, LastMaintenance = :last_maintenance WHERE EnclosureID = :enclosure_id;
DELETE FROM ENCLOSURE WHERE EnclosureID = :enclosure_id;   -- fails (RESTRICT) if animals or transfers reference it
```

**Validation:** capacity above 0; cannot reduce capacity below current animal count (check before UPDATE).

**Justification:** The schema separates ecosystem zones from physical enclosures, so the page mirrors that two-level structure (habitat, then enclosures). The occupancy bar turns the capacity rule into a visual cue and supports transfer decisions.

---

### P08. Species and Conservation

**Purpose:** Maintain the species catalog and see conservation priorities.

**Components:** Species table (common name, scientific name, diet, lifespan, conservation badge, animals in zoo), filter by conservation status and diet, "Add species" form, "Endangered animals" tab.

**Database:**
```sql
-- Species list
SELECT s.SpeciesID, s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears,
       cs.Code, cs.Name AS Status, COUNT(a.AnimalID) AS AnimalsInZoo
FROM SPECIES s
JOIN CONSERVATION_STATUS cs ON s.StatusID = cs.StatusID
LEFT JOIN ANIMAL a          ON a.SpeciesID = s.SpeciesID AND a.HealthStatus <> 'Deceased'
GROUP BY s.SpeciesID, s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears, cs.Code, cs.Name
ORDER BY s.CommonName;

-- Status dropdown
SELECT StatusID, Code, Name FROM CONSERVATION_STATUS ORDER BY StatusID;

-- Endangered tab (Q10)
SELECT a.Name AS Animal, s.CommonName AS Species, cs.Name AS Status, e.Name AS Enclosure
FROM ANIMAL a
JOIN SPECIES s              ON a.SpeciesID = s.SpeciesID
JOIN CONSERVATION_STATUS cs ON s.StatusID  = cs.StatusID
LEFT JOIN ENCLOSURE e       ON a.EnclosureID = e.EnclosureID
WHERE cs.Code IN ('CR', 'EN') AND a.HealthStatus <> 'Deceased'
ORDER BY cs.Code, s.CommonName;

-- Commands
INSERT INTO SPECIES (StatusID, CommonName, ScientificName, DietType, AvgLifespanYears)
VALUES (:status_id, :common, :scientific, :diet, :lifespan);
UPDATE SPECIES SET StatusID = :status_id, CommonName = :common, DietType = :diet,
                   AvgLifespanYears = :lifespan WHERE SpeciesID = :species_id;
```

**Justification:** Species data is entered once and reused by every animal of that species (3NF). A dedicated page prevents duplicate species and gives conservation reporting a natural home.

---

### P09. Feeding Today (keeper worksheet)

**Purpose:** The keeper's daily task list: see what to feed and record it with one tap.

**Components:** Date header, progress bar (done / total), filter (my animals, habitat, time slot), checklist table with a **Mark fed** button per row, quick dialog (actual quantity, notes), status chips (Pending, Done, Late).

**Content:** Time, animal, enclosure, food, planned quantity, status, fed by, actual quantity.

**Database:**
```sql
-- Today's checklist (Q6 + Q7 combined)
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

-- "My animals" filter
--   add: AND a.AnimalID IN (SELECT AnimalID FROM CARE_ASSIGNMENT
--                           WHERE StaffID = :my_staff_id AND EndDate IS NULL)

-- Mark as fed
INSERT INTO FEEDING_LOG (PlanID, StaffID, FedAt, QuantityGiven, Notes)
VALUES (:plan_id, :my_staff_id, CURRENT_TIMESTAMP, :quantity_given, :notes);
```

**Validation:** a plan cannot be logged twice in the same time slot (the UI disables the button after the first log); quantity cannot be negative; notes are used for appetite or refusal.

**Justification:** Feeding happens many times a day, so this page is built for speed (one-tap logging). Comparing FEEDING_PLAN (what should happen) with FEEDING_LOG (what happened) gives accountability and feeds the dashboard's missed-feeding alert.

---

### P10. Feeding Plans

**Purpose:** Define and maintain each animal's diet.

**Components:** Animal selector, plan table (food, quantity, time, frequency), "Add food line" form, food dropdown filtered by the animal's diet type (for example, carnivores show Meat, Fish, Insect), warning if the food stock is low.

**Database:**
```sql
-- Plan for one animal
SELECT fp.PlanID, ft.Name AS Food, fp.QuantityPerMeal, ft.Unit, fp.FeedingTime, fp.Frequency
FROM FEEDING_PLAN fp JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID
WHERE fp.AnimalID = :animal_id ORDER BY fp.FeedingTime;

-- Food options (app maps DietType to allowed categories)
SELECT FoodID, Name, Category, Unit FROM FOOD_TYPE WHERE Category IN (:allowed_categories) ORDER BY Name;

-- Commands
INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
VALUES (:animal_id, :food_id, :qty, :time, :frequency);
UPDATE FEEDING_PLAN SET QuantityPerMeal = :qty, FeedingTime = :time, Frequency = :frequency
WHERE PlanID = :plan_id;
DELETE FROM FEEDING_PLAN WHERE PlanID = :plan_id;
-- fails (RESTRICT) if feeding logs exist; the UI then offers "Replace" (update) instead of "Delete"
```

**Justification:** Separating plan management from daily logging prevents keepers from changing diets by accident, and lets vets and lead keepers control nutrition. The delete restriction protects the feeding history.

---

### P11. Care Assignments

**Purpose:** Decide who looks after which animal, and balance the workload.

**Components:** Two panels: (left) keeper workload table with counts, (right) animals without a keeper; assign dialog (keeper, animal, responsibility), end-assignment button.

**Database:**
```sql
-- Workload (Q12)
SELECT st.StaffID, st.FirstName, st.LastName, COUNT(DISTINCT ca.AnimalID) AS AnimalsCaredFor
FROM STAFF st
LEFT JOIN CARE_ASSIGNMENT ca ON ca.StaffID = st.StaffID AND ca.EndDate IS NULL
WHERE st.Role = 'Keeper'
GROUP BY st.StaffID, st.FirstName, st.LastName
ORDER BY AnimalsCaredFor DESC;

-- Animals without an active keeper
SELECT a.AnimalID, a.Name, s.CommonName
FROM ANIMAL a JOIN SPECIES s ON a.SpeciesID = s.SpeciesID
WHERE a.HealthStatus <> 'Deceased'
  AND NOT EXISTS (SELECT 1 FROM CARE_ASSIGNMENT ca
                  WHERE ca.AnimalID = a.AnimalID AND ca.EndDate IS NULL);

-- Assign / end
INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (:staff_id, :animal_id, CURRENT_DATE, :responsibility);
UPDATE CARE_ASSIGNMENT SET EndDate = CURRENT_DATE WHERE AssignmentID = :assignment_id;
```

**Justification:** CARE_ASSIGNMENT is a many-to-many junction with dates. A dedicated screen shows both sides (people and animals), which makes unassigned animals and overloaded keepers obvious.

---

### P12. Veterinary Center

**Purpose:** The vet's workspace for preventive care and treatments.

**Components:** Tabs: **Due vaccines**, **Overdue checkups**, **Under treatment**, **New record**. Each list has a quick-action button ("Record vaccination", "Add checkup").

**Database:**
```sql
-- Due or overdue vaccines (improved Q4: ignores doses already replaced by a newer one)
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

-- Overdue checkups (Q5)
SELECT a.AnimalID, a.Name AS Animal, MAX(m.NextCheckup) AS NextCheckup
FROM ANIMAL a JOIN MEDICAL_RECORD m ON m.AnimalID = a.AnimalID
WHERE a.HealthStatus <> 'Deceased'
GROUP BY a.AnimalID, a.Name
HAVING MAX(m.NextCheckup) < CURRENT_DATE
ORDER BY NextCheckup;

-- Under treatment or quarantine
SELECT a.AnimalID, a.Name, a.HealthStatus, e.Name AS Enclosure
FROM ANIMAL a LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID
WHERE a.HealthStatus IN ('Under Treatment', 'Quarantine');

-- Commands (one transaction when the status changes)
BEGIN;
INSERT INTO MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup)
VALUES (:animal_id, :my_staff_id, CURRENT_DATE, :diagnosis, :treatment, :next_checkup);
UPDATE ANIMAL SET HealthStatus = :new_status WHERE AnimalID = :animal_id;
COMMIT;

INSERT INTO VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue)
VALUES (:animal_id, :my_staff_id, :vaccine, CURRENT_DATE, :next_due);
```

**Justification:** Veterinarians work from lists of things that need attention, not from individual animal pages. The page turns date columns (NextDue, NextCheckup) into a work queue, and the `VetID` is always the signed-in vet.

---

### P13. Food Inventory

**Purpose:** Track stock levels, expiry dates, and deliveries.

**Components:** Stock summary table with level indicator (OK, Low, Out), "Expiring soon" panel, purchase history table with date filter, "Record delivery" form, food type management (add or edit food).

**Database:**
```sql
-- Estimated stock (Q8)
SELECT ft.FoodID, ft.Name AS Food, ft.Unit,
       COALESCE(p.Purchased, 0) - COALESCE(c.Consumed, 0) AS EstimatedStock
FROM FOOD_TYPE ft
LEFT JOIN (SELECT FoodID, SUM(Quantity) AS Purchased FROM FOOD_STOCK GROUP BY FoodID) p
       ON p.FoodID = ft.FoodID
LEFT JOIN (SELECT fp.FoodID, SUM(fl.QuantityGiven) AS Consumed
           FROM FEEDING_LOG fl JOIN FEEDING_PLAN fp ON fl.PlanID = fp.PlanID
           GROUP BY fp.FoodID) c ON c.FoodID = ft.FoodID
ORDER BY EstimatedStock;

-- Expiring within 14 days (Q9)
SELECT ft.Name AS Food, fs.Quantity, fs.ExpiryDate, sp.Name AS Supplier
FROM FOOD_STOCK fs
JOIN FOOD_TYPE ft ON fs.FoodID = ft.FoodID
JOIN SUPPLIER sp  ON fs.SupplierID = sp.SupplierID
WHERE fs.ExpiryDate BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
ORDER BY fs.ExpiryDate;

-- Purchase history
SELECT fs.PurchaseDate, ft.Name AS Food, sp.Name AS Supplier, fs.Quantity, fs.UnitPrice,
       fs.Quantity * fs.UnitPrice AS Total, fs.ExpiryDate
FROM FOOD_STOCK fs
JOIN FOOD_TYPE ft ON fs.FoodID = ft.FoodID
JOIN SUPPLIER sp  ON fs.SupplierID = sp.SupplierID
WHERE fs.PurchaseDate BETWEEN :from AND :to
ORDER BY fs.PurchaseDate DESC;

-- Commands
INSERT INTO FOOD_STOCK (FoodID, SupplierID, Quantity, UnitPrice, PurchaseDate, ExpiryDate)
VALUES (:food_id, :supplier_id, :quantity, :unit_price, :purchase_date, :expiry_date);
INSERT INTO FOOD_TYPE (Name, Category, Unit, CaloriesPerUnit) VALUES (:name, :category, :unit, :calories);
UPDATE FOOD_TYPE SET Name = :name, Category = :category, Unit = :unit, CaloriesPerUnit = :calories
WHERE FoodID = :food_id;
```

**Justification:** Food is a recurring cost and a safety risk (expiry). The page combines purchases (FOOD_STOCK) with consumption (FEEDING_LOG) so managers see real stock, not just purchases. Recording deliveries is a simple insert, which keeps the audit trail of prices and suppliers.

---

### P14. Suppliers

**Purpose:** Keep supplier contacts and understand spending per supplier.

**Components:** Supplier table (name, contact, phone, total spent, last delivery), add/edit form, supplier detail with delivery history.

**Database:**
```sql
-- List with spending (Q15 extended)
SELECT sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone,
       COALESCE(SUM(fs.Quantity * fs.UnitPrice), 0) AS TotalSpent,
       MAX(fs.PurchaseDate) AS LastDelivery
FROM SUPPLIER sp
LEFT JOIN FOOD_STOCK fs ON fs.SupplierID = sp.SupplierID
GROUP BY sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone
ORDER BY TotalSpent DESC;

-- Commands
INSERT INTO SUPPLIER (Name, ContactPerson, Phone, Address) VALUES (:name, :contact, :phone, :address);
UPDATE SUPPLIER SET Name = :name, ContactPerson = :contact, Phone = :phone, Address = :address
WHERE SupplierID = :supplier_id;
```

**Justification:** Supplier data is managerial and price-sensitive, so it is separated from daily inventory work and shown only to managers.

---

### P15. Staff Directory and Profile

**Purpose:** Maintain employee records and the reporting hierarchy.

**Components:** Directory table with filters (department, role), search, "Add employee" form, profile page with tabs (Details, Assignments, Shifts, Subordinates), organization chart view.

**Database:**
```sql
-- Directory (Q13 extended)
SELECT s.StaffID, s.FirstName, s.LastName, s.Role, d.Name AS Department,
       m.FirstName || ' ' || m.LastName AS Supervisor, s.Phone, s.Email
FROM STAFF s
JOIN DEPARTMENT d  ON s.DepartmentID = d.DepartmentID
LEFT JOIN STAFF m  ON s.SupervisorID = m.StaffID
WHERE (:dept_id IS NULL OR s.DepartmentID = :dept_id)
  AND (:role    IS NULL OR s.Role = :role)
ORDER BY s.LastName;

-- Profile: current animals
SELECT a.AnimalID, a.Name, ca.Responsibility, ca.StartDate
FROM CARE_ASSIGNMENT ca JOIN ANIMAL a ON ca.AnimalID = a.AnimalID
WHERE ca.StaffID = :staff_id AND ca.EndDate IS NULL;

-- Profile: subordinates
SELECT StaffID, FirstName, LastName, Role FROM STAFF WHERE SupervisorID = :staff_id;

-- Commands
INSERT INTO STAFF (DepartmentID, SupervisorID, FirstName, LastName, Role, Phone, Email, HireDate, Salary)
VALUES (:dept_id, :supervisor_id, :first, :last, :role, :phone, :email, :hire_date, :salary);
UPDATE STAFF SET DepartmentID = :dept_id, SupervisorID = :supervisor_id, Role = :role,
                 Phone = :phone, Email = :email, Salary = :salary
WHERE StaffID = :staff_id;
```

**Validation:** email unique; salary not negative; a person cannot be their own supervisor (and, by trigger, not a subordinate's subordinate).

**Justification:** STAFF is referenced by seven relationships, so one authoritative page for people avoids duplicated or inconsistent employee data. Deletion is blocked once an employee has history (RESTRICT); a future `IsActive` column is recommended for leavers. Salary is visible to managers only.

---

### P16. Shift Schedule

**Purpose:** Plan who works when.

**Components:** Weekly calendar grid (days as columns, staff as rows or time slots), filters (department, role), "Add shift" dialog, conflict warning, "Copy last week" button.

**Database:**
```sql
-- Week view
SELECT ss.ShiftID, ss.ShiftDate, ss.StartTime, ss.EndTime,
       st.StaffID, st.FirstName, st.LastName, st.Role
FROM STAFF_SHIFT ss JOIN STAFF st ON ss.StaffID = st.StaffID
WHERE ss.ShiftDate BETWEEN :week_start AND :week_end
  AND (:dept_id IS NULL OR st.DepartmentID = :dept_id)
ORDER BY ss.ShiftDate, ss.StartTime, st.LastName;

-- Overlap check before inserting
SELECT 1 FROM STAFF_SHIFT
WHERE StaffID = :staff_id AND ShiftDate = :date
  AND StartTime < :end_time AND EndTime > :start_time;

-- Commands
INSERT INTO STAFF_SHIFT (StaffID, ShiftDate, StartTime, EndTime) VALUES (:staff_id, :date, :start, :end);
UPDATE STAFF_SHIFT SET StartTime = :start, EndTime = :end WHERE ShiftID = :shift_id;
DELETE FROM STAFF_SHIFT WHERE ShiftID = :shift_id;

-- Copy last week
INSERT INTO STAFF_SHIFT (StaffID, ShiftDate, StartTime, EndTime)
SELECT StaffID, ShiftDate + INTERVAL '7 days', StartTime, EndTime
FROM STAFF_SHIFT WHERE ShiftDate BETWEEN :last_week_start AND :last_week_end;
```

**Justification:** Schedules are naturally visual (a calendar). Shifts are the one place where deleting is safe (CASCADE from STAFF), because they are planning data rather than history.

---

### P17. Ticketing (Point of Sale)

**Purpose:** A fast, single-screen tool for cashiers to sell tickets.

**Components:** Ticket type buttons (name and price), quantity stepper, visit date picker (default today), running total, "Sell" button, today's sales list with totals, receipt view.

**Database:**
```sql
-- Ticket types
SELECT TicketTypeID, Name, Price, Description FROM TICKET_TYPE ORDER BY Price DESC;

-- Sell (price is read from the database, never trusted from the browser)
INSERT INTO TICKET (TicketTypeID, SoldByStaffID, VisitDate, Quantity, TotalPrice)
SELECT :ticket_type_id, :my_staff_id, :visit_date, :quantity, :quantity * Price
FROM TICKET_TYPE WHERE TicketTypeID = :ticket_type_id
RETURNING TicketID, TotalPrice;

-- Today's sales (this cashier)
SELECT t.TicketID, t.PurchasedAt, tt.Name, t.Quantity, t.TotalPrice
FROM TICKET t JOIN TICKET_TYPE tt ON t.TicketTypeID = tt.TicketTypeID
WHERE t.SoldByStaffID = :my_staff_id AND CAST(t.PurchasedAt AS DATE) = CURRENT_DATE
ORDER BY t.PurchasedAt DESC;
```

**Justification:** Cashiers need speed and no distractions, so the page contains only sales. Calculating `TotalPrice` in the SQL from the current price prevents tampering and keeps the stored amount correct even if prices change later. There is no delete: refunds should be modeled as an extension (for example, a negative or "refunded" status) to keep a clean audit trail.

---

### P18. Reports

**Purpose:** Management analytics with date filters and export (CSV or PDF).

| Report | Chart / table | Query |
|---|---|---|
| Visitors and revenue by day | Line chart | Q14 with `WHERE VisitDate BETWEEN :from AND :to` |
| Revenue by ticket type | Pie or bar | `SELECT tt.Name, SUM(t.Quantity) AS Sold, SUM(t.TotalPrice) AS Revenue FROM TICKET t JOIN TICKET_TYPE tt ON t.TicketTypeID = tt.TicketTypeID WHERE t.VisitDate BETWEEN :from AND :to GROUP BY tt.Name;` |
| Food spending per supplier | Bar | Q15 with a date filter |
| Food consumption per food | Bar | `SELECT ft.Name, SUM(fl.QuantityGiven) AS Consumed FROM FEEDING_LOG fl JOIN FEEDING_PLAN fp ON fl.PlanID = fp.PlanID JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID WHERE CAST(fl.FedAt AS DATE) BETWEEN :from AND :to GROUP BY ft.Name ORDER BY Consumed DESC;` |
| Animals per habitat | Bar | `SELECT h.Name, COUNT(a.AnimalID) FROM HABITAT h LEFT JOIN ENCLOSURE e ON e.HabitatID = h.HabitatID LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID GROUP BY h.Name;` |
| Species by conservation status | Donut | `SELECT cs.Name, COUNT(DISTINCT s.SpeciesID) FROM CONSERVATION_STATUS cs LEFT JOIN SPECIES s ON s.StatusID = cs.StatusID GROUP BY cs.Name;` |
| Keeper workload | Table | Q12 |
| Feeding compliance (planned vs logged) | Table | `SELECT CAST(fl.FedAt AS DATE) AS Day, COUNT(*) AS Logged FROM FEEDING_LOG fl WHERE CAST(fl.FedAt AS DATE) BETWEEN :from AND :to GROUP BY 1 ORDER BY 1;` compared with the number of active plans |

**Components:** Report picker, date range, chart area, data table, Export button.

**Justification:** Reports use aggregate queries (`GROUP BY`) over existing tables, so they need no extra storage. They demonstrate the value of the schema: all links between tables make these questions answerable.

---

### P19. Admin Settings

**Purpose:** Maintain lookup and configuration data that other pages rely on.

**Components:** Tabs: **Zoo info**, **Departments**, **Ticket types**, **Conservation statuses**, **Food types**.

**Database:**
```sql
-- Zoo info
SELECT * FROM ZOO WHERE ZooID = :zoo_id;
UPDATE ZOO SET Name = :name, City = :city, Address = :address, Phone = :phone WHERE ZooID = :zoo_id;

-- Departments
SELECT d.DepartmentID, d.Name, d.Description, COUNT(s.StaffID) AS Employees
FROM DEPARTMENT d LEFT JOIN STAFF s ON s.DepartmentID = d.DepartmentID
WHERE d.ZooID = :zoo_id GROUP BY d.DepartmentID, d.Name, d.Description;
INSERT INTO DEPARTMENT (ZooID, Name, Description) VALUES (:zoo_id, :name, :description);

-- Ticket types
INSERT INTO TICKET_TYPE (Name, Price, Description) VALUES (:name, :price, :description);
UPDATE TICKET_TYPE SET Price = :price, Description = :description WHERE TicketTypeID = :id;
-- price changes affect only future sales; old TICKET rows keep their TotalPrice

-- Conservation statuses
INSERT INTO CONSERVATION_STATUS (Code, Name, Description) VALUES (:code, :name, :description);
UPDATE CONSERVATION_STATUS SET Name = :name, Description = :description WHERE StatusID = :id;
```

**Justification:** Lookup tables are rarely changed but control dropdowns across the whole app. Keeping them in one admin-only area avoids accidental edits and keeps the data consistent.

---

## 5. Page-to-Table Matrix

R = reads, W = writes (INSERT / UPDATE / DELETE).

| Table | P02 | P03 | P04 | P05 | P06 | P07 | P08 | P09 | P10 | P11 | P12 | P13 | P14 | P15 | P16 | P17 | P18 | P19 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ZOO | | | | | | R | | | | | | | | | | | | R/W |
| DEPARTMENT | | | | | | | | | | | | | | R | R | | | R/W |
| STAFF | R | | R | R | | | | R | | R | R | | | R/W | R | R | R | |
| STAFF_SHIFT | R | | | | | | | | | | | | | R | R/W | | | |
| HABITAT | | R | R | | | R/W | | | | | | | | | | | R | |
| ENCLOSURE | R | R | R | R | R | R/W | R | R | | | R | | | | | | R | |
| CONSERVATION_STATUS | | | R | | | | R | | | | | | | | | | R | R/W |
| SPECIES | | R | R | R | | | R/W | | R | R | | | | | | | R | |
| ANIMAL | R | R | R | R/W | R/W | R | R | R | R | R | R/W | | | | | | R | |
| ANIMAL_TRANSFER | | | R | | W | | | | | | | | | | | | | |
| CARE_ASSIGNMENT | | | R/W | W | | | | R | | R/W | | | | R | | | R | |
| MEDICAL_RECORD | R | | R | W | | | | | | | R/W | | | | | | | |
| VACCINATION | R | | R | W | | | | | | | R/W | | | | | | | |
| FOOD_TYPE | | | R | R | | | | R | R | | | R/W | | | | | R | |
| SUPPLIER | | | | | | | | | | | | R | R/W | | | | R | |
| FOOD_STOCK | R | | | | | | | | R | | | R/W | R | | | | R | |
| FEEDING_PLAN | R | | R | W | | | | R | R/W | | | R | | | | | R | |
| FEEDING_LOG | R | | R | | | | | R/W | | | | R | | | | | R | |
| TICKET_TYPE | | | | | | | | | | | | | | | | R | R | R/W |
| TICKET | R | | | | | | | | | | | | | | | R/W | R | |

**Justification:** Every one of the 20 tables is written by at least one page and read by at least one other, which confirms that no table is unused and that the schema supports the whole application.

---

## 6. Cross-Cutting Rules

### 6.1 Transactions (multi-table actions)

| Action | Tables changed in one transaction |
|---|---|
| Register animal (P05) | ANIMAL, MEDICAL_RECORD, VACCINATION, CARE_ASSIGNMENT, FEEDING_PLAN |
| Transfer animal (P06) | ANIMAL_TRANSFER, ANIMAL |
| Mark deceased (P05) | ANIMAL, CARE_ASSIGNMENT |
| Checkup with status change (P12) | MEDICAL_RECORD, ANIMAL |

### 6.2 Mapping database errors to friendly messages

| Database error | Message shown |
|---|---|
| UNIQUE violation on `STAFF.Email` | "This email is already registered." |
| UNIQUE violation on `SPECIES.ScientificName` | "This species already exists." |
| CHECK violation on dates | "End date must be after start date." |
| FOREIGN KEY violation on delete (RESTRICT) | "This record is used elsewhere and cannot be deleted." |
| Capacity trigger | "This enclosure is full." |
| CHECK `Capacity > 0` | "Capacity must be at least 1." |

### 6.3 Security and quality

- Use **parameterized queries** everywhere (prevents SQL injection).
- Check **role permissions on the server**, not only by hiding buttons.
- Hash passwords; never store them in plain text.
- Use **pagination** for lists (animals, logs, tickets) and **indexes** on columns used in filters and joins: `ANIMAL(SpeciesID)`, `ANIMAL(EnclosureID)`, `FEEDING_LOG(PlanID, FedAt)`, `VACCINATION(NextDue)`, `TICKET(VisitDate)`, `STAFF_SHIFT(ShiftDate)`.
- Show **loading, empty, and error states** on every list.
- Make pages **responsive**: P09 (feeding) and P17 (ticketing) are used on tablets or phones.

---

## 7. Suggested Build Order

| Phase | Pages | Reason |
|---|---|---|
| 1. Foundation | P01, P19, P15 | Login, lookup data, and staff are needed by everything else |
| 2. Core data | P08, P07, P03, P05, P04 | Species, places, and animals: the heart of the system |
| 3. Daily operations | P10, P09, P11, P06 | Feeding and care workflows |
| 4. Health and supplies | P12, P13, P14 | Vet queues and inventory |
| 5. Visitors and scheduling | P17, P16 | Revenue and staffing |
| 6. Insight | P18, P02 | Dashboard and reports are built last because they reuse queries from earlier pages |

**Justification:** The order follows data dependencies (a feeding plan needs animals and food types; an animal needs species and enclosures) and builds the most valuable, demonstrable features early.

---

*End of document.*
