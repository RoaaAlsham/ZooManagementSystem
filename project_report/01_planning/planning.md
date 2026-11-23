# 1. Planning Phase

**Goal of this phase:** Identify the information gap in the organization and propose a database solution.

---

## 1.1 Context

A modern zoo must coordinate many daily activities at once:

- Housing and tracking individual animals and their species  
- Assigning keepers and veterinarians  
- Planning and logging feedings  
- Recording medical care and vaccinations  
- Managing habitats, enclosures, and capacity  
- Selling tickets and reporting attendance / revenue  

Today these activities are often handled with **separate notebooks, spreadsheets, or isolated applications**. That creates an **information gap**: data exists, but it is fragmented, duplicated, or hard to combine for decisions.

---

## 1.2 Information Gap (Problem Statement)

| Area | Typical gap without a unified system |
|---|---|
| Animal care | Hard to see “who cares for this animal?” or “was today’s feeding done?” |
| Health | Vaccination due dates and checkup history live in files that are easy to miss |
| Places | Enclosure capacity and transfers are not linked to live animal locations |
| Staff | Shifts and responsibilities are not connected to animals or ticket sales |
| Inventory | Food stock and supplier data are disconnected from feeding plans |
| Visitors | Ticket sales are not tied to staff or ticket types for reliable reporting |
| Management | No single source for alerts (missed feedings, low stock, full enclosures) |

**Core problem:** The organization lacks a **single, consistent, queryable store** of zoo operations data. Without it, care quality, compliance, and management visibility suffer.

---

## 1.3 Opportunity

A unified **Zoo Database Management System** can:

1. Store all operational data in one relational schema  
2. Enforce integrity (keys, foreign keys, check constraints)  
3. Support day-to-day tasks (feeding, transfers, ticketing, vet visits)  
4. Power reports and alerts from the same data used on the floor  

---

## 1.4 Proposed Database Solution

**Solution:** Design and implement a **normalized relational database** (**20 tables** in 3NF) on **Microsoft SQL Server**, integrated with a **Python + Tkinter** desktop application, covering:

| Domain | What the database will hold |
|---|---|
| Organization | Zoo, departments, staff, shifts |
| Places | Habitats and enclosures |
| Animals | Species, conservation status, animals, transfer history |
| Food & supply | Food types, suppliers, stock, feeding plans and logs |
| Care & health | Care assignments, medical records, vaccinations |
| Visitors | Ticket types and ticket sales |

**Project constraints (agreed by the team):**

| Constraint | Choice |
|---|---|
| Team size | 3 students |
| DBMS | **Microsoft SQL Server** (T-SQL; Express OK) |
| Application stack | Python + **Tkinter** UI, **pyodbc** ODBC client |
| Delivery focus | Planning → analysis → database design → working integrated system |

---

## 1.5 Planning Outcomes (Checklist)

- [x] Problem / information gap identified  
- [x] Unified database proposed as the solution  
- [x] Main data domains listed  
- [ ] Stakeholder list and interview notes *(optional appendix — fill if available)*  
- [x] Project constraints (time, DBMS = SQL Server, team size = 3)  


---

## 1.6 Next Phase

**Analysis** gathers facts about *how users work* and turns them into **UI screen requirements**—a lean set of **10 core screens** (with merges for secondary flows)—before detailed table design.
