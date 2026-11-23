# Zoo Management System — Remaining Work Plan (Pre-Submission)
1234567890
**Course:** SEN22321E Database System Design  
**DBMS:** Microsoft SQL Server (T-SQL)  
**Application:** Python + Tkinter + `pyodbc`  
**Goal:** Finish required deliverables for a single PDF report + working integrated system.

**Out of scope:** nice-to-haves (indexes polish, bcrypt, extra seed volume, dashboard, etc.).

---

## 0. Current baseline

| Area | Status |
|---|---|
| 20 tables, constraints, seed (`ZooDB_FULL.sql`) | Done |
| Conceptual / logical / physical design docs | Done |
| ER diagram PNG images added | Done (not yet embedded in report markdown) |
| Desktop app screens + app-level transactions | Done |
| SQL Server **views** | Missing |
| SQL Server **stored procedures** | Missing |
| SQL Server **functions** | Missing |
| **Database-level transactions** (`BEGIN TRANSACTION` in T-SQL) | Missing (only Python `db.transaction()` today) |
| Report chapter mapping objects → where used | Missing |
| Single PDF assembly | Missing |

---

## 1. Phase plan (order of work)

```
Phase 1  SQL objects (views, functions, procedures with DB transactions)
Phase 2  Wire desktop app to call those objects
Phase 3  Report: embed ER images + document objects & where implemented
Phase 4  Integration chapter + screenshots + run instructions
Phase 5  Assemble one PDF + final checklist
```

---

## 2. Phase 1 — Database objects (SQL Server)

**Deliverable location:** extend  
`ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql`  
**(or)** add companion scripts run after it, e.g. `ZooDB_Objects.sql`, then reference both in the report.

### 2.1 Views

| # | Object | Purpose | Intended consumer |
|---|---|---|---|
| V1 | `vw_AnimalDirectory` | Animal + species + enclosure + habitat | Animals list |
| V2 | `vw_FeedingToday` | Feeding plan vs today’s log status | Feeding Today |
| V3 | `vw_VaccinesDue` | Vaccinations with upcoming / due dates | Veterinary Center |
| V4 | `vw_FoodStockEstimate` | Purchased − consumed per food type | Food Inventory |
| V5 | `vw_TicketSalesToday` | Today’s ticket sales with type + cashier | Ticketing |

**Implementation notes:**
- Use `CREATE OR ALTER VIEW` (or `DROP` + `CREATE`) in T-SQL.
- Prefer `CAST(GETDATE() AS DATE)` for “today” filters where needed.
- Keep column names stable so the Tkinter tables can bind easily.

**Done when:** all five views exist in `ZooDB` and `SELECT TOP 5 * FROM <view>` works in SSMS.

---

### 2.2 Functions

| # | Object | Type | Purpose |
|---|---|---|---|
| F1 | `fn_EnclosureFreeSpaces(@EnclosureID INT)` | scalar `INT` | `Capacity −` count of living animals in enclosure |
| F2 | `fn_TicketLineTotal(@TicketTypeID INT, @Quantity INT)` | scalar `DECIMAL(10,2)` | `Price × Quantity` from `TICKET_TYPE` |
| F3 | `fn_IsFedToday(@PlanID INT)` | scalar `BIT` | `1` if a `FEEDING_LOG` exists for that plan today |

**Implementation notes:**
- Use `CREATE OR ALTER FUNCTION` with `RETURNS ... AS BEGIN ... END`.
- Schema-qualify as `dbo.fn_...`.
- Functions are used by procedures and/or app checks (and mentioned in the report).

**Done when:** functions compile and return correct values for seeded data in SSMS.

---

### 2.3 Stored procedures with **database-level transactions**

