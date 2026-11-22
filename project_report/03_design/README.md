# 3. Design Phase

**Goal of this phase:** Turn analysis requirements into a database design.  
In database projects, **most emphasis** is placed on Design. It has three sub-phases.

---

## Database Design Sub-Phases

| Sub-phase | Question answered | Folder |
|---|---|---|
| **A. Conceptual Design** | What data exists, how it relates, what business rules apply—**independent of any DBMS**? | [`A_conceptual/`](A_conceptual/) |
| **B. Logical Design** | How is that model expressed as a **relational schema** (tables, keys, 3NF)—still DBMS-independent in principle? | [`B_logical/`](B_logical/) |
| **C. Physical Design** | How is the schema **implemented** for the chosen DBMS (SQL, indexes, storage-oriented choices)? | [`C_physical/`](C_physical/) |

---

## Flow in This Project

```
Analysis (UI / user needs)
        │
        ▼
A. Conceptual Design
   • Identify entities and relationships
   • Document constraints at a business level
   • Produce Conceptual ER diagram
        │
        ▼
B. Logical Design
   • Map entities → relations (tables)
   • Define keys, FKs, normalization (3NF)
   • Complete schema documentation
     (zoo_database_documentation.md)
        │
        ▼
C. Physical Design
   • Implement tables in Zoo_Database.sql
   • Physical ER diagram (tables + attributes + crow’s foot)
```

---

## Diagrams: Conceptual vs Physical

| | **Conceptual ER** | **Physical ER** |
|---|---|---|
| Focus | Business entities and relationships | Tables as they will be stored |
| Attributes | Named characteristics (no SQL types) | Columns with types, PK / FK |
| Notation | Chen-style (entity / relationship / attribute) | Crow’s-foot tables (implementation) |
| DBMS | None | Reflects chosen SQL schema |
| Location | [`A_conceptual/conceptual_er_diagram.md`](A_conceptual/conceptual_er_diagram.md) | [`C_physical/physical_er_diagram.md`](C_physical/physical_er_diagram.md) |

*(See also: [ER diagrams vs EER diagrams — conceptual vs physical models](https://nulab.com/learn/software-development/er-diagrams-vs-eer-diagrams-whats-the-difference/).)*

---

## Documents in This Phase

| Document | Path |
|---|---|
| Conceptual design narrative | [`A_conceptual/conceptual_design.md`](A_conceptual/conceptual_design.md) |
| Conceptual ER diagram | [`A_conceptual/conceptual_er_diagram.md`](A_conceptual/conceptual_er_diagram.md) |
| Logical design narrative | [`B_logical/logical_design.md`](B_logical/logical_design.md) |
| Schema documentation (full) | [`../../zoo_database_documentation.md`](../../zoo_database_documentation.md) |
| Physical design narrative | [`C_physical/physical_design.md`](C_physical/physical_design.md) |
| Physical ER diagram | [`C_physical/physical_er_diagram.md`](C_physical/physical_er_diagram.md) |
| SQL DDL | [`../../Zoo_Database.sql`](../../Zoo_Database.sql) |
