# Analysis Deliverable: Initial UI Page Requirements

This document summarizes **user-need → page** requirements discovered in Analysis.  
The complete page specifications (components, SQL mapping, build order) are in:

> [`../../zoo_ui_pages_design.md`](../../zoo_ui_pages_design.md)

---

## Design Principles (from user needs)

| Principle | Meaning |
|---|---|
| Task-oriented pages | Pages follow jobs (feed, vaccinate, sell tickets), not raw tables |
| Dashboard first | Landing page shows alerts that need action |
| Animal-centric navigation | Animal detail is the hub for care, health, feeding, transfers |
| Role-based views | Each role sees only what it needs |
| History preserved | Prefer end / deactivate over delete |
| Forms reflect rules | UI validates dates, required fields, and allowed values |

---

## Navigation Map

```
Login
└── Main layout (sidebar + top bar)
    ├── P02 Dashboard
    ├── Animals
    │   ├── P03 Animal List
    │   ├── P04 Animal Detail (tabs)
    │   ├── P05 Add / Edit Animal
    │   └── P06 Transfer Animal (dialog)
    ├── Places
    │   └── P07 Habitats and Enclosures
    ├── Species
    │   └── P08 Species and Conservation
    ├── Care
    │   ├── P09 Feeding Today
    │   ├── P10 Feeding Plans
    │   └── P11 Care Assignments
    ├── Health
    │   └── P12 Veterinary Center
    ├── Supplies
    │   ├── P13 Food Inventory
    │   └── P14 Suppliers
    ├── People
    │   ├── P15 Staff Directory and Profile
    │   └── P16 Shift Schedule
    ├── Visitors
    │   └── P17 Ticketing (Point of Sale)
    ├── P18 Reports
    └── P19 Admin Settings
```

---

## Page List vs. User Need

| ID | Page | User need addressed |
|---|---|---|
| P01 | Login | Secure access; detect role |
| P02 | Dashboard | “What needs attention today?” |
| P03 | Animal List | Find / filter animals |
| P04 | Animal Detail | Full picture of one animal |
| P05 | Add / Edit Animal | Register and update animals |
| P06 | Transfer Animal | Move animal; keep history |
| P07 | Habitats and Enclosures | Manage places and capacity |
| P08 | Species and Conservation | Species catalog and status |
| P09 | Feeding Today | Daily feeding worksheet and logging |
| P10 | Feeding Plans | Define diets |
| P11 | Care Assignments | Assign keepers to animals |
| P12 | Veterinary Center | Checkups, vaccines, treatments |
| P13 | Food Inventory | Stock, expiry, deliveries |
| P14 | Suppliers | Supplier directory |
| P15 | Staff Directory | Employees and hierarchy |
| P16 | Shift Schedule | Who works when |
| P17 | Ticketing | Sell tickets |
| P18 | Reports | Analytics and exports |
| P19 | Admin Settings | Lookup tables and zoo info |

---

## Role Access (Summary)

| Page | Manager | Keeper | Vet | Cashier |
|---|---|---|---|---|
| Dashboard | ✓ | ✓ | ✓ | limited |
| Animals | ✓ | ✓ | ✓ | — |
| Habitats | ✓ | view | — | — |
| Feeding | ✓ | ✓ | view | — |
| Veterinary | ✓ | view | ✓ | — |
| Staff / Shifts | ✓ | — | — | — |
| Ticketing | ✓ | — | — | ✓ |
| Reports | ✓ | — | — | — |
| Admin | ✓ (admin) | — | — | — |

*(Exact matrix: see full UI design document.)*

---

## Bridge to Design

These pages imply the data domains designed next:

- Organization → Zoo, Department, Staff, Staff Shift  
- Places → Habitat, Enclosure  
- Animals → Species, Conservation Status, Animal, Animal Transfer  
- Food → Food Type, Supplier, Food Stock, Feeding Plan, Feeding Log  
- Care & Health → Care Assignment, Medical Record, Vaccination  
- Visitors → Ticket Type, Ticket  

Conceptual Design starts from these entities and their relationships—**without** choosing column types or a DBMS yet.
