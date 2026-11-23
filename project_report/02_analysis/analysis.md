# 2. Analysis Phase

**Goal of this phase:** Fact-finding about the problem / opportunity—who needs what information, and which tasks the system must support.

---

## 2.1 Purpose of Analysis

Planning showed *why* a unified database is needed. Analysis answers:

- Who are the users (roles)?  
- What daily tasks do they perform?  
- What information must appear on each screen?  
- Which data domains must the database support so those screens work?  

The main analysis deliverable is a **lean UI of 10 core screens** derived from user needs (secondary flows merged into hubs). Details: [`ui_pages_requirements.md`](ui_pages_requirements.md) and [`../../zoo_ui_pages_design.md`](../../zoo_ui_pages_design.md).

---

## 2.2 Stakeholders and Roles

| Role | Main needs |
|---|---|
| **Manager / Admin** | Staff, habitats, inventory, settings, oversight |
| **Keeper** | Animal list/detail, feeding today, care on animal hub |
| **Veterinarian** | Vet queues; medical/vaccine history on animal detail |
| **Cashier** | Ticket sales (point of sale) |
| **Maintenance** | Habitats and enclosures (condition / capacity view) |

---

## 2.3 Fact-Finding Summary (User Needs → System Needs)

| User need (observed / assumed) | System response |
|---|---|
| “Find an animal and see everything about it.” | **P04 Animal Detail** hub (care, health, feeding plans, transfers, edit) |
| “Register a new animal.” | **Add** wizard from **P03 Animal List** |
| “Log that I fed this animal.” | **P09 Feeding Today** |
| “Move an animal to another enclosure.” | Transfer **dialog on P04** (history kept) |
| “Sell tickets quickly.” | **P17 Ticketing** |
| “Who works when?” | **Shifts tab on P15 Staff** |
| “Don’t lose history.” | No hard deletes for important history; end / deactivate instead |
| “Manage rare lookups.” | **P19 Admin** (species, ticket types, zoo, departments) |

---

## 2.4 Core UI Screen Requirements (Overview)

Screens are **task-oriented** and limited to **10** for an efficient build.

| ID | Screen | Primary users |
|---|---|---|
| P01 | Login | Everyone |
| P03 | Animal List (+ Add) | Manager, Keeper, Vet |
| P04 | Animal Detail (hub) | Manager, Keeper, Vet |
| P07 | Habitats and Enclosures | Manager |
| P09 | Feeding Today | Keeper |
| P12 | Veterinary Center | Vet |
| P13 | Food Inventory (+ Suppliers) | Manager, Keeper |
| P15 | Staff Directory (+ Shifts) | Manager |
| P17 | Ticketing | Cashier |
| P19 | Admin Settings (+ Species) | Admin |

**Merged away as separate pages:** Add/Edit route, Transfer route, Species page, Feeding Plans page, Care Assignments page, Suppliers page, Shift Schedule page, Reports page.  
**Stretch (optional later):** Dashboard (P02).

Full navigation map, role matrix, and page-to-table mapping: see [`ui_pages_requirements.md`](ui_pages_requirements.md).

---

## 2.5 Analysis Outcomes

- [x] Roles identified  
- [x] Core tasks mapped to **10** proposed UI screens  
- [x] Merges and deferred screens documented  
- [x] Link established between screens and data domains (feeds Design)  

---

## 2.6 Next Phase

**Design** turns these information requirements into a database model:

1. **Conceptual** — entities and relationships (no DBMS details)  
2. **Logical** — relational tables, keys, documentation  
3. **Physical** — SQL DDL and physical ER for the selected DBMS  
