# 3.C Physical Design

**Goal:** Implement the logical schema for a **selected DBMS**—tables, columns with SQL types, primary/foreign keys, and check constraints as executable DDL. Physical design also considers how the database will be stored and accessed (file/table structures as defined by the DBMS).

---

## 3.C.1 DBMS Choice

| Item | Choice for this project |
|---|---|
| **DBMS** | **Microsoft SQL Server** (Express is sufficient for development/demo) |
| **Dialect** | **T-SQL** |
| **Client integration** | Python desktop app via **ODBC** (`pyodbc`) |
| **Official script** | [`../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql`](../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql) |

Physical decisions reflected in the script include:

- `CREATE DATABASE ZooDB` and ordered `CREATE TABLE` statements respecting foreign-key dependencies  
- `INT IDENTITY(1,1)` primary keys  
- `NVARCHAR` / `DECIMAL` / `DATE` / `TIME` / `DATETIME2` column types  
- `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` constraints  
- `ON DELETE CASCADE` where appropriate (e.g. staff shifts)  
- Sample seed data for demonstration logins and day-to-day screens  
- Application support column `STAFF.PasswordHash` (hashed credentials for login)

---

## 3.C.2 From Logical to Physical

| Logical | Physical (SQL Server) |
|---|---|
| Relation | `CREATE TABLE` |
| Column + domain | Typed column (`NVARCHAR(100)`, `DECIMAL(10,2)`, …) |
| Surrogate key | `INT IDENTITY(1,1) PRIMARY KEY` |
| Foreign key | `FOREIGN KEY ... REFERENCES ...` |
| Business rule | `CHECK (...)` / `UNIQUE (...)` |
| Conceptual/logical ER | **Physical ER** (crow’s-foot tables with attributes) |

---

## 3.C.3 Physical Artifacts

| Artifact | Location |
|---|---|
| T-SQL DDL + seed (all 20 tables) | [`../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql`](../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql) |
| Physical ER diagram | [`physical_er_diagram.md`](physical_er_diagram.md) |
| Full data dictionary & examples | [`../../../zoo_database_documentation.md`](../../../zoo_database_documentation.md) §3–§8 |
| Desktop app (integration) | [`../../../ZooManagementSystem_Desktop/ZooManagementSystem/`](../../../ZooManagementSystem_Desktop/ZooManagementSystem/) |

---

## 3.C.4 Implementation Order (as in SQL script)

Tables are created from independent / parent tables toward dependents, for example:

1. ZOO → DEPARTMENT → STAFF → STAFF_SHIFT  
2. HABITAT → ENCLOSURE  
3. CONSERVATION_STATUS → SPECIES → ANIMAL → ANIMAL_TRANSFER  
4. FOOD_TYPE, SUPPLIER → FOOD_STOCK → FEEDING_PLAN → FEEDING_LOG  
5. CARE_ASSIGNMENT, MEDICAL_RECORD, VACCINATION  
6. TICKET_TYPE → TICKET  

---

## 3.C.5 Physical ER Diagram

The physical diagram shows **tables as boxes**, **columns with types**, **PK/FK markers**, and **crow’s-foot** relationship lines.  
It corresponds to Section 3 of the schema documentation and is copied for the report here:

> [`physical_er_diagram.md`](physical_er_diagram.md)

---

## 3.C.6 How to Load the Database (demo)

1. Install **Microsoft SQL Server** and connect with **SSMS**.  
2. Open `ZooDB_FULL.sql`, click in the script, press **F5** (creates `ZooDB`, 20 tables, sample data).  
3. Point the desktop app’s `zoo_settings.ini` `server` value at the same instance (default `.\SQLEXPRESS`).  
4. Run the Tkinter application; it connects through ODBC and performs parameterized DML and multi-statement **transactions**.

---

## 3.C.7 Outcomes

- [x] Logical schema implemented as **Microsoft SQL Server** T-SQL (`ZooDB_FULL.sql`)  
- [x] Physical ER diagram produced (tables + attributes + crow’s foot)  
- [x] Constraints enforced at the DBMS level  
- [x] Sample seed data included for a live demo  
- [x] Database integrated with the Python / Tkinter desktop system  

**End of Design phase** for this course report. The physical schema is the same database used by the integrated desktop application.
