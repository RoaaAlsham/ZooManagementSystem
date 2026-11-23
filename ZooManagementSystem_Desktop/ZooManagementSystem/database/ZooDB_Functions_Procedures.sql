/* =====================================================================
   Zoo Management System - SQL Server (T-SQL)
   ZooDB_Functions_Procedures.sql

   SUBMISSION_PLAN Phase 1 - section 2.2 (Functions) and 2.3 (Stored
   procedures with database-level transactions).

   HOW TO RUN (after ZooDB_FULL.sql):
     SSMS > File > Open > File... > choose this file > click inside the
     text (select nothing) > F5.
   The script can be run again at any time (CREATE OR ALTER).

   Contents
     Functions
       F1  dbo.fn_EnclosureFreeSpaces(@EnclosureID)          -> INT
       F2  dbo.fn_TicketLineTotal(@TicketTypeID, @Quantity)   -> DECIMAL(10,2)
       F3  dbo.fn_IsFedToday(@PlanID)                         -> BIT
     Stored procedures (each one runs inside BEGIN TRANSACTION /
     COMMIT TRANSACTION, and ROLLBACK TRANSACTION on any error)
       P1  dbo.usp_TransferAnimal      ANIMAL_TRANSFER + ANIMAL
       P2  dbo.usp_MarkAnimalDeceased  ANIMAL + CARE_ASSIGNMENT
       P3  dbo.usp_RegisterCheckup     MEDICAL_RECORD + ANIMAL
       P4  dbo.usp_SellTicket          TICKET (price from TICKET_TYPE)
       P5  dbo.usp_LogFeeding          FEEDING_LOG (no double logging)

   Business-rule errors are raised with THROW and these error numbers:
     50001-50007  usp_TransferAnimal
     50011-50012  usp_MarkAnimalDeceased
     50021-50024  usp_RegisterCheckup
     50031-50034  usp_SellTicket
     50041-50045  usp_LogFeeding
   ===================================================================== */

USE ZooDB;
GO

