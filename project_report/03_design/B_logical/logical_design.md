# 3.B Logical Design

**Goal:** Map the conceptual model to a **relational data model**: tables, attributes, keys, and relationships—**DBMS-independent** in principle (no storage files, indexes, or vendor-only features required at this step).

---

## 3.B.1 From Conceptual to Logical

| Conceptual | Logical (relational) |
|---|---|
| Entity | Relation (table) |
| Attribute | Column |
| Identifying attribute | Primary key |
| Relationship 1:N | Foreign key on the “N” side |
| Relationship M:N | Associative table (or entity that already held relationship attributes) |
| Business constraint | CHECK / UNIQUE / NOT NULL rules (stated logically) |

In this project, many M:N relationships were already conceptualized as entities with attributes (Care Assignment, Feeding Plan, Food Stock), so they map **1:1** to tables.

---

## 3.B.2 Identified Tables (20)

| # | Table | Source entity / role |
|---|---|---|
| 1 | ZOO | Zoo |
| 2 | DEPARTMENT | Department |
| 3 | STAFF | Staff (+ supervises self-FK) |
| 4 | STAFF_SHIFT | Staff Shift |
| 5 | HABITAT | Habitat |
| 6 | ENCLOSURE | Enclosure |
| 7 | CONSERVATION_STATUS | Conservation Status |
| 8 | SPECIES | Species |
| 9 | ANIMAL | Animal |
| 10 | ANIMAL_TRANSFER | Animal Transfer |
| 11 | CARE_ASSIGNMENT | Care Assignment (Staff ↔ Animal) |
| 12 | MEDICAL_RECORD | Medical Record |
| 13 | VACCINATION | Vaccination |
| 14 | FOOD_TYPE | Food Type |
| 15 | SUPPLIER | Supplier |
| 16 | FOOD_STOCK | Food Stock (Supplier ↔ Food Type) |
| 17 | FEEDING_PLAN | Feeding Plan (Animal ↔ Food Type) |
| 18 | FEEDING_LOG | Feeding Log |
| 19 | TICKET_TYPE | Ticket Type |
| 20 | TICKET | Ticket |

---

## 3.B.3 Design Choices Emphasized in Logical Design

1. **Catalog vs instance** — SPECIES vs ANIMAL; FOOD_TYPE vs FEEDING_PLAN; TICKET_TYPE vs TICKET.  
2. **Plan vs event** — FEEDING_PLAN vs FEEDING_LOG.  
3. **History kept** — ANIMAL_TRANSFER, CARE_ASSIGNMENT date ranges, medical/vaccination records.  
4. **Normalization** — Target **3NF** to remove redundant repeating groups and transitive dependencies.  
5. **Integrity** — Primary keys, foreign keys, UNIQUE pairs, and CHECK rules documented for each table.

---

## 3.B.4 Main Deliverable: Schema Documentation

The complete logical (and descriptive) documentation—purpose of each table, data dictionary, relationships, constraints, normalization notes, example queries—is maintained in:

> **[`../../../zoo_database_documentation.md`](../../../zoo_database_documentation.md)**

That document was completed in this phase as the written record of:

- Identified tables  
- Relationships between tables  
- Column-level definitions and constraints  
- Business rules and normalization notes  

---

## 3.B.5 Relationship Summary (Logical)

See also Section 5 of the schema documentation. High-level groups:

- **Organization:** ZOO → DEPARTMENT → STAFF → STAFF_SHIFT; STAFF → STAFF (supervisor)  
- **Places:** ZOO → HABITAT → ENCLOSURE → ANIMAL  
- **Animals:** CONSERVATION_STATUS → SPECIES → ANIMAL; ANIMAL → ANIMAL_TRANSFER  
- **Care:** STAFF / ANIMAL → CARE_ASSIGNMENT, MEDICAL_RECORD, VACCINATION  
- **Food:** FOOD_TYPE / SUPPLIER → FOOD_STOCK; ANIMAL / FOOD_TYPE → FEEDING_PLAN → FEEDING_LOG  
- **Visitors:** TICKET_TYPE → TICKET; STAFF → TICKET  

---

## 3.B.6 Outcomes

- [x] Tables identified from conceptual entities  
- [x] Keys and relationships defined  
- [x] Normalization to 3NF documented  
- [x] Full documentation completed (`zoo_database_documentation.md`)  

**Next:** Physical Design implements this schema in SQL and presents the **physical ER diagram** (tables with typed attributes and crow’s-foot notation).
