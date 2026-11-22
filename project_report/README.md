# Zoo Management System — Database Design Project Report

**University:** Fatih Sultan Mehmet Foundation University  
**Course:** Database System Design  
**Project:** Zoo Database Management System  

---

## How This Report Is Organized

This report follows the **Database Development Lifecycle**. Each phase has its own folder with the documents, diagrams, and artifacts produced in that phase.

| Phase | Folder | Focus |
|---|---|---|
| **0. Cover** | [`00_cover/`](00_cover/) | Title page and report overview |
| **1. Planning** | [`01_planning/`](01_planning/) | Information gap and proposed database solution |
| **2. Analysis** | [`02_analysis/`](02_analysis/) | Fact-finding and **10 core UI screens** from user needs |
| **3. Design** | [`03_design/`](03_design/) | Conceptual → Logical → Physical design |

### Design Sub-Phases

| Sub-phase | Folder | Deliverables |
|---|---|---|
| **A. Conceptual Design** | [`03_design/A_conceptual/`](03_design/A_conceptual/) | Entities, relationships, constraints (no DBMS details); **conceptual ER diagram** |
| **B. Logical Design** | [`03_design/B_logical/`](03_design/B_logical/) | Relational schema, 3NF tables, data dictionary; schema documentation |
| **C. Physical Design** | [`03_design/C_physical/`](03_design/C_physical/) | SQL DDL for the chosen DBMS; **physical ER diagram** |

---

## Quick Navigation

1. [Cover Page](00_cover/cover_page.md)
2. [Planning](01_planning/planning.md)
3. [Analysis](02_analysis/analysis.md) · [UI Requirements](02_analysis/ui_pages_requirements.md)
4. [Design Overview](03_design/README.md)
   - [Conceptual Design](03_design/A_conceptual/conceptual_design.md) · [Conceptual ER](03_design/A_conceptual/conceptual_er_diagram.md)
   - [Logical Design](03_design/B_logical/logical_design.md)
   - [Physical Design](03_design/C_physical/physical_design.md) · [Physical ER](03_design/C_physical/physical_er_diagram.md)

---

## Related Project Artifacts (Repository Root)

| Artifact | Path | Used in |
|---|---|---|
| Schema documentation | [`../zoo_database_documentation.md`](../zoo_database_documentation.md) | Logical / Physical |
| UI pages design | [`../zoo_ui_pages_design.md`](../zoo_ui_pages_design.md) | Analysis |
| SQL script | [`../Zoo_Database.sql`](../Zoo_Database.sql) | Physical |
| Implementation plan (Python) | [`../IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) | Build next steps |