Each procedure that changes more than one table (or must enforce an all-or-nothing business action) must use:

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    -- statements
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
```

| # | Procedure | Tables / logic | DB transaction required |
|---|---|---|---|
| P1 | `usp_TransferAnimal` | `INSERT ANIMAL_TRANSFER` + `UPDATE ANIMAL.EnclosureID`; validate free space via `fn_EnclosureFreeSpaces`; From ≠ To | **Yes** |
| P2 | `usp_MarkAnimalDeceased` | `UPDATE ANIMAL` health + `UPDATE CARE_ASSIGNMENT` end open rows | **Yes** |
| P3 | `usp_RegisterCheckup` | `INSERT MEDICAL_RECORD` + optional `UPDATE ANIMAL.HealthStatus` | **Yes** |
| P4 | `usp_SellTicket` | Read price / use `fn_TicketLineTotal`; `INSERT TICKET` | Yes (single logical sale; keep in proc for consistency) |
| P5 | `usp_LogFeeding` | Guard with `fn_IsFedToday`; `INSERT FEEDING_LOG` | Yes (reject double-log cleanly) |

**Optional single-statement helpers (still procedures, transaction optional):**  
only add if needed for symmetry; core submission = **P1–P5**.

**Implementation notes:**
- Parameters mirror what the UI already collects (IDs, dates, reason, etc.).
- Raise clear errors (`THROW` / `RAISERROR`) for business rule failures (no free space, already fed, etc.).
- Application may still open a connection and call `EXEC usp_...`; the **commit/rollback authority for multi-table writes lives in SQL Server**.

**Done when:** each proc runs successfully in SSMS on seed data; forced failure path rolls back (no partial writes).

---

## 3. Phase 2 — Wire the desktop application

**Goal:** the running system actually uses the new DB objects (not only “SQL exists unused”).

| # | Task | How |
|---|---|---|
| A1 | Animals list reads `vw_AnimalDirectory` | Update `ui/screens/animals.py` list query |
| A2 | Feeding Today reads `vw_FeedingToday` | Update `ui/screens/feeding.py` |
| A3 | Vet queues use `vw_VaccinesDue` (and related queries as fit) | Update `ui/screens/vet.py` |
| A4 | Inventory stock uses `vw_FoodStockEstimate` | Update `ui/screens/inventory.py` |
| A5 | Ticketing today list uses `vw_TicketSalesToday` | Update `ui/screens/ticketing.py` |
| A6 | Transfer / deceased call `usp_TransferAnimal` / `usp_MarkAnimalDeceased` | Replace multi-statement Python blocks in `animals.py` with `EXEC` |
| A7 | Checkup calls `usp_RegisterCheckup` | Replace transaction block in `vet.py` |
| A8 | Sell ticket calls `usp_SellTicket` | Update `ticketing.py` |
| A9 | Mark fed calls `usp_LogFeeding` | Update `feeding.py` |
| A10 | Helper in `db.py` | Add thin `exec_proc(name, params)` (and optionally `query_view`) so screens share one call style |

**Transaction policy after wiring:**
- Multi-table business actions → **stored procedure DB transactions** (primary).
- Python `db.transaction()` may remain for simple single-statement helpers, but report emphasis is on **T-SQL transactions inside procedures**.

**Done when:** full demo path works: login → transfer animal → mark fed → checkup → sell ticket, against SQL Server using views/procs.

---

## 4. Phase 3 — Report updates (for the final PDF)

### 4.1 Embed ER diagram images

| # | Task | File |
|---|---|---|
| R1 | Insert conceptual figures with captions | `project_report/03_design/A_conceptual/conceptual_er_diagram.md` ← `diagram1-cardinality.png`, `diagram2-attributes.png` |
| R2 | Insert physical figure with caption | `project_report/03_design/C_physical/physical_er_diagram.md` ← `mermaid-diagram-2026-11-23-175710.png` |

Keep Mermaid source as appendix/optional; **PDF must show the PNGs**.

### 4.2 New section: Database programming objects + where implemented

Add under Design, e.g.  
`project_report/03_design/D_database_objects/database_objects.md`  
(and link it from `03_design/README.md` + cover structure).

Required tables in that section:

#### Views — where implemented

| View | Purpose | Implemented in |
|---|---|---|
| `vw_...` | … | SQL: `ZooDB_….sql` · App: `ui/screens/….py` · Screen: … |

#### Functions — where implemented

| Function | Purpose | Implemented in |
|---|---|---|
| `fn_...` | … | SQL: … · Used by: procedure / screen … |

#### Stored procedures — where implemented

| Procedure | Purpose | DB transaction | Implemented in |
|---|---|---|---|
| `usp_...` | … | Yes (BEGIN/COMMIT/ROLLBACK) | SQL: … · App: … · UI action: … |

#### Transactions — inventory

| Business action | Tables | DB-level transaction location | UI trigger |
|---|---|---|---|
| Transfer animal | `ANIMAL_TRANSFER`, `ANIMAL` | `usp_TransferAnimal` | Animal Detail → Transfer |
| Mark deceased | `ANIMAL`, `CARE_ASSIGNMENT` | `usp_MarkAnimalDeceased` | Animal Detail → Mark deceased |
| Register checkup | `MEDICAL_RECORD`, `ANIMAL` | `usp_RegisterCheckup` | Veterinary → New checkup |
| Sell ticket | `TICKET` (+ read `TICKET_TYPE`) | `usp_SellTicket` | Ticketing → Sell |
| Log feeding | `FEEDING_LOG` | `usp_LogFeeding` | Feeding Today → Mark fed |

Include short T-SQL snippets (not full script dump) for one view, one function, one procedure showing `BEGIN TRANSACTION`.

**Done when:** a reader of the PDF can answer “where is X implemented?” without opening the repo blindly.

---

## 5. Phase 4 — Implementation / integration chapter

Add a short report chapter (or extend physical design) covering:

| # | Content |
|---|---|
| I1 | Architecture diagram/text: Tkinter → `pyodbc` → SQL Server `ZooDB` |
| I2 | How to create DB: SSMS + `ZooDB_FULL.sql` (+ objects script if separate) |
| I3 | How to run app: `zoo_settings.ini`, `pip install -r requirements.txt`, `py main.py` |
| I4 | Demo accounts table |
| I5 | Screenshots: Login + Animals/Transfer + Feeding + Vet + Ticketing (enough to prove integration) |

**Done when:** a classmate can recreate the demo from the PDF + attached SQL/app folder.

---

## 6. Phase 5 — Submission packaging

| # | Task |
|---|---|
| S1 | Cover page: course code, instructor, date, three student names/IDs (already partially done) |
| S2 | Short team contribution note (who owned design / SQL objects / UI) |
| S3 | Confirm report narrative uses **Microsoft SQL Server** + `ZooDB_FULL.sql` only (deprecated root `Zoo_Database.sql` not presented as official) |
| S4 | Export **one PDF** in this order: Cover → Planning → Analysis → Conceptual (+ images) → Logical → Physical (+ image) → Database objects (views/functions/procs/transactions) → Implementation (+ screenshots) → Appendix (SQL script reference) |
| S5 | Zip for upload: PDF + `database/*.sql` + `app/` (or whole desktop project) |

**PDF build tip:** paste Markdown into Word or use Pandoc; ensure PNG figures render; avoid relying on Mermaid live rendering inside the PDF.

---

## 7. Definition of done (submission-ready)

- [ ] Views V1–V5 created on SQL Server  
- [ ] Functions F1–F3 created on SQL Server  
- [ ] Procedures P1–P5 created with **DB-level** `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`  
- [ ] Desktop app reads views and calls procedures for the listed screens/actions  
- [ ] Report embeds conceptual + physical ER PNGs  
- [ ] Report documents each view/function/procedure/transaction and **where implemented**  
- [ ] Integration/run instructions + screenshots in report  
- [ ] Single PDF + SQL/app package ready to submit  

---

## 8. Suggested team split (3 students)

| Owner | Owns |
|---|---|
| Student A | Phase 1 SQL (views, functions, procedures + DB transactions) + SSMS verification |
| Student B | Phase 2 app wiring (`db.py` + screens) + end-to-end demo |
| Student C | Phases 3–5 report (images, objects chapter, screenshots, PDF assembly) |

All three review the final PDF and demo once together before submission.
