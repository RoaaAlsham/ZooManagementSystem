/* =====================================================================
   Zoo Management System - SQL Server (T-SQL)
   ZooDB_FULL.sql  ->  ONE file that does everything:
     1) deletes the old ZooDB (if it exists)
     2) creates ZooDB and the 20 tables
     3) inserts the sample data
   HOW TO RUN: File > Open > File... > choose this file,
   click once inside the text (select NOTHING), press F5.
   ===================================================================== */

USE master;
GO

IF DB_ID('ZooDB') IS NOT NULL
BEGIN
    ALTER DATABASE ZooDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ZooDB;
END
GO

IF DB_ID('ZooDB') IS NULL
    CREATE DATABASE ZooDB;
GO

USE ZooDB;
GO

-- 1 ZOO
CREATE TABLE ZOO (
    ZooID     INT IDENTITY(1,1) PRIMARY KEY,
    Name      NVARCHAR(100) NOT NULL,
    City      NVARCHAR(60)  NOT NULL,
    Address   NVARCHAR(200),
    Phone     NVARCHAR(20),
    OpenDate  DATE
);

-- 2 DEPARTMENT
CREATE TABLE DEPARTMENT (
    DepartmentID  INT IDENTITY(1,1) PRIMARY KEY,
    ZooID         INT NOT NULL,
    Name          NVARCHAR(80) NOT NULL,
    Description   NVARCHAR(255),
    FOREIGN KEY (ZooID) REFERENCES ZOO(ZooID),
    UNIQUE (ZooID, Name)
);

-- 3 STAFF
CREATE TABLE STAFF (
    StaffID       INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentID  INT NOT NULL,
    SupervisorID  INT,
    FirstName     NVARCHAR(50)  NOT NULL,
    LastName      NVARCHAR(50)  NOT NULL,
    Role          NVARCHAR(50)  NOT NULL,
    Phone         NVARCHAR(20),
    Email         NVARCHAR(100) UNIQUE,
    HireDate      DATE NOT NULL,
    Salary        DECIMAL(10,2),
    PasswordHash  NVARCHAR(255),
    FOREIGN KEY (DepartmentID) REFERENCES DEPARTMENT(DepartmentID),
    FOREIGN KEY (SupervisorID) REFERENCES STAFF(StaffID),
    CHECK (Salary >= 0),
    CHECK (Role IN ('Manager', 'Keeper', 'Veterinarian', 'Cashier', 'Maintenance'))
);

-- 4 STAFF_SHIFT
CREATE TABLE STAFF_SHIFT (
    ShiftID    INT IDENTITY(1,1) PRIMARY KEY,
    StaffID    INT  NOT NULL,
    ShiftDate  DATE NOT NULL,
    StartTime  TIME NOT NULL,
    EndTime    TIME NOT NULL,
    FOREIGN KEY (StaffID) REFERENCES STAFF(StaffID) ON DELETE CASCADE,
    CHECK (EndTime > StartTime),
    UNIQUE (StaffID, ShiftDate, StartTime)
);

-- 5 HABITAT
CREATE TABLE HABITAT (
    HabitatID  INT IDENTITY(1,1) PRIMARY KEY,
    ZooID      INT NOT NULL,
    Name       NVARCHAR(80) NOT NULL,
    BiomeType  NVARCHAR(50) NOT NULL,
    Climate    NVARCHAR(50),
    AreaSqm    DECIMAL(10,2),
    FOREIGN KEY (ZooID) REFERENCES ZOO(ZooID),
    UNIQUE (ZooID, Name),
    CHECK (AreaSqm > 0)
);

-- 6 ENCLOSURE
CREATE TABLE ENCLOSURE (
    EnclosureID      INT IDENTITY(1,1) PRIMARY KEY,
    HabitatID        INT NOT NULL,
    Name             NVARCHAR(80) NOT NULL,
    Capacity         INT NOT NULL,
    Condition        NVARCHAR(30),
    LastMaintenance  DATE,
    FOREIGN KEY (HabitatID) REFERENCES HABITAT(HabitatID),
    UNIQUE (HabitatID, Name),
    CHECK (Capacity > 0),
    CHECK (Condition IN ('Good', 'Needs Repair', 'Under Maintenance'))
);

