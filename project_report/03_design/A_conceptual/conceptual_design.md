# 3.A Conceptual Design

**Goal:** Give a concise description of the **data**, **data meaning**, **relationships**, and **constraints**—with **no** implementation or physical detail (no SQL types, no indexes, no DBMS).

This phase structures all information requirements collected in Analysis into a technology-independent model.

---

## 3.A.1 What Conceptual Design Includes

| Element | In this project |
|---|---|
| Entities | Real-world things the zoo cares about (Animal, Staff, Enclosure, …) |
| Attributes | Properties of entities (Animal Name, Hire Date, …) — names only |
| Relationships | Associations (Staff *cares for* Animal; Enclosure *houses* Animal) |
| Cardinality | 1:1, 1:N, M:N where needed |
| Constraints | Business rules (e.g. transfer from ≠ to; end date ≥ start date) |

**What it excludes:** primary/foreign key column names as implementation, data types (`INT`, `VARCHAR`), storage, indexes, DBMS dialect.

---

## 3.A.2 Entity Groups (from Analysis)

| Group | Entities |
|---|---|
| Organization | Zoo, Department, Staff, Staff Shift |
| Places | Habitat, Enclosure |
| Animals | Conservation Status, Species, Animal, Animal Transfer |
| Food & Supply | Food Type, Supplier, Food Stock, Feeding Plan, Feeding Log |
| Care & Health | Care Assignment, Medical Record, Vaccination |
| Visitors | Ticket Type, Ticket |

---

## 3.A.3 Main Relationships (Business Level)

| Relationship | From → To | Cardinality | Meaning |
|---|---|---|---|
| has | Zoo → Department | 1 : N | A zoo has many departments |
| contains | Zoo → Habitat | 1 : N | A zoo contains many habitat zones |
| employs | Department → Staff | 1 : N | A department employs many staff |
| supervises | Staff → Staff | 1 : N | A staff member may supervise others |
| works | Staff → Staff Shift | 1 : N | Staff work scheduled shifts |
| includes | Habitat → Enclosure | 1 : N | A habitat includes many enclosures |
| classifies | Conservation Status → Species | 1 : N | Status classifies many species |
| is type of | Species → Animal | 1 : N | Many animals belong to one species |
| houses | Enclosure → Animal | 1 : N | An enclosure houses many animals |
| moved | Animal → Animal Transfer | 1 : N | Transfers record animal moves |
| from / to | Enclosure → Animal Transfer | 1 : N | Transfer leaves one enclosure for another |
| assigned / cared for | Staff ↔ Animal (via Care Assignment) | M : N | Keepers assigned to animals over time |
| has / examines | Animal / Staff → Medical Record | 1 : N | Vet exams for animals |
| receives / administers | Animal / Staff → Vaccination | 1 : N | Vaccines given by vets |
| follows / used in | Animal / Food Type → Feeding Plan | M : N | Planned diet (resolved by Feeding Plan) |
| recorded / fed by | Feeding Plan / Staff → Feeding Log | 1 : N | Actual feeding events |
| supplies / stocked | Supplier / Food Type → Food Stock | M : N | Purchases of food |
| defines / sells | Ticket Type / Staff → Ticket | 1 : N | Ticket sales |

---

## 3.A.4 Important Business Constraints (Conceptual)

- An animal lives in **one** enclosure at a time; past locations are kept as **transfers**.  
- Care assignments and medical history are **not overwritten**—history is kept.  
- Feeding **plans** (intended diet) are separate from feeding **logs** (what actually happened).  
- A transfer’s source enclosure must differ from its destination.  
- Ticket sales refer to a ticket **type** (price list) rather than storing a free-text price only.  
- Staff roles include Manager, Keeper, Veterinarian, Cashier, and Maintenance.  

---

## 3.A.5 Conceptual ER Diagram

See: [`conceptual_er_diagram.md`](conceptual_er_diagram.md)

The conceptual diagram uses **Chen-style** thinking: entities and relationships first; attributes named without SQL types. It is the foundation for Logical Design.

---

## 3.A.6 Outcomes

- [x] Entities identified from user needs / UI domains  
- [x] Relationships and cardinalities stated  
- [x] Business constraints listed  
- [x] Conceptual ER produced  
- [ ] Optional: attribute list per entity as appendix for oral defense  

**Next:** Logical Design maps this model to tables, keys, and the written schema documentation.
