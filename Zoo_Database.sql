  -- 1 ZOO
CREATE TABLE ZOO (
    ZooID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    City VARCHAR(60) NOT NULL,
    Address VARCHAR(200),
    Phone VARCHAR(20),
    OpenDate DATE
);

-- 2 DEPARTMENT
CREATE TABLE DEPARTMENT (
    DepartmentID INT PRIMARY KEY,
    ZooID INT NOT NULL,
    Name VARCHAR(80) NOT NULL,
    Description VARCHAR(255),
    FOREIGN KEY (ZooID) REFERENCES ZOO(ZooID),
    UNIQUE (ZooID, Name)
);

-- 3 STAFF
CREATE TABLE STAFF (
    StaffID INT PRIMARY KEY,
    DepartmentID INT NOT NULL,
    SupervisorID INT,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    Phone VARCHAR(20),
    Email VARCHAR(100) UNIQUE,
    HireDate DATE NOT NULL,
    Salary DECIMAL(10,2),
    FOREIGN KEY (DepartmentID) REFERENCES DEPARTMENT(DepartmentID),
    FOREIGN KEY (SupervisorID) REFERENCES STAFF(StaffID),
    CHECK (Salary >= 0)
);

-- 4 STAFF_SHIFT
CREATE TABLE STAFF_SHIFT (
    ShiftID INT PRIMARY KEY,
    StaffID INT NOT NULL,
    ShiftDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    FOREIGN KEY (StaffID) REFERENCES STAFF(StaffID) ON DELETE CASCADE,
    CHECK (EndTime > StartTime),
    UNIQUE (StaffID, ShiftDate, StartTime)
);

-- 5 HABITAT
CREATE TABLE HABITAT (
    HabitatID INT PRIMARY KEY,
    ZooID INT NOT NULL,
    Name VARCHAR(80) NOT NULL,
    BiomeType VARCHAR(50) NOT NULL,
    Climate VARCHAR(50),
    AreaSqm DECIMAL(10,2),
    FOREIGN KEY (ZooID) REFERENCES ZOO(ZooID),
    UNIQUE (ZooID, Name),
    CHECK (AreaSqm > 0)
);

-- 6 ENCLOSURE
CREATE TABLE ENCLOSURE (
    EnclosureID INT PRIMARY KEY,
    HabitatID INT NOT NULL,
    Name VARCHAR(80) NOT NULL,
    Capacity INT NOT NULL,
    Condition VARCHAR(30),
    LastMaintenance DATE,
    FOREIGN KEY (HabitatID) REFERENCES HABITAT(HabitatID),
    UNIQUE (HabitatID, Name),
    CHECK (Capacity > 0),
    CHECK (Condition IN ('Good', 'Needs Repair', 'Under Maintenance'))
);

-- 7 CONSERVATION_STATUS
CREATE TABLE CONSERVATION_STATUS (
    StatusID INT PRIMARY KEY,
    Code VARCHAR(5) NOT NULL UNIQUE,
    Name VARCHAR(50) NOT NULL,
    Description VARCHAR(255)
);

-- 8 SPECIES
CREATE TABLE SPECIES (
    SpeciesID INT PRIMARY KEY,
    StatusID INT NOT NULL,
    CommonName VARCHAR(80) NOT NULL,
    ScientificName VARCHAR(100) NOT NULL UNIQUE,
    DietType VARCHAR(30),
    AvgLifespanYears INT,
    FOREIGN KEY (StatusID) REFERENCES CONSERVATION_STATUS(StatusID),
    CHECK (DietType IN ('Carnivore', 'Herbivore', 'Omnivore', 'Insectivore')),
    CHECK (AvgLifespanYears > 0)
);

-- 9 ANIMAL
CREATE TABLE ANIMAL (
    AnimalID INT PRIMARY KEY,
    SpeciesID INT NOT NULL,
    EnclosureID INT,
    Name VARCHAR(60) NOT NULL,
    Gender VARCHAR(10),
    BirthDate DATE,
    ArrivalDate DATE NOT NULL,
    Origin VARCHAR(100),
    HealthStatus VARCHAR(30),
    FOREIGN KEY (SpeciesID) REFERENCES SPECIES(SpeciesID),
    FOREIGN KEY (EnclosureID) REFERENCES ENCLOSURE(EnclosureID),
    CHECK (Gender IN ('Male', 'Female', 'Unknown')),
    CHECK (HealthStatus IN ('Healthy', 'Under Treatment', 'Quarantine', 'Deceased')),
    CHECK (BirthDate IS NULL OR ArrivalDate >= BirthDate)
);

-- 10 ANIMAL_TRANSFER
CREATE TABLE ANIMAL_TRANSFER (
    TransferID INT PRIMARY KEY,
    AnimalID INT NOT NULL,
    FromEnclosureID INT NOT NULL,
    ToEnclosureID INT NOT NULL,
    TransferDate DATE NOT NULL,
    Reason VARCHAR(200),
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (FromEnclosureID) REFERENCES ENCLOSURE(EnclosureID),
    FOREIGN KEY (ToEnclosureID) REFERENCES ENCLOSURE(EnclosureID),
    CHECK (FromEnclosureID <> ToEnclosureID)
);

