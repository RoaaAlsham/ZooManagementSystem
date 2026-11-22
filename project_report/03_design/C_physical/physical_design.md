# 3.C Physical Design

**Goal:** Implement the logical schema for a **selected DBMS**—tables, columns with SQL types, primary/foreign keys, and check constraints as executable DDL. Physical design also considers how the database will be stored and accessed (file/table structures as defined by the DBMS).

---

## 3.C.1 DBMS Choice

| Item | Choice for this project |
|---|---|
| Dialect of examples | **PostgreSQL-style** SQL |
| Portability | Notes where MySQL / SQL Server differ (documented in schema docs) |
| Script | [`../../../Zoo_Database.sql`](../../../Zoo_Database.sql) |

Physical decisions reflected in the script include:

- Explicit `CREATE TABLE` order respecting foreign-key dependencies  
- `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` constraints  
- `ON DELETE` behavior where appropriate (e.g. cascade on shifts)  
- SQL data types (`INT`, `VARCHAR(n)`, `DECIMAL`, `DATE`, `TIME`, `TIMESTAMP`)

---

## 3.C.2 From Logical to Physical

| Logical | Physical |
|---|---|
| Relation | `CREATE TABLE` |
| Column + domain | Typed column (`VARCHAR(100)`, `DECIMAL(10,2)`, …) |
| Primary key | `PRIMARY KEY` |
| Foreign key | `FOREIGN KEY ... REFERENCES ...` |
| Business rule | `CHECK (...)` / `UNIQUE (...)` |
| Conceptual/logical ER | **Physical ER** (crow’s-foot tables with attributes) |

---

## 3.C.3 Physical Artifacts

| Artifact | Location |
|---|---|
| SQL DDL (create all 20 tables) | [`../../../Zoo_Database.sql`](../../../Zoo_Database.sql) |
| Physical ER diagram | [`physical_er_diagram.md`](physical_er_diagram.md) |
| Full data dictionary & examples | [`../../../zoo_database_documentation.md`](../../../zoo_database_documentation.md) §3–§8 |

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

## 3.C.6 Outcomes

- [x] Logical schema implemented as `Zoo_Database.sql`  
- [x] Physical ER diagram produced (tables + attributes + crow’s foot)  
- [x] Constraints enforced at the DBMS level  
- [ ] Optional later: indexes, views, sample seed data, performance notes  

**End of Design phase** for this course report. Implementation of the application UI (from Analysis) can follow using this physical schema.