-- 7 CONSERVATION_STATUS
CREATE TABLE CONSERVATION_STATUS (
    StatusID     INT IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(5)  NOT NULL UNIQUE,
    Name         NVARCHAR(50) NOT NULL,
    Description  NVARCHAR(255)
);

-- 8 SPECIES
CREATE TABLE SPECIES (
    SpeciesID         INT IDENTITY(1,1) PRIMARY KEY,
    StatusID          INT NOT NULL,
    CommonName        NVARCHAR(80)  NOT NULL,
    ScientificName    NVARCHAR(100) NOT NULL UNIQUE,
    DietType          NVARCHAR(30),
    AvgLifespanYears  INT,
    FOREIGN KEY (StatusID) REFERENCES CONSERVATION_STATUS(StatusID),
    CHECK (DietType IN ('Carnivore', 'Herbivore', 'Omnivore', 'Insectivore')),
    CHECK (AvgLifespanYears > 0)
);

-- 9 ANIMAL
CREATE TABLE ANIMAL (
    AnimalID      INT IDENTITY(1,1) PRIMARY KEY,
    SpeciesID     INT NOT NULL,
    EnclosureID   INT,
    Name          NVARCHAR(60) NOT NULL,
    Gender        NVARCHAR(10),
    BirthDate     DATE,
    ArrivalDate   DATE NOT NULL,
    Origin        NVARCHAR(100),
    HealthStatus  NVARCHAR(30),
    FOREIGN KEY (SpeciesID)   REFERENCES SPECIES(SpeciesID),
    FOREIGN KEY (EnclosureID) REFERENCES ENCLOSURE(EnclosureID),
    CHECK (Gender IN ('Male', 'Female', 'Unknown')),
    CHECK (HealthStatus IN ('Healthy', 'Under Treatment', 'Quarantine', 'Deceased')),
    CHECK (BirthDate IS NULL OR ArrivalDate >= BirthDate)
);

-- 10 ANIMAL_TRANSFER
CREATE TABLE ANIMAL_TRANSFER (
    TransferID       INT IDENTITY(1,1) PRIMARY KEY,
    AnimalID         INT  NOT NULL,
    FromEnclosureID  INT  NOT NULL,
    ToEnclosureID    INT  NOT NULL,
    TransferDate     DATE NOT NULL,
    Reason           NVARCHAR(200),
    FOREIGN KEY (AnimalID)        REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (FromEnclosureID) REFERENCES ENCLOSURE(EnclosureID),
    FOREIGN KEY (ToEnclosureID)   REFERENCES ENCLOSURE(EnclosureID),
    CHECK (FromEnclosureID <> ToEnclosureID)
);

-- 11 FOOD_TYPE
CREATE TABLE FOOD_TYPE (
    FoodID           INT IDENTITY(1,1) PRIMARY KEY,
    Name             NVARCHAR(80) NOT NULL UNIQUE,
    Category         NVARCHAR(30),
    Unit             NVARCHAR(10) NOT NULL,
    CaloriesPerUnit  DECIMAL(8,2),
    CHECK (Category IN ('Meat', 'Fish', 'Fruit', 'Vegetable', 'Grain', 'Insect', 'Supplement')),
    CHECK (CaloriesPerUnit >= 0)
);

-- 12 SUPPLIER
CREATE TABLE SUPPLIER (
    SupplierID     INT IDENTITY(1,1) PRIMARY KEY,
    Name           NVARCHAR(100) NOT NULL UNIQUE,
    ContactPerson  NVARCHAR(80),
    Phone          NVARCHAR(20),
    Address        NVARCHAR(200)
);