/* =====================================================================
   F1  fn_EnclosureFreeSpaces
   Capacity minus the number of living animals in the enclosure.
   Returns NULL if the enclosure does not exist.
   Used by: usp_TransferAnimal
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_EnclosureFreeSpaces (@EnclosureID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Capacity INT;
    DECLARE @Living INT;

    SELECT @Capacity = Capacity
    FROM dbo.ENCLOSURE
    WHERE EnclosureID = @EnclosureID;

    IF @Capacity IS NULL
        RETURN NULL;

    SELECT @Living = COUNT(*)
    FROM dbo.ANIMAL
    WHERE EnclosureID = @EnclosureID
      AND (HealthStatus IS NULL OR HealthStatus <> 'Deceased');

    RETURN @Capacity - @Living;
END;
GO

/* =====================================================================
   F2  fn_TicketLineTotal
   Price x Quantity, with the price read from TICKET_TYPE.
   Returns NULL for an unknown ticket type or a quantity below 1.
   Used by: usp_SellTicket
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_TicketLineTotal (@TicketTypeID INT, @Quantity INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Price DECIMAL(8,2);

    SELECT @Price = Price
    FROM dbo.TICKET_TYPE
    WHERE TicketTypeID = @TicketTypeID;

    IF @Price IS NULL OR @Quantity IS NULL OR @Quantity < 1
        RETURN NULL;

    RETURN CAST(@Price * @Quantity AS DECIMAL(10,2));
END;
GO

/* =====================================================================
   F3  fn_IsFedToday
   1 if a FEEDING_LOG row exists for the feeding plan today, otherwise 0.
   Used by: usp_LogFeeding
   ===================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_IsFedToday (@PlanID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @DayStart DATETIME2(0) = CAST(CAST(GETDATE() AS DATE) AS DATETIME2(0));

    IF EXISTS (SELECT 1
               FROM dbo.FEEDING_LOG
               WHERE PlanID = @PlanID
                 AND FedAt >= @DayStart
                 AND FedAt <  DATEADD(DAY, 1, @DayStart))
        RETURN 1;

    RETURN 0;
END;
GO

/* =====================================================================
   P1  usp_TransferAnimal
   Moves an animal to another enclosure:
     INSERT ANIMAL_TRANSFER (history)  +  UPDATE ANIMAL.EnclosureID
   Rules: animal exists and is not deceased, has a current enclosure,
   From <> To, destination exists, is not under maintenance and has
   free space (fn_EnclosureFreeSpaces).
   Returns: TransferID
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_TransferAnimal
    @AnimalID      INT,
    @ToEnclosureID INT,
    @Reason        NVARCHAR(200) = NULL,
    @TransferDate  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FromEnclosureID INT;
    DECLARE @HealthStatus NVARCHAR(30);
    DECLARE @TransferID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @FromEnclosureID = EnclosureID,
               @HealthStatus    = HealthStatus
        FROM dbo.ANIMAL WITH (UPDLOCK)
        WHERE AnimalID = @AnimalID;

        IF @@ROWCOUNT = 0
            THROW 50001, N'Animal not found.', 1;
        IF @HealthStatus = 'Deceased'
            THROW 50002, N'A deceased animal cannot be transferred.', 1;
        IF @FromEnclosureID IS NULL
            THROW 50003, N'The animal has no current enclosure.', 1;
        IF @FromEnclosureID = @ToEnclosureID
            THROW 50004, N'The destination must be different from the current enclosure.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.ENCLOSURE WHERE EnclosureID = @ToEnclosureID)
            THROW 50005, N'Destination enclosure not found.', 1;
        IF EXISTS (SELECT 1 FROM dbo.ENCLOSURE
                   WHERE EnclosureID = @ToEnclosureID AND Condition = 'Under Maintenance')
            THROW 50006, N'The destination enclosure is under maintenance.', 1;
        IF dbo.fn_EnclosureFreeSpaces(@ToEnclosureID) <= 0
            THROW 50007, N'The destination enclosure is full.', 1;

        INSERT INTO dbo.ANIMAL_TRANSFER (AnimalID, FromEnclosureID, ToEnclosureID, TransferDate, Reason)
        VALUES (@AnimalID, @FromEnclosureID, @ToEnclosureID,
                COALESCE(@TransferDate, CAST(GETDATE() AS DATE)), @Reason);

        SET @TransferID = SCOPE_IDENTITY();

        UPDATE dbo.ANIMAL
        SET EnclosureID = @ToEnclosureID
        WHERE AnimalID = @AnimalID;

        COMMIT TRANSACTION;

        SELECT @TransferID AS TransferID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P2  usp_MarkAnimalDeceased
   UPDATE ANIMAL (HealthStatus = 'Deceased', EnclosureID = NULL)
   + UPDATE CARE_ASSIGNMENT (end all open assignments).
   History is kept; nothing is deleted.
   Returns: AnimalID, number of ended care assignments
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_MarkAnimalDeceased
    @AnimalID INT,
    @EndDate  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @HealthStatus NVARCHAR(30);
    DECLARE @EndedAssignments INT;
    SET @EndDate = COALESCE(@EndDate, CAST(GETDATE() AS DATE));

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @HealthStatus = HealthStatus
        FROM dbo.ANIMAL WITH (UPDLOCK)
        WHERE AnimalID = @AnimalID;

        IF @@ROWCOUNT = 0
            THROW 50011, N'Animal not found.', 1;
        IF @HealthStatus = 'Deceased'
            THROW 50012, N'The animal is already marked as deceased.', 1;

        UPDATE dbo.ANIMAL
        SET HealthStatus = 'Deceased',
            EnclosureID  = NULL
        WHERE AnimalID = @AnimalID;

        -- an assignment that starts after @EndDate ends on its own start date (CHECK EndDate >= StartDate)
        UPDATE dbo.CARE_ASSIGNMENT
        SET EndDate = CASE WHEN StartDate > @EndDate THEN StartDate ELSE @EndDate END
        WHERE AnimalID = @AnimalID
          AND EndDate IS NULL;

        SET @EndedAssignments = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT @AnimalID AS AnimalID, @EndedAssignments AS EndedCareAssignments;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P3  usp_RegisterCheckup
   INSERT MEDICAL_RECORD  +  optional UPDATE ANIMAL.HealthStatus
   Rules: animal exists and is not deceased; VetID must be a staff
   member with Role = 'Veterinarian'; 'Deceased' is not allowed here
   (use usp_MarkAnimalDeceased). Any other invalid status is rejected
   by the CHECK constraint on ANIMAL and the medical record is rolled back.
   Returns: RecordID
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_RegisterCheckup
    @AnimalID        INT,
    @VetID           INT,
    @Diagnosis       NVARCHAR(255) = NULL,
    @Treatment       NVARCHAR(255) = NULL,
    @NextCheckup     DATE = NULL,
    @NewHealthStatus NVARCHAR(30) = NULL,
    @CheckupDate     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @HealthStatus NVARCHAR(30);
    DECLARE @RecordID INT;
    SET @CheckupDate = COALESCE(@CheckupDate, CAST(GETDATE() AS DATE));

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @HealthStatus = HealthStatus
        FROM dbo.ANIMAL WITH (UPDLOCK)
        WHERE AnimalID = @AnimalID;

        IF @@ROWCOUNT = 0
            THROW 50021, N'Animal not found.', 1;
        IF @HealthStatus = 'Deceased'
            THROW 50022, N'A checkup cannot be recorded for a deceased animal.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.STAFF WHERE StaffID = @VetID AND Role = 'Veterinarian')
            THROW 50023, N'Only a veterinarian can register a checkup.', 1;
        IF @NewHealthStatus = 'Deceased'
            THROW 50024, N'Use usp_MarkAnimalDeceased to mark an animal as deceased.', 1;

        INSERT INTO dbo.MEDICAL_RECORD (AnimalID, VetID, CheckupDate, Diagnosis, Treatment, NextCheckup)
        VALUES (@AnimalID, @VetID, @CheckupDate, @Diagnosis, @Treatment, @NextCheckup);

        SET @RecordID = SCOPE_IDENTITY();

        IF @NewHealthStatus IS NOT NULL
            UPDATE dbo.ANIMAL
            SET HealthStatus = @NewHealthStatus
            WHERE AnimalID = @AnimalID;

        COMMIT TRANSACTION;

        SELECT @RecordID AS RecordID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P4  usp_SellTicket
   INSERT TICKET with TotalPrice = fn_TicketLineTotal (price read from
   TICKET_TYPE at the moment of sale).
   Rules: quantity >= 1, ticket type exists, visit date not in the past,
   seller (if given) is a staff member with Role = 'Cashier'.
   @SoldByStaffID = NULL means an online sale.
   Returns: TicketID, TotalPrice
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_SellTicket
    @TicketTypeID  INT,
    @Quantity      INT,
    @VisitDate     DATE = NULL,
    @SoldByStaffID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TotalPrice DECIMAL(10,2);
    DECLARE @TicketID INT;
    SET @VisitDate = COALESCE(@VisitDate, CAST(GETDATE() AS DATE));

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Quantity IS NULL OR @Quantity < 1
            THROW 50031, N'Quantity must be at least 1.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.TICKET_TYPE WHERE TicketTypeID = @TicketTypeID)
            THROW 50032, N'Ticket type not found.', 1;
        IF @VisitDate < CAST(GETDATE() AS DATE)
            THROW 50033, N'The visit date cannot be in the past.', 1;
        IF @SoldByStaffID IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.STAFF WHERE StaffID = @SoldByStaffID AND Role = 'Cashier')
            THROW 50034, N'Only a cashier can sell tickets.', 1;

        SET @TotalPrice = dbo.fn_TicketLineTotal(@TicketTypeID, @Quantity);

        INSERT INTO dbo.TICKET (TicketTypeID, SoldByStaffID, VisitDate, PurchasedAt, Quantity, TotalPrice)
        VALUES (@TicketTypeID, @SoldByStaffID, @VisitDate, SYSDATETIME(), @Quantity, @TotalPrice);

        SET @TicketID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @TicketID AS TicketID, @TotalPrice AS TotalPrice;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================================
   P5  usp_LogFeeding
   INSERT FEEDING_LOG for a feeding plan.
   Rules: plan exists, its animal is not deceased, the staff member is a
   Keeper or Manager, quantity >= 0, and the plan has not been logged
   today yet (fn_IsFedToday) - double logging is rejected.
   Returns: LogID
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_LogFeeding
    @PlanID        INT,
    @StaffID       INT,
    @QuantityGiven DECIMAL(8,2),
    @Notes         NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @AnimalID INT;
    DECLARE @LogID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- lock the plan row so two users cannot log the same feeding at the same moment
        SELECT @AnimalID = AnimalID
        FROM dbo.FEEDING_PLAN WITH (UPDLOCK)
        WHERE PlanID = @PlanID;

        IF @@ROWCOUNT = 0
            THROW 50041, N'Feeding plan not found.', 1;
        IF EXISTS (SELECT 1 FROM dbo.ANIMAL WHERE AnimalID = @AnimalID AND HealthStatus = 'Deceased')
            THROW 50042, N'A deceased animal cannot be fed.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.STAFF WHERE StaffID = @StaffID AND Role IN ('Keeper', 'Manager'))
            THROW 50043, N'Only a keeper or a manager can log a feeding.', 1;
        IF @QuantityGiven IS NULL OR @QuantityGiven < 0
            THROW 50044, N'Quantity given cannot be negative.', 1;
        IF dbo.fn_IsFedToday(@PlanID) = 1
            THROW 50045, N'This feeding has already been logged today.', 1;

        INSERT INTO dbo.FEEDING_LOG (PlanID, StaffID, FedAt, QuantityGiven, Notes)
        VALUES (@PlanID, @StaffID, SYSDATETIME(), @QuantityGiven, @Notes);

        SET @LogID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @LogID AS LogID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'ZooDB: 3 functions and 5 stored procedures created.';
GO

-- Quick check: list the objects that were created
SELECT name AS ObjectName, type_desc AS ObjectType, create_date, modify_date
FROM sys.objects
WHERE name IN ('fn_EnclosureFreeSpaces', 'fn_TicketLineTotal', 'fn_IsFedToday',
               'usp_TransferAnimal', 'usp_MarkAnimalDeceased', 'usp_RegisterCheckup',
               'usp_SellTicket', 'usp_LogFeeding')
ORDER BY type_desc, name;
