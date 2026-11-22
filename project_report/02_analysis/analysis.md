# 2. Analysis Phase

**Goal of this phase:** Fact-finding about the problem / opportunity—who needs what information, and which tasks the system must support.

---

## 2.1 Purpose of Analysis

Planning showed *why* a unified database is needed. Analysis answers:

- Who are the users (roles)?  
- What daily tasks do they perform?  
- What information must appear on each screen?  
- Which data domains must the database support so those screens work?  

The main analysis deliverable in this project is the set of **initial UI page requirements** derived from user needs. Detailed page specs live in [`ui_pages_requirements.md`](ui_pages_requirements.md) and in the full design note [`../../zoo_ui_pages_design.md`](../../zoo_ui_pages_design.md).

---

## 2.2 Stakeholders and Roles

| Role | Main needs |
|---|---|
| **Manager / Admin** | Overview alerts, staff, habitats, reports, settings |
| **Keeper** | Animal list/detail, feeding today, feeding plans, care assignments |
| **Veterinarian** | Medical records, vaccinations, species / health status |
| **Cashier** | Ticket sales (point of sale) |

---

## 2.3 Fact-Finding Summary (User Needs → System Needs)

| User need (observed / assumed) | System response |
|---|---|
| “Show me what needs attention today.” | Dashboard with alerts (missed feedings, due vaccines, low stock, full enclosures) |
| “Find an animal and see everything about it.” | Animal-centric detail page (care, health, feeding, transfers) |
| “Log that I fed this animal.” | Feeding Today worksheet + feeding log |
| “Move an animal to another enclosure.” | Transfer action that keeps history |
| “Sell tickets quickly.” | Ticketing POS by ticket type |
| “Who works when?” | Staff directory + shift schedule |
| “Don’t lose history.” | No hard deletes for important history; end / deactivate instead |

---

## 2.4 Initial UI Page Requirements (Overview)

Pages are **task-oriented** (how staff work), not one page per table.

| ID | Page | Primary users |
|---|---|---|
| P01 | Login | Everyone |
| P02 | Dashboard | Manager, all |
| P03–P06 | Animals (list, detail, add/edit, transfer) | Manager, Keeper, Vet |
| P07 | Habitats and Enclosures | Manager |
| P08 | Species and Conservation | Manager, Vet |
| P09–P11 | Care (feeding today, plans, assignments) | Keeper, Manager |
| P12 | Veterinary Center | Vet |
| P13–P14 | Supplies (inventory, suppliers) | Manager, Keeper |
| P15–P16 | People (staff, shifts) | Manager |
| P17 | Ticketing | Cashier |
| P18 | Reports | Manager |
| P19 | Admin Settings | Admin |

Full navigation map, role matrix, and page-to-table mapping: see [`ui_pages_requirements.md`](ui_pages_requirements.md).

---

## 2.5 Analysis Outcomes

- [x] Roles identified  
- [x] Core tasks mapped to proposed UI pages  
- [x] Initial page list and access matrix defined  
- [x] Link established between pages and future data domains (feeds Design)  

---

## 2.6 Next Phase

**Design** turns these information requirements into a database model:

1. **Conceptual** — entities and relationships (no DBMS details)  
2. **Logical** — relational tables, keys, documentation  
3. **Physical** — SQL DDL and physical ER for the selected DBMS  