-- 13 FOOD_STOCK
CREATE TABLE FOOD_STOCK (
    StockID       INT IDENTITY(1,1) PRIMARY KEY,
    FoodID        INT NOT NULL,
    SupplierID    INT NOT NULL,
    Quantity      DECIMAL(10,2) NOT NULL,
    UnitPrice     DECIMAL(10,2) NOT NULL,
    PurchaseDate  DATE NOT NULL,
    ExpiryDate    DATE,
    FOREIGN KEY (FoodID)     REFERENCES FOOD_TYPE(FoodID),
    FOREIGN KEY (SupplierID) REFERENCES SUPPLIER(SupplierID),
    CHECK (Quantity > 0),
    CHECK (UnitPrice >= 0),
    CHECK (ExpiryDate IS NULL OR ExpiryDate > PurchaseDate)
);

-- 14 FEEDING_PLAN
CREATE TABLE FEEDING_PLAN (
    PlanID           INT IDENTITY(1,1) PRIMARY KEY,
    AnimalID         INT NOT NULL,
    FoodID           INT NOT NULL,
    QuantityPerMeal  DECIMAL(8,2) NOT NULL,
    FeedingTime      TIME NOT NULL,
    Frequency        NVARCHAR(30),
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (FoodID)   REFERENCES FOOD_TYPE(FoodID),
    CHECK (QuantityPerMeal > 0),
    UNIQUE (AnimalID, FoodID, FeedingTime)
);

-- 15 FEEDING_LOG
CREATE TABLE FEEDING_LOG (
    LogID          INT IDENTITY(1,1) PRIMARY KEY,
    PlanID         INT NOT NULL,
    StaffID        INT NOT NULL,
    FedAt          DATETIME2(0) NOT NULL,
    QuantityGiven  DECIMAL(8,2) NOT NULL,
    Notes          NVARCHAR(255),
    FOREIGN KEY (PlanID)  REFERENCES FEEDING_PLAN(PlanID),
    FOREIGN KEY (StaffID) REFERENCES STAFF(StaffID),
    CHECK (QuantityGiven >= 0)
);

-- 16 CARE_ASSIGNMENT
CREATE TABLE CARE_ASSIGNMENT (
    AssignmentID    INT IDENTITY(1,1) PRIMARY KEY,
    StaffID         INT  NOT NULL,
    AnimalID        INT  NOT NULL,
    StartDate       DATE NOT NULL,
    EndDate         DATE,
    Responsibility  NVARCHAR(100),
    FOREIGN KEY (StaffID)  REFERENCES STAFF(StaffID),
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    CHECK (EndDate IS NULL OR EndDate >= StartDate),
    UNIQUE (StaffID, AnimalID, StartDate)
);

-- 17 MEDICAL_RECORD
CREATE TABLE MEDICAL_RECORD (
    RecordID     INT IDENTITY(1,1) PRIMARY KEY,
    AnimalID     INT  NOT NULL,
    VetID        INT  NOT NULL,
    CheckupDate  DATE NOT NULL,
    Diagnosis    NVARCHAR(255),
    Treatment    NVARCHAR(255),
    NextCheckup  DATE,
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (VetID)    REFERENCES STAFF(StaffID),
    CHECK (NextCheckup IS NULL OR NextCheckup > CheckupDate)
);

-- 18 VACCINATION
CREATE TABLE VACCINATION (
    VaccinationID  INT IDENTITY(1,1) PRIMARY KEY,
    AnimalID       INT  NOT NULL,
    VetID          INT  NOT NULL,
    VaccineName    NVARCHAR(100) NOT NULL,
    DateGiven      DATE NOT NULL,
    NextDue        DATE,
    FOREIGN KEY (AnimalID) REFERENCES ANIMAL(AnimalID),
    FOREIGN KEY (VetID)    REFERENCES STAFF(StaffID),
    CHECK (NextDue IS NULL OR NextDue > DateGiven)
);

-- 19 TICKET_TYPE
CREATE TABLE TICKET_TYPE (
    TicketTypeID  INT IDENTITY(1,1) PRIMARY KEY,
    Name          NVARCHAR(50) NOT NULL UNIQUE,
    Price         DECIMAL(8,2) NOT NULL,
    Description   NVARCHAR(200),
    CHECK (Price >= 0)
);

