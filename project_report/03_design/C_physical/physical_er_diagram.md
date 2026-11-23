# Physical ER Diagram (Crow’s-Foot / Table Model)

**Phase:** 3.C Physical Design  
**Source:** Same diagram as Section 3 of [`../../../zoo_database_documentation.md`](../../../zoo_database_documentation.md)

> **Physical model:** each entity is a **table**; fields are **typed attributes**; links use **crow’s-foot** notation with **PK / FK**.  
> For the technology-independent conceptual model, see [`../A_conceptual/conceptual_er_diagram.md`](../A_conceptual/conceptual_er_diagram.md).

Paste into [mermaid.live](https://mermaid.live) to render.

```mermaid
erDiagram
    ZOO ||--o{ DEPARTMENT : has
    ZOO ||--o{ HABITAT : contains
    DEPARTMENT ||--o{ STAFF : employs
    STAFF ||--o{ STAFF : supervises
    STAFF ||--o{ STAFF_SHIFT : works
    HABITAT ||--o{ ENCLOSURE : includes
    CONSERVATION_STATUS ||--o{ SPECIES : classifies
    SPECIES ||--o{ ANIMAL : "is type of"
    ENCLOSURE ||--o{ ANIMAL : houses
    ANIMAL ||--o{ ANIMAL_TRANSFER : moved
    ENCLOSURE ||--o{ ANIMAL_TRANSFER : "from"
    ENCLOSURE ||--o{ ANIMAL_TRANSFER : "to"
    STAFF ||--o{ CARE_ASSIGNMENT : assigned
    ANIMAL ||--o{ CARE_ASSIGNMENT : "cared for"
    ANIMAL ||--o{ MEDICAL_RECORD : has
    STAFF ||--o{ MEDICAL_RECORD : "examines (vet)"
    ANIMAL ||--o{ VACCINATION : receives
    STAFF ||--o{ VACCINATION : administers
    ANIMAL ||--o{ FEEDING_PLAN : follows
    FOOD_TYPE ||--o{ FEEDING_PLAN : "used in"
    FEEDING_PLAN ||--o{ FEEDING_LOG : recorded
    STAFF ||--o{ FEEDING_LOG : "fed by"
    SUPPLIER ||--o{ FOOD_STOCK : supplies
    FOOD_TYPE ||--o{ FOOD_STOCK : stocked
    TICKET_TYPE ||--o{ TICKET : defines
    STAFF ||--o{ TICKET : sells

    ZOO {
        int ZooID PK
        string Name
        string City
        string Address
        string Phone
        date OpenDate
    }
    DEPARTMENT {
        int DepartmentID PK
        int ZooID FK
        string Name
        string Description
    }
    STAFF {
        int StaffID PK
        int DepartmentID FK
        int SupervisorID FK
        string FirstName
        string LastName
        string Role
        string Phone
        string Email
        date HireDate
        decimal Salary
        string PasswordHash
    }
    STAFF_SHIFT {
        int ShiftID PK
        int StaffID FK
        date ShiftDate
        time StartTime
        time EndTime
    }
    HABITAT {
        int HabitatID PK
        int ZooID FK
        string Name
        string BiomeType
        string Climate
        decimal AreaSqm
    }
    ENCLOSURE {
        int EnclosureID PK
        int HabitatID FK
        string Name
        int Capacity
        string Condition
        date LastMaintenance
    }
    CONSERVATION_STATUS {
        int StatusID PK
        string Code
        string Name
        string Description
    }
    SPECIES {
        int SpeciesID PK
        int StatusID FK
        string CommonName
        string ScientificName
        string DietType
        int AvgLifespanYears
    }
    ANIMAL {
        int AnimalID PK
        int SpeciesID FK
        int EnclosureID FK
        string Name
        string Gender
        date BirthDate
        date ArrivalDate
        string Origin
        string HealthStatus
    }
    ANIMAL_TRANSFER {
        int TransferID PK
        int AnimalID FK
        int FromEnclosureID FK
        int ToEnclosureID FK
        date TransferDate
        string Reason
    }
    CARE_ASSIGNMENT {
        int AssignmentID PK
        int StaffID FK
        int AnimalID FK
        date StartDate
        date EndDate
        string Responsibility
    }
    MEDICAL_RECORD {
        int RecordID PK
        int AnimalID FK
        int VetID FK
        date CheckupDate
        string Diagnosis
        string Treatment
        date NextCheckup
    }
    VACCINATION {
        int VaccinationID PK
        int AnimalID FK
        int VetID FK
        string VaccineName
        date DateGiven
        date NextDue
    }
    FOOD_TYPE {
        int FoodID PK
        string Name
        string Category
        string Unit
        decimal CaloriesPerUnit
    }
    SUPPLIER {
        int SupplierID PK
        string Name
        string ContactPerson
        string Phone
        string Address
    }
    FOOD_STOCK {
        int StockID PK
        int FoodID FK
        int SupplierID FK
        decimal Quantity
        decimal UnitPrice
        date PurchaseDate
        date ExpiryDate
    }
    FEEDING_PLAN {
        int PlanID PK
        int AnimalID FK
        int FoodID FK
        decimal QuantityPerMeal
        time FeedingTime
        string Frequency
    }
    FEEDING_LOG {
        int LogID PK
        int PlanID FK
        int StaffID FK
        datetime FedAt
        decimal QuantityGiven
        string Notes
    }
    TICKET_TYPE {
        int TicketTypeID PK
        string Name
        decimal Price
        string Description
    }
    TICKET {
        int TicketID PK
        int TicketTypeID FK
        int SoldByStaffID FK
        date VisitDate
        datetime PurchasedAt
        int Quantity
        decimal TotalPrice
    }
```

---

## Link to SQL

Tables are created on **Microsoft SQL Server** with the official T-SQL script (DDL + sample data):

[`../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql`](../../../ZooManagementSystem_Desktop/ZooManagementSystem/database/ZooDB_FULL.sql)
