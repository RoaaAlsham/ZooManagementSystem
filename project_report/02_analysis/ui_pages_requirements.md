# Analysis Deliverable: Initial UI Page Requirements

This document summarizes **user-need → screen** requirements discovered in Analysis.  
The project builds a **lean set of 10 core screens**; secondary flows are merged into hubs.

Full specifications (components, SQL, build order):

> [`../../zoo_ui_pages_design.md`](../../zoo_ui_pages_design.md)

---

## Design Principles (from user needs)

| Principle | Meaning |
|---|---|
| Lean screen set | **10 core screens**; merge dialogs/tabs instead of many routes |
| Task-oriented pages | Screens follow jobs (feed, vaccinate, sell tickets), not raw tables |
| Animal-centric hub | Animal Detail holds care, health, feeding plans, transfer, edit |
| Role-based views | Each role sees only what it needs |
| History preserved | Prefer end / deactivate over delete |
| Forms reflect rules | UI validates dates, required fields, and allowed values |

---

## Core Build Target (10 Screens)

| # | ID | Screen | Notes |
|---|---|---|---|
| 1 | P01 | Login | Auth + role |
| 2 | P03 | Animal List | Find animals; **Add animal** wizard |
| 3 | P04 | Animal Detail | Hub: edit, transfer, care, plans, health |
| 4 | P07 | Habitats and Enclosures | Places + capacity |
| 5 | P09 | Feeding Today | Daily logging |
| 6 | P12 | Veterinary Center | Vet work queues |
| 7 | P13 | Food Inventory | Stock + **suppliers** |
| 8 | P15 | Staff Directory | People + **shifts** |
| 9 | P17 | Ticketing | POS |
| 10 | P19 | Admin Settings | Zoo, departments, **species**, ticket types |

### Merged (not separate screens)

| Former idea | Merged into |
|---|---|
| Add / Edit Animal | P03 Add + P04 Edit |
| Transfer Animal | P04 dialog |
| Species & Conservation | P19 |
| Feeding Plans | P04 Feeding tab |
| Care Assignments | P04 Care tab (+ workload on P15) |
| Suppliers | P13 tab |
| Shift Schedule | P15 Shifts tab |
| Reports | Deferred (optional with Dashboard) |

### Deferred (stretch)

| ID | Feature |
|---|---|
| P02 | Dashboard (alerts / KPIs) — build after the 10 screens |

---

## Navigation Map

```
Login (P01)
└── Main layout (sidebar + top bar)
    ├── Animals
    │   ├── P03 Animal List
    │   └── P04 Animal Detail (tabs + edit/transfer)
    ├── P07 Habitats and Enclosures
    ├── P09 Feeding Today
    ├── P12 Veterinary Center
    ├── P13 Food Inventory (+ Suppliers)
    ├── P15 Staff Directory (+ Shifts)
    ├── P17 Ticketing
    └── P19 Admin Settings (+ Species)
```

---

## Page List vs. User Need

| ID | Page | User need addressed |
|---|---|---|
| P01 | Login | Secure access; detect role |
| P03 | Animal List | Find / filter animals; register new |
| P04 | Animal Detail | Full picture of one animal; transfer; plans; care |
| P07 | Habitats and Enclosures | Manage places and capacity |
| P09 | Feeding Today | Daily feeding worksheet and logging |
| P12 | Veterinary Center | Checkups, vaccines, treatments |
| P13 | Food Inventory | Stock, expiry, deliveries, suppliers |
| P15 | Staff Directory | Employees, hierarchy, shifts |
| P17 | Ticketing | Sell tickets |
| P19 | Admin Settings | Lookups and zoo info |

---

## Role Access (Summary)

| Page | Manager | Keeper | Vet | Cashier |
|---|---|---|---|---|
| Animal List / Detail | ✓ | ✓ | ✓ | — |
| Habitats | ✓ | view | view | — |
| Feeding Today | view | ✓ | view | — |
| Veterinary | view | — | ✓ | — |
| Food Inventory | ✓ | view | view | — |
| Staff | ✓ | own | own | own |
| Ticketing | view | — | — | ✓ |
| Admin | ✓ | — | species optional | — |

*(Exact matrix: see full UI design document.)*

---

## Bridge to Design

These screens still imply the same data domains:

- Organization → Zoo, Department, Staff, Staff Shift  
- Places → Habitat, Enclosure  
- Animals → Species, Conservation Status, Animal, Animal Transfer  
- Food → Food Type, Supplier, Food Stock, Feeding Plan, Feeding Log  
- Care & Health → Care Assignment, Medical Record, Vaccination  
- Visitors → Ticket Type, Ticket  

All **20 tables** remain covered by the 10 screens (see page-to-table matrix in the UI design doc).