-- 20 TICKET
CREATE TABLE TICKET (
    TicketID       INT IDENTITY(1,1) PRIMARY KEY,
    TicketTypeID   INT  NOT NULL,
    SoldByStaffID  INT,
    VisitDate      DATE NOT NULL,
    PurchasedAt    DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    Quantity       INT NOT NULL,
    TotalPrice     DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (TicketTypeID)  REFERENCES TICKET_TYPE(TicketTypeID),
    FOREIGN KEY (SoldByStaffID) REFERENCES STAFF(StaffID) ON DELETE SET NULL,
    CHECK (Quantity > 0),
    CHECK (TotalPrice >= 0)
);
GO

PRINT 'ZooDB: 20 tables created.';




USE ZooDB;
GO

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Pwd NVARCHAR(255) = CONVERT(NVARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2);

-- ZOO
INSERT INTO ZOO (Name, City, Address, Phone, OpenDate) VALUES
('Istanbul Wildlife Park', 'Istanbul', 'Fatih Cad. No:1', '0212 000 00 00', '2010-05-01');

-- DEPARTMENT (1..5)
INSERT INTO DEPARTMENT (ZooID, Name, Description) VALUES
(1, 'Administration', 'Zoo management and planning'),
(1, 'Animal Care',    'Daily care and feeding of animals'),
(1, 'Veterinary',     'Animal health, checkups and vaccines'),
(1, 'Ticketing',      'Visitor ticket sales'),
(1, 'Maintenance',    'Repair and cleaning of enclosures');

-- STAFF (1..9) - supervisor (1) is inserted first
INSERT INTO STAFF (DepartmentID, SupervisorID, FirstName, LastName, Role, Phone, Email, HireDate, Salary, PasswordHash) VALUES
(1, NULL, 'Ayse',   'Yilmaz', 'Manager',      '0532 100 00 01', 'manager@zoo.com',  '2015-03-01', 65000, @Pwd);
INSERT INTO STAFF (DepartmentID, SupervisorID, FirstName, LastName, Role, Phone, Email, HireDate, Salary, PasswordHash) VALUES
(2, 1, 'Mehmet', 'Kaya',   'Keeper',       '0532 100 00 02', 'keeper1@zoo.com',  '2018-06-15', 32000, @Pwd),
(2, 1, 'Zeynep', 'Demir',  'Keeper',       '0532 100 00 03', 'keeper2@zoo.com',  '2019-09-01', 31000, @Pwd),
(2, 1, 'Ali',    'Celik',  'Keeper',       '0532 100 00 04', 'keeper3@zoo.com',  '2021-02-10', 29000, @Pwd),
(3, 1, 'Elif',   'Sahin',  'Veterinarian', '0532 100 00 05', 'vet1@zoo.com',     '2016-11-20', 55000, @Pwd),
(3, 5, 'Can',    'Aydin',  'Veterinarian', '0532 100 00 06', 'vet2@zoo.com',     '2020-04-05', 48000, @Pwd),
(4, 1, 'Selin',  'Ozturk', 'Cashier',      '0532 100 00 07', 'cashier1@zoo.com', '2022-01-10', 25000, @Pwd),
(4, 7, 'Burak',  'Arslan', 'Cashier',      '0532 100 00 08', 'cashier2@zoo.com', '2023-05-15', 24000, @Pwd),
(5, 1, 'Hakan',  'Koc',    'Maintenance',  '0532 100 00 09', 'maint1@zoo.com',   '2017-07-01', 27000, @Pwd);

-- STAFF_SHIFT
INSERT INTO STAFF_SHIFT (StaffID, ShiftDate, StartTime, EndTime) VALUES
(2, @Today,                  '07:00', '15:00'),
(3, @Today,                  '07:00', '15:00'),
(4, @Today,                  '12:00', '20:00'),
(5, @Today,                  '08:00', '16:00'),
(7, @Today,                  '09:00', '17:00'),
(8, @Today,                  '12:00', '20:00'),
(2, DATEADD(DAY, 1, @Today), '07:00', '15:00'),
(6, DATEADD(DAY, 1, @Today), '08:00', '16:00');

