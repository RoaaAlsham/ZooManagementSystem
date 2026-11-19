CREATE DATABASE ZooManagementDB;
GO

USE ZooManagementDB;
GO

--TABLE 1: ZOO
CREATE TABLE ZOO (
    ZooID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    City VARCHAR(60) NOT NULL,
    Address VARCHAR(200),
    Phone VARCHAR(20),
    OpenDate DATE
);

-- TABLE 2: DEPARTMENT 
CREATE TABLE DEPARTMENT (
    DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
    ZooID INT NOT NULL,
    Name VARCHAR(80) NOT NULL,
    Description VARCHAR(255),

    CONSTRAINT FK_Department_Zoo
        FOREIGN KEY (ZooID)
        REFERENCES ZOO(ZooID),

    CONSTRAINT UQ_Department_Zoo_Name
        UNIQUE (ZooID, Name)
);

--TABLE 3: STAFF
CREATE TABLE STAFF (
    StaffID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentID INT NOT NULL,
    SupervisorID INT NULL,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    Phone VARCHAR(20),
    Email VARCHAR(100) UNIQUE,
    HireDate DATE NOT NULL,
    Salary DECIMAL(10,2),

    CONSTRAINT FK_Staff_Department
        FOREIGN KEY (DepartmentID)
        REFERENCES DEPARTMENT(DepartmentID),

    CONSTRAINT FK_Staff_Supervisor
        FOREIGN KEY (SupervisorID)
        REFERENCES STAFF(StaffID)
        ON DELETE NO ACTION,

    CONSTRAINT CK_Staff_Salary
        CHECK (Salary >= 0)
);

--TABLE 4: STAFF_SHIFT
CREATE TABLE STAFF_SHIFT (
    ShiftID INT IDENTITY(1,1) PRIMARY KEY,
    StaffID INT NOT NULL,
    ShiftDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,

    CONSTRAINT FK_StaffShift_Staff
        FOREIGN KEY (StaffID)
        REFERENCES STAFF(StaffID)
        ON DELETE CASCADE,

    CONSTRAINT CK_StaffShift_Time
        CHECK (EndTime > StartTime),

    CONSTRAINT UQ_StaffShift
        UNIQUE (StaffID, ShiftDate, StartTime)
);


-- TABLE 5: HABITAT
CREATE TABLE HABITAT (
    HabitatID INT IDENTITY(1,1) PRIMARY KEY,
    ZooID INT NOT NULL,
    Name VARCHAR(80) NOT NULL,
    BiomeType VARCHAR(50) NOT NULL,
    Climate VARCHAR(50),
    AreaSqm DECIMAL(10,2),

    FOREIGN KEY (ZooID) REFERENCES dbo.ZOO(ZooID),
    UNIQUE (ZooID, Name),
    CHECK (AreaSqm > 0)
);


-- TABLE 6: ENCLOSURE
CREATE TABLE ENCLOSURE (
    EnclosureID INT IDENTITY(1,1) PRIMARY KEY,
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


-- TABLE 7: CONSERVATION_STATUS
CREATE TABLE CONSERVATION_STATUS (
    StatusID INT IDENTITY(1,1) PRIMARY KEY,
    Code VARCHAR(5) NOT NULL UNIQUE,
    Name VARCHAR(50) NOT NULL,
    Description VARCHAR(255)
);


-- TABLE 8: SPECIES
CREATE TABLE SPECIES (
    SpeciesID INT IDENTITY(1,1) PRIMARY KEY,
    StatusID INT NOT NULL,
    CommonName VARCHAR(80) NOT NULL,
    ScientificName VARCHAR(100) NOT NULL UNIQUE,
    DietType VARCHAR(30),
    AvgLifespanYears INT,

    FOREIGN KEY (StatusID) REFERENCES CONSERVATION_STATUS(StatusID),
    CHECK (DietType IN ('Carnivore', 'Herbivore', 'Omnivore', 'Insectivore')),
    CHECK (AvgLifespanYears > 0)
);


-- TABLE 9: ANIMAL
CREATE TABLE ANIMAL (
    AnimalID INT IDENTITY(1,1) PRIMARY KEY,
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


-- TABLE 10: ANIMAL_TRANSFER
CREATE TABLE ANIMAL_TRANSFER (
    TransferID INT IDENTITY(1,1) PRIMARY KEY,
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



-- TABLE 11: FOOD_TYPE
CREATE TABLE FOOD_TYPE (
    FoodID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(80) NOT NULL UNIQUE,
    Category VARCHAR(30),
    Unit VARCHAR(10) NOT NULL,
    CaloriesPerUnit DECIMAL(8,2),

    CHECK (Category IN ('Meat', 'Fish', 'Fruit',
                       'Vegetable', 'Grain', 'Insect',
                       'Supplement')),
    CHECK (CaloriesPerUnit >= 0)
);


-- TABLE 12: SUPPLIER
CREATE TABLE SUPPLIER (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE,
    ContactPerson VARCHAR(80),
    Phone VARCHAR(20),
    Address VARCHAR(200)
);


-- TABLE 13: FOOD_STOCK
CREATE TABLE FOOD_STOCK (
    StockID INT IDENTITY(1,1) PRIMARY KEY,
    FoodID INT NOT NULL,
    SupplierID INT NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    PurchaseDate DATE NOT NULL,
    ExpiryDate DATE,

    FOREIGN KEY (FoodID) REFERENCES dbo.FOOD_TYPE(FoodID),
    FOREIGN KEY (SupplierID) REFERENCES dbo.SUPPLIER(SupplierID),
    CHECK (Quantity > 0),
    CHECK (UnitPrice >= 0),
    CHECK (ExpiryDate > PurchaseDate)
);


-- TABLE 14: FEEDING_PLAN
CREATE TABLE FEEDING_PLAN (
    PlanID INT IDENTITY(1,1) PRIMARY KEY,
    AnimalID INT NOT NULL,
    FoodID INT NOT NULL,
    QuantityPerMeal DECIMAL(8,2) NOT NULL,
    FeedingTime TIME NOT NULL,
    Frequency VARCHAR(30),

    FOREIGN KEY (AnimalID) REFERENCES dbo.ANIMAL(AnimalID),
    FOREIGN KEY (FoodID) REFERENCES dbo.FOOD_TYPE(FoodID),
    CHECK (QuantityPerMeal > 0),
    UNIQUE (AnimalID, FoodID, FeedingTime)
);


-- TABLE 15: FEEDING_LOG
CREATE TABLE FEEDING_LOG (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    PlanID INT NOT NULL,
    StaffID INT NOT NULL,
    FedAt DATETIME2 NOT NULL,
    QuantityGiven DECIMAL(8,2) NOT NULL,
    Notes VARCHAR(255),

    FOREIGN KEY (PlanID) REFERENCES dbo.FEEDING_PLAN(PlanID),
    FOREIGN KEY (StaffID) REFERENCES dbo.STAFF(StaffID),
    CHECK (QuantityGiven >= 0)
);