-- 11 FOOD_TYPE
CREATE TABLE FOOD_TYPE (
    FoodID INT PRIMARY KEY,
    Name VARCHAR(80) NOT NULL UNIQUE,
    Category VARCHAR(30),
    Unit VARCHAR(10) NOT NULL,
    CaloriesPerUnit DECIMAL(8,2),
    CHECK (Category IN ('Meat', 'Fish', 'Fruit', 'Vegetable', 'Grain', 'Insect', 'Supplement')),
    CHECK (CaloriesPerUnit >= 0)
);

-- 12 SUPPLIER
CREATE TABLE SUPPLIER (
    SupplierID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE,
    ContactPerson VARCHAR(80),
    Phone VARCHAR(20),
    Address VARCHAR(200)
);

-- 13 FOOD_STOCK
CREATE TABLE FOOD_STOCK (
    StockID INT PRIMARY KEY,
    FoodID INT NOT NULL,
    SupplierID INT NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    PurchaseDate DATE NOT NULL,
    ExpiryDate DATE,
    FOREIGN KEY (FoodID) REFERENCES FOOD_TYPE(FoodID),
    FOREIGN KEY (SupplierID) REFERENCES SUPPLIER(SupplierID),
    CHECK (Quantity > 0),
    CHECK (UnitPrice >= 0),
    CHECK (ExpiryDate IS NULL OR ExpiryDate > PurchaseDate)
);

-- 14 FEEDING_PLAN
CREATE TABLE FEEDING_PLAN (
    PlanID INT PRIMARY KEY,
    AnimalID INT NOT NULL,
    FoodID INT NOT NULL,
    QuantityPerMeal DECIMAL(8,2) NOT NULL,
    FeedingTime TIME NOT NULL,
    Frequency VARCHAR(30),
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (FoodID) REFERENCES FOOD_TYPE(FoodID),
    CHECK (QuantityPerMeal > 0),
    UNIQUE (AnimalID, FoodID, FeedingTime)
);

-- 15 FEEDING_LOG
CREATE TABLE FEEDING_LOG (
    LogID INT PRIMARY KEY,
    PlanID INT NOT NULL,
    StaffID INT NOT NULL,
    FedAt DATETIME NOT NULL,
    QuantityGiven DECIMAL(8,2) NOT NULL,
    Notes VARCHAR(255),
    FOREIGN KEY (PlanID) REFERENCES FEEDING_PLAN(PlanID),
    FOREIGN KEY (StaffID) REFERENCES STAFF(StaffID),
    CHECK (QuantityGiven >= 0)
);

-- 16 CARE_ASSIGNMENT
CREATE TABLE CARE_ASSIGNMENT (
    AssignmentID INT PRIMARY KEY,
    StaffID INT NOT NULL,
    AnimalID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE,
    Responsibility VARCHAR(100),
    FOREIGN KEY (StaffID) REFERENCES STAFF(StaffID),
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    CHECK (EndDate IS NULL OR EndDate >= StartDate),
    UNIQUE (StaffID, AnimalID, StartDate)
);

-- 17 MEDICAL_RECORD
CREATE TABLE MEDICAL_RECORD (
    RecordID INT PRIMARY KEY,
    AnimalID INT NOT NULL,
    VetID INT NOT NULL,
    CheckupDate DATE NOT NULL,
    Diagnosis VARCHAR(255),
    Treatment VARCHAR(255),
    NextCheckup DATE,
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (VetID) REFERENCES STAFF(StaffID),
    CHECK (NextCheckup IS NULL OR NextCheckup > CheckupDate)
);

-- 18 VACCINATION
CREATE TABLE VACCINATION (
    VaccinationID INT PRIMARY KEY,
    AnimalID INT NOT NULL,
    VetID INT NOT NULL,
    VaccineName VARCHAR(100) NOT NULL,
    DateGiven DATE NOT NULL,
    NextDue DATE,
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (VetID) REFERENCES STAFF(StaffID),
    CHECK (NextDue IS NULL OR NextDue > DateGiven)
);

-- 19 TICKET_TYPE
CREATE TABLE TICKET_TYPE (
    TicketTypeID INT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Price DECIMAL(8,2) NOT NULL,
    Description VARCHAR(200),
    CHECK (Price >= 0)
);

-- 20 TICKET
CREATE TABLE TICKET (
    TicketID INT PRIMARY KEY,
    TicketTypeID INT NOT NULL,
    SoldByStaffID INT,
    VisitDate DATE NOT NULL,
    PurchasedAt DATETIME NOT NULL,
    Quantity INT NOT NULL,
    TotalPrice DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (TicketTypeID) REFERENCES TICKET_TYPE(TicketTypeID),
    FOREIGN KEY (SoldByStaffID) REFERENCES STAFF(StaffID) ON DELETE SET NULL,
    CHECK (Quantity > 0),
    CHECK (TotalPrice >= 0)
);