-- HABITAT (1..4)
INSERT INTO HABITAT (ZooID, Name, BiomeType, Climate, AreaSqm) VALUES
(1, 'African Savanna', 'Savanna',    'Arid',      12000),
(1, 'Tropical Forest', 'Rainforest', 'Tropical',   6000),
(1, 'Polar World',     'Polar',      'Cold',       2500),
(1, 'Ocean Zone',      'Aquatic',    'Temperate',  4000);

-- ENCLOSURE (1..7)
INSERT INTO ENCLOSURE (HabitatID, Name, Capacity, Condition, LastMaintenance) VALUES
(1, 'Lion Pride Area', 4,  'Good',              DATEADD(DAY, -40, @Today)),
(1, 'Giraffe Yard',    5,  'Good',              DATEADD(DAY, -25, @Today)),
(2, 'Primate House',   6,  'Needs Repair',      DATEADD(DAY, -200, @Today)),
(2, 'Reptile Hall',    8,  'Good',              DATEADD(DAY, -15, @Today)),
(3, 'Penguin Cove',    10, 'Good',              DATEADD(DAY, -10, @Today)),
(4, 'Dolphin Pool',    3,  'Under Maintenance', DATEADD(DAY, -2, @Today)),
(1, 'Zebra Plains',    6,  'Good',              DATEADD(DAY, -60, @Today));

-- CONSERVATION_STATUS (1..7)
INSERT INTO CONSERVATION_STATUS (Code, Name, Description) VALUES
('LC', 'Least Concern',         'Widespread and abundant'),
('NT', 'Near Threatened',       'Close to qualifying for a threatened category'),
('VU', 'Vulnerable',            'High risk of extinction in the wild'),
('EN', 'Endangered',            'Very high risk of extinction in the wild'),
('CR', 'Critically Endangered', 'Extremely high risk of extinction in the wild'),
('EW', 'Extinct in the Wild',   'Survives only in captivity'),
('EX', 'Extinct',               'No known individuals remaining');

-- SPECIES (1..8)
INSERT INTO SPECIES (StatusID, CommonName, ScientificName, DietType, AvgLifespanYears) VALUES
(3, 'African Lion',       'Panthera leo',           'Carnivore', 14),
(3, 'Giraffe',            'Giraffa camelopardalis', 'Herbivore', 25),
(4, 'Chimpanzee',         'Pan troglodytes',        'Omnivore',  40),
(1, 'Green Iguana',       'Iguana iguana',          'Herbivore', 15),
(2, 'Gentoo Penguin',     'Pygoscelis papua',       'Carnivore', 15),
(1, 'Bottlenose Dolphin', 'Tursiops truncatus',     'Carnivore', 40),
(2, 'Plains Zebra',       'Equus quagga',           'Herbivore', 25),
(5, 'Sumatran Orangutan', 'Pongo abelii',           'Omnivore',  45);

-- ANIMAL (1..12)
INSERT INTO ANIMAL (SpeciesID, EnclosureID, Name, Gender, BirthDate, ArrivalDate, Origin, HealthStatus) VALUES
(1, 1,    'Leo',     'Male',    '2016-04-10', '2018-01-15', 'Exchanged from Ankara Zoo', 'Healthy'),
(1, 1,    'Nala',    'Female',  '2017-08-02', '2018-01-15', 'Exchanged from Ankara Zoo', 'Healthy'),
(2, 2,    'Stretch', 'Male',    '2014-05-20', '2015-03-01', 'Born in captivity',         'Healthy'),
(3, 3,    'Koko',    'Female',  '2009-02-14', '2012-06-30', 'Rescued',                   'Under Treatment'),
(3, 3,    'Bongo',   'Male',    '2011-11-11', '2013-09-12', 'Rescued',                   'Healthy'),
(4, 4,    'Iggy',    'Unknown', '2020-03-01', '2021-05-05', 'Donated',                   'Healthy'),
(5, 5,    'Pingu',   'Male',    '2019-12-12', '2020-02-20', 'Born in zoo',               'Healthy'),
(5, 5,    'Waddles', 'Female',  '2020-01-05', '2020-02-20', 'Born in zoo',               'Quarantine'),
(6, NULL, 'Flipper', 'Female',  '2012-07-07', '2014-08-08', 'Exchanged',                 'Under Treatment'),
(7, 7,    'Ziggy',   'Male',    '2015-09-09', '2016-10-10', 'Born in captivity',         'Healthy'),
(8, 3,    'Mina',    'Female',  '2005-06-06', '2010-04-04', 'Rescued',                   'Healthy'),
(2, 2,    'Lulu',    'Female',  '2018-04-04', '2019-01-01', 'Born in zoo',               'Healthy');

