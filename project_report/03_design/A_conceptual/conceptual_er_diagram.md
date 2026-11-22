# Conceptual ER Diagram (Chen-Style)

**Phase:** 3.A Conceptual Design  
**Purpose:** Show **entities**, **relationships**, and **cardinality** without physical/DBMS detail.

> **Conceptual vs physical (summary)**  
> - **Conceptual:** business entities & relationships; attributes as names only; no table/column/types/PK-FK implementation.  
> - **Physical:** tables with typed columns and crow’s-foot keys — see [`../C_physical/physical_er_diagram.md`](../C_physical/physical_er_diagram.md).  
> Reference: [ER diagrams vs EER diagrams](https://nulab.com/learn/software-development/er-diagrams-vs-eer-diagrams-whats-the-difference/).

Paste diagrams into [mermaid.live](https://mermaid.live) to render.

---

## Diagram 1 — Entity–Relationship Overview (Cardinality)

Entities are shown as nodes; labeled edges show relationship names and cardinality.  
**No** primary keys, foreign keys, or SQL data types.

```mermaid
flowchart TB
  subgraph ORG["Organization"]
    ZOO["Zoo"]
    DEPT["Department"]
    STAFF["Staff"]
    SHIFT["Staff Shift"]
  end

  subgraph PLACES["Places"]
    HAB["Habitat"]
    ENC["Enclosure"]
  end

  subgraph ANIMALS["Animals"]
    CS["Conservation Status"]
    SP["Species"]
    AN["Animal"]
    TR["Animal Transfer"]
  end

  subgraph FOOD["Food and Supply"]
    FT["Food Type"]
    SUP["Supplier"]
    STOCK["Food Stock"]
    FP["Feeding Plan"]
    FL["Feeding Log"]
  end

  subgraph CARE["Care and Health"]
    CA["Care Assignment"]
    MR["Medical Record"]
    VAC["Vaccination"]
  end

  subgraph VIS["Visitors"]
    TT["Ticket Type"]
    TK["Ticket"]
  end

  ZOO -->|"has (1:N)"| DEPT
  ZOO -->|"contains (1:N)"| HAB
  DEPT -->|"employs (1:N)"| STAFF
  STAFF -->|"supervises (1:N)"| STAFF
  STAFF -->|"works (1:N)"| SHIFT
  HAB -->|"includes (1:N)"| ENC
  CS -->|"classifies (1:N)"| SP
  SP -->|"is type of (1:N)"| AN
  ENC -->|"houses (1:N)"| AN
  AN -->|"moved (1:N)"| TR
  ENC -->|"from (1:N)"| TR
  ENC -->|"to (1:N)"| TR
  STAFF -->|"assigned (M:N via Care Assignment)"| CA
  AN -->|"cared for (M:N via Care Assignment)"| CA
  AN -->|"has (1:N)"| MR
  STAFF -->|"examines (1:N)"| MR
  AN -->|"receives (1:N)"| VAC
  STAFF -->|"administers (1:N)"| VAC
  AN -->|"follows (M:N via Feeding Plan)"| FP
  FT -->|"used in (M:N via Feeding Plan)"| FP
  FP -->|"recorded (1:N)"| FL
  STAFF -->|"fed by (1:N)"| FL
  SUP -->|"supplies (M:N via Food Stock)"| STOCK
  FT -->|"stocked (M:N via Food Stock)"| STOCK
  TT -->|"defines (1:N)"| TK
  STAFF -->|"sells (1:N)"| TK
```

---

## Diagram 2 — Chen-Style Core (Selected Entities with Attributes)

Classic conceptual style: **rectangle = entity**, **diamond = relationship**, **oval = attribute**.  
Only a core subset is drawn in full so the figure stays readable; remaining entities follow the same pattern (see attribute catalog below).

```mermaid
flowchart TB
  %% Attributes — Zoo
  Z_Name((Name))
  Z_City((City))
  Z_Address((Address))
  Z_Phone((Phone))
  Z_Open((Open Date))

  %% Attributes — Animal
  A_Name((Name))
  A_Gender((Gender))
  A_Birth((Birth Date))
  A_Arrival((Arrival Date))
  A_Origin((Origin))
  A_Health((Health Status))

  %% Attributes — Staff
  S_FN((First Name))
  S_LN((Last Name))
  S_Role((Role))
  S_Phone((Phone))
  S_Email((Email))
  S_Hire((Hire Date))
  S_Sal((Salary))

  %% Attributes — Enclosure
  E_Name((Name))
  E_Cap((Capacity))
  E_Cond((Condition))
  E_Maint((Last Maintenance))

  %% Entities
  ZOO[Zoo]
  DEPT[Department]
  STAFF[Staff]
  HAB[Habitat]
  ENC[Enclosure]
  SP[Species]
  AN[Animal]
  CA[Care Assignment]
  FP[Feeding Plan]
  FT[Food Type]

  %% Relationships
  R_HAS{has}
  R_CONTAINS{contains}
  R_EMPLOYS{employs}
  R_INCLUDES{includes}
  R_TYPE{is type of}
  R_HOUSES{houses}
  R_CARES{cares for}
  R_FEEDS{is fed}

  %% Attribute links
  Z_Name --- ZOO
  Z_City --- ZOO
  Z_Address --- ZOO
  Z_Phone --- ZOO
  Z_Open --- ZOO

  A_Name --- AN
  A_Gender --- AN
  A_Birth --- AN
  A_Arrival --- AN
  A_Origin --- AN
  A_Health --- AN

  S_FN --- STAFF
  S_LN --- STAFF
  S_Role --- STAFF
  S_Phone --- STAFF
  S_Email --- STAFF
  S_Hire --- STAFF
  S_Sal --- STAFF

  E_Name --- ENC
  E_Cap --- ENC
  E_Cond --- ENC
  E_Maint --- ENC

  %% Structure
  ZOO --- R_HAS --- DEPT
  ZOO --- R_CONTAINS --- HAB
  DEPT --- R_EMPLOYS --- STAFF
  HAB --- R_INCLUDES --- ENC
  SP --- R_TYPE --- AN
  ENC --- R_HOUSES --- AN
  STAFF --- R_CARES --- CA
  AN --- R_CARES --- CA
  AN --- R_FEEDS --- FP
  FT --- R_FEEDS --- FP
```

---

## Attribute Catalog (Conceptual — Names Only)

Attributes are listed **without** SQL types. Identifying attributes are marked *(id)* conceptually (not as implemented PK columns).

### Organization
| Entity | Attributes |
|---|---|
| Zoo | Zoo Id *(id)*, Name, City, Address, Phone, Open Date |
| Department | Department Id *(id)*, Name, Description |
| Staff | Staff Id *(id)*, First Name, Last Name, Role, Phone, Email, Hire Date, Salary |
| Staff Shift | Shift Id *(id)*, Shift Date, Start Time, End Time |

### Places
| Entity | Attributes |
|---|---|
| Habitat | Habitat Id *(id)*, Name, Biome Type, Climate, Area (m²) |
| Enclosure | Enclosure Id *(id)*, Name, Capacity, Condition, Last Maintenance |

### Animals
| Entity | Attributes |
|---|---|
| Conservation Status | Status Id *(id)*, Code, Name, Description |
| Species | Species Id *(id)*, Common Name, Scientific Name, Diet Type, Avg Lifespan (years) |
| Animal | Animal Id *(id)*, Name, Gender, Birth Date, Arrival Date, Origin, Health Status |
| Animal Transfer | Transfer Id *(id)*, Transfer Date, Reason |

### Food and Supply
| Entity | Attributes |
|---|---|
| Food Type | Food Id *(id)*, Name, Category, Unit, Calories Per Unit |
| Supplier | Supplier Id *(id)*, Name, Contact Person, Phone, Address |
| Food Stock | Stock Id *(id)*, Quantity, Unit Price, Purchase Date, Expiry Date |
| Feeding Plan | Plan Id *(id)*, Quantity Per Meal, Feeding Time, Frequency |
| Feeding Log | Log Id *(id)*, Fed At, Quantity Given, Notes |

### Care and Health
| Entity | Attributes |
|---|---|
| Care Assignment | Assignment Id *(id)*, Start Date, End Date, Responsibility |
| Medical Record | Record Id *(id)*, Checkup Date, Diagnosis, Treatment, Next Checkup |
| Vaccination | Vaccination Id *(id)*, Vaccine Name, Date Given, Next Due |

### Visitors
| Entity | Attributes |
|---|---|
| Ticket Type | Ticket Type Id *(id)*, Name, Price, Description |
| Ticket | Ticket Id *(id)*, Visit Date, Purchased At, Quantity, Total Price |

---

## Notes for the Report

1. **Associative / bridge concepts** such as Care Assignment, Feeding Plan, Food Stock, and Ticket appear as entities because they carry their own attributes (dates, quantities, prices)—not only as bare M:N links.  
2. **Weak / dependent ideas** (e.g. Staff Shift depending on Staff) are modeled as separate entities with a clear parent relationship.  
3. Logical Design will turn this model into **relations** with explicit keys and foreign keys; Physical Design will add **SQL types** and the crow’s-foot physical ER.