-- ANIMAL_TRANSFER
INSERT INTO ANIMAL_TRANSFER (AnimalID, FromEnclosureID, ToEnclosureID, TransferDate, Reason) VALUES
(11, 4, 3, '2023-05-10', 'Moved to the primate group'),
(10, 2, 7, '2021-03-01', 'More space in Zebra Plains');

-- FOOD_TYPE (1..9)
INSERT INTO FOOD_TYPE (Name, Category, Unit, CaloriesPerUnit) VALUES
('Beef',             'Meat',       'kg',    2500),
('Chicken',          'Meat',       'kg',    1650),
('Herring',          'Fish',       'kg',    1580),
('Hay',              'Grain',      'kg',     900),
('Acacia Leaves',    'Vegetable',  'kg',     600),
('Bananas',          'Fruit',      'kg',     890),
('Mixed Vegetables', 'Vegetable',  'kg',     400),
('Vitamin Mix',      'Supplement', 'piece',   10),
('Crickets',         'Insect',     'kg',    1200);

-- SUPPLIER (1..3)
INSERT INTO SUPPLIER (Name, ContactPerson, Phone, Address) VALUES
('Anadolu Meat Co.',    'Murat Er',     '0216 111 11 11', 'Kadikoy, Istanbul'),
('Marmara Fish Ltd.',   'Deniz Su',     '0216 222 22 22', 'Tuzla, Istanbul'),
('Green Farm Produce',  'Ayla Yesil',   '0262 333 33 33', 'Izmit, Kocaeli');

-- FOOD_STOCK
INSERT INTO FOOD_STOCK (FoodID, SupplierID, Quantity, UnitPrice, PurchaseDate, ExpiryDate) VALUES
(1, 1, 200, 350, DATEADD(DAY, -20, @Today), DATEADD(DAY, 10,  @Today)),
(2, 1, 100, 180, DATEADD(DAY, -10, @Today), DATEADD(DAY, 5,   @Today)),
(3, 2, 150, 220, DATEADD(DAY, -7,  @Today), DATEADD(DAY, 7,   @Today)),
(4, 3, 500, 15,  DATEADD(DAY, -30, @Today), DATEADD(DAY, 150, @Today)),
(5, 3, 120, 40,  DATEADD(DAY, -5,  @Today), DATEADD(DAY, 9,   @Today)),
(6, 3, 80,  30,  DATEADD(DAY, -3,  @Today), DATEADD(DAY, 4,   @Today)),
(7, 3, 100, 25,  DATEADD(DAY, -2,  @Today), DATEADD(DAY, 6,   @Today)),
(8, 3, 500, 5,   DATEADD(DAY, -60, @Today), DATEADD(DAY, 300, @Today));

-- FEEDING_PLAN (1..13)
INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency) VALUES
(1,  1, 7,   '09:00', 'Daily'),
(2,  1, 6,   '09:00', 'Daily'),
(3,  5, 15,  '08:00', 'Daily'),
(3,  4, 10,  '16:00', 'Daily'),
(4,  6, 1.5, '10:00', 'Daily'),
(5,  6, 2,   '10:00', 'Daily'),
(6,  7, 0.3, '11:00', 'Daily'),
(7,  3, 1,   '12:00', 'Daily'),
(8,  3, 1,   '12:00', 'Daily'),
(10, 4, 9,   '08:30', 'Daily'),
(11, 6, 2,   '10:30', 'Daily'),
(12, 5, 12,  '08:00', 'Daily'),
(9,  3, 8,   '13:00', 'Daily');

-- FEEDING_LOG (some feedings done today, some yesterday)
INSERT INTO FEEDING_LOG (PlanID, StaffID, FedAt, QuantityGiven, Notes) VALUES
(3,  2, DATEADD(MINUTE, 490,  CAST(@Today AS DATETIME2(0))), 15,  'Ate well'),
(12, 2, DATEADD(MINUTE, 492,  CAST(@Today AS DATETIME2(0))), 12,  NULL),
(10, 4, DATEADD(MINUTE, 515,  CAST(@Today AS DATETIME2(0))), 9,   NULL),
(1,  2, DATEADD(MINUTE, 545,  CAST(@Today AS DATETIME2(0))), 7,   NULL),
(2,  2, DATEADD(MINUTE, 546,  CAST(@Today AS DATETIME2(0))), 5,   'Left some food'),
(1,  2, DATEADD(MINUTE, -895, CAST(@Today AS DATETIME2(0))), 7,   NULL),
(2,  2, DATEADD(MINUTE, -894, CAST(@Today AS DATETIME2(0))), 6,   NULL),
(3,  3, DATEADD(MINUTE, -955, CAST(@Today AS DATETIME2(0))), 15,  NULL),
(5,  3, DATEADD(MINUTE, -840, CAST(@Today AS DATETIME2(0))), 1,   'Low appetite'),
(6,  3, DATEADD(MINUTE, -840, CAST(@Today AS DATETIME2(0))), 2,   NULL);

-- CARE_ASSIGNMENT
INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, EndDate, Responsibility) VALUES
(2, 1,  '2018-01-15', NULL,         'Daily care'),
(2, 2,  '2018-01-15', NULL,         'Daily care'),
(2, 3,  '2019-01-01', NULL,         'Daily care'),
(2, 12, '2019-01-01', NULL,         'Daily care'),
(3, 4,  '2019-09-01', NULL,         'Daily care'),
(3, 5,  '2019-09-01', NULL,         'Daily care'),
(3, 11, '2019-09-01', NULL,         'Training'),
(3, 9,  '2020-01-01', NULL,         'Feeding'),
(4, 6,  '2021-05-05', NULL,         'Daily care'),
(4, 7,  '2021-02-10', NULL,         'Feeding'),
(4, 8,  '2021-02-10', NULL,         'Feeding'),
(4, 10, '2021-03-01', NULL,         'Daily care'),
(4, 1,  '2018-01-15', '2019-12-31', 'Feeding');

-- MEDICAL_RECORD (two overdue follow-ups for the vet queue)
INSERT INTO MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup) VALUES
(4, 5, DATEADD(DAY, -14, @Today), 'Respiratory infection',  'Antibiotics for 10 days', DATEADD(DAY, -2,  @Today)),
(9, 6, DATEADD(DAY, -30, @Today), 'Skin lesion',            'Topical treatment',       DATEADD(DAY, -5,  @Today)),
(1, 5, DATEADD(DAY, -60, @Today), 'Routine checkup',        'None',                    DATEADD(DAY, 120, @Today)),
(8, 6, DATEADD(DAY, -3,  @Today), 'Quarantine intake exam', 'Observation',             DATEADD(DAY, 11,  @Today)),
(3, 5, DATEADD(DAY, -90, @Today), 'Hoof check',             'Hoof trimming',           DATEADD(DAY, 90,  @Today));

-- VACCINATION (some due soon, one overdue)
INSERT INTO VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue) VALUES
(1,  5, 'Rabies',          DATEADD(DAY, -350, @Today), DATEADD(DAY, 15,  @Today)),
(2,  5, 'Rabies',          DATEADD(DAY, -350, @Today), DATEADD(DAY, 15,  @Today)),
(7,  6, 'Avian Influenza', DATEADD(DAY, -200, @Today), DATEADD(DAY, -5,  @Today)),
(3,  5, 'Tetanus',         DATEADD(DAY, -100, @Today), DATEADD(DAY, 265, @Today)),
(10, 6, 'Tetanus',         DATEADD(DAY, -380, @Today), DATEADD(DAY, 10,  @Today));

-- TICKET_TYPE (1..5)
INSERT INTO TICKET_TYPE (Name, Price, Description) VALUES
('Adult',   250, 'Visitors aged 18-64'),
('Child',   120, 'Children aged 3-17'),
('Student', 150, 'With a valid student ID'),
('Senior',  100, 'Visitors aged 65 and over'),
('Family',  600, '2 adults + 2 children');

-- TICKET (TotalPrice = Quantity x Price)
INSERT INTO TICKET (TicketTypeID, SoldByStaffID, VisitDate, PurchasedAt, Quantity, TotalPrice) VALUES
(1, 7,    @Today,                   DATEADD(MINUTE, 615,  CAST(@Today AS DATETIME2(0))), 2, 500),
(2, 7,    @Today,                   DATEADD(MINUTE, 616,  CAST(@Today AS DATETIME2(0))), 2, 240),
(5, 8,    @Today,                   DATEADD(MINUTE, 660,  CAST(@Today AS DATETIME2(0))), 1, 600),
(3, 8,    @Today,                   DATEADD(MINUTE, 690,  CAST(@Today AS DATETIME2(0))), 3, 450),
(1, NULL, DATEADD(DAY, 1, @Today),  DATEADD(MINUTE, -240, CAST(@Today AS DATETIME2(0))), 4, 1000),
(4, 7,    DATEADD(DAY, -1, @Today), DATEADD(MINUTE, -600, CAST(@Today AS DATETIME2(0))), 2, 200);

PRINT 'ZooDB: sample data inserted.';
GO

-- Quick check: row count of every table
SELECT 'ZOO' AS TableName, COUNT(*) AS Rows FROM ZOO
UNION ALL SELECT 'DEPARTMENT', COUNT(*) FROM DEPARTMENT
UNION ALL SELECT 'STAFF', COUNT(*) FROM STAFF
UNION ALL SELECT 'STAFF_SHIFT', COUNT(*) FROM STAFF_SHIFT
UNION ALL SELECT 'HABITAT', COUNT(*) FROM HABITAT
UNION ALL SELECT 'ENCLOSURE', COUNT(*) FROM ENCLOSURE
UNION ALL SELECT 'CONSERVATION_STATUS', COUNT(*) FROM CONSERVATION_STATUS
UNION ALL SELECT 'SPECIES', COUNT(*) FROM SPECIES
UNION ALL SELECT 'ANIMAL', COUNT(*) FROM ANIMAL
UNION ALL SELECT 'ANIMAL_TRANSFER', COUNT(*) FROM ANIMAL_TRANSFER
UNION ALL SELECT 'FOOD_TYPE', COUNT(*) FROM FOOD_TYPE
UNION ALL SELECT 'SUPPLIER', COUNT(*) FROM SUPPLIER
UNION ALL SELECT 'FOOD_STOCK', COUNT(*) FROM FOOD_STOCK
UNION ALL SELECT 'FEEDING_PLAN', COUNT(*) FROM FEEDING_PLAN
UNION ALL SELECT 'FEEDING_LOG', COUNT(*) FROM FEEDING_LOG
UNION ALL SELECT 'CARE_ASSIGNMENT', COUNT(*) FROM CARE_ASSIGNMENT
UNION ALL SELECT 'MEDICAL_RECORD', COUNT(*) FROM MEDICAL_RECORD
UNION ALL SELECT 'VACCINATION', COUNT(*) FROM VACCINATION
UNION ALL SELECT 'TICKET_TYPE', COUNT(*) FROM TICKET_TYPE
UNION ALL SELECT 'TICKET', COUNT(*) FROM TICKET;
