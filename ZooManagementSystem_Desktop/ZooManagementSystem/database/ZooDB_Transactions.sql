/* =====================================================================
   Zoo Management System - SQL Server (T-SQL)
   ZooDB_Transactions.sql  ->  database-level TRANSACTIONS

   Run order:
     1) ZooDB_FULL.sql                    (tables + sample data)
     2) ZooDB_Functions_Procedures.sql    (F1-F3, P1-P5)
     3) ZooDB_Transactions.sql            (this file)

   HOW TO RUN: SSMS > File > Open > File... > choose this file,
   click once inside the text (select NOTHING), press F5.
   The script can be run again at any time (CREATE OR ALTER).

   What a transaction is:
     A group of SQL statements that runs as ONE unit.
       * all statements succeed  -> COMMIT   (all changes are saved)
       * any statement fails     -> ROLLBACK (no change is saved)
     So the database is never left half-updated.

   Pattern used in every procedure:
       SET XACT_ABORT ON;              -- any error aborts the transaction
       BEGIN TRY
           BEGIN TRANSACTION;
           ...statements...
           COMMIT TRANSACTION;
       END TRY
       BEGIN CATCH
           IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
           THROW;                      -- send the error to the application
       END CATCH

   Transactions in the system:
     T1  Register animal   ANIMAL + VACCINATION + CARE_ASSIGNMENT + FEEDING_PLAN
                           -> dbo.usp_RegisterAnimal (this file)
     T2  Transfer animal   ANIMAL_TRANSFER + ANIMAL   -> dbo.usp_TransferAnimal
     T3  Mark deceased     ANIMAL + CARE_ASSIGNMENT   -> dbo.usp_MarkAnimalDeceased
     T4  New checkup       MEDICAL_RECORD + ANIMAL    -> dbo.usp_RegisterCheckup
     (T2-T4 are in ZooDB_Functions_Procedures.sql)

   Error numbers used here: 50051-50056
   ===================================================================== */

USE ZooDB;
GO

/* =====================================================================
   T1  usp_RegisterAnimal
   Registers a new animal in ONE transaction:
     INSERT ANIMAL
     + optional INSERT VACCINATION     (arrival vaccine)
     + optional INSERT CARE_ASSIGNMENT (keeper)
     + optional INSERT FEEDING_PLAN    (diet)
   If any step fails, the animal row is rolled back too.
   Rules: species exists; enclosure (if given) is not under maintenance
   and has free space (fn_EnclosureFreeSpaces); VetID is a Veterinarian;
   KeeperID is a Keeper.
   Returns: AnimalID
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_RegisterAnimal
    @Name            NVARCHAR(60),
    @SpeciesID       INT,
    @Gender          NVARCHAR(10),
    @ArrivalDate     DATE,
    @BirthDate       DATE          = NULL,
    @Origin          NVARCHAR(100) = NULL,
    @EnclosureID     INT           = NULL,
    @VetID           INT           = NULL,
    @VaccineName     NVARCHAR(100) = NULL,
    @NextDue         DATE          = NULL,
    @KeeperID        INT           = NULL,
    @FoodID          INT           = NULL,
    @QuantityPerMeal DECIMAL(8,2)  = NULL,
    @FeedingTime     TIME          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @AnimalID INT;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) business-rule checks (nothing is written yet)
        IF NOT EXISTS (SELECT 1 FROM dbo.SPECIES WHERE SpeciesID = @SpeciesID)
            THROW 50051, N'Species not found.', 1;

        IF @EnclosureID IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.ENCLOSURE WITH (UPDLOCK)
                       WHERE EnclosureID = @EnclosureID AND Condition = 'Under Maintenance')
                THROW 50052, N'The enclosure is under maintenance.', 1;
            IF dbo.fn_EnclosureFreeSpaces(@EnclosureID) <= 0
                THROW 50053, N'The enclosure is full.', 1;
        END

        IF @VaccineName IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.STAFF WHERE StaffID = @VetID AND Role = 'Veterinarian')
            THROW 50054, N'The arrival vaccine must be given by a veterinarian.', 1;

        IF @KeeperID IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.STAFF WHERE StaffID = @KeeperID AND Role = 'Keeper')
            THROW 50055, N'The care assignment must be given to a keeper.', 1;

        -- 2) the animal itself
        INSERT INTO dbo.ANIMAL (SpeciesID, EnclosureID, Name, Gender, BirthDate, ArrivalDate, Origin, HealthStatus)
        VALUES (@SpeciesID, @EnclosureID, @Name, @Gender, @BirthDate, @ArrivalDate, @Origin, 'Healthy');

        SET @AnimalID = SCOPE_IDENTITY();

        -- 3) optional arrival vaccination
        IF @VaccineName IS NOT NULL
            INSERT INTO dbo.VACCINATION (AnimalID, VetID, VaccineName, DateGiven, NextDue)
            VALUES (@AnimalID, @VetID, @VaccineName, @Today, @NextDue);

        -- 4) optional keeper
        IF @KeeperID IS NOT NULL
            INSERT INTO dbo.CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
            VALUES (@KeeperID, @AnimalID, @Today, N'Daily care');

        -- 5) optional diet
        IF @FoodID IS NOT NULL
            INSERT INTO dbo.FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
            VALUES (@AnimalID, @FoodID, COALESCE(@QuantityPerMeal, 1),
                    COALESCE(@FeedingTime, CAST('09:00' AS TIME)), N'Daily');

        COMMIT TRANSACTION;

        SELECT @AnimalID AS AnimalID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'ZooDB: usp_RegisterAnimal (transaction T1) created.';
GO

/* =====================================================================
   ROLLBACK PROOF (safe: leaves no data behind)
   The animal INSERT succeeds, then the FEEDING_PLAN INSERT fails
   (FoodID 9999 does not exist -> foreign key error).
   Because everything is one transaction, the animal row is rolled back:
   the number of animals must be the same before and after.
   ===================================================================== */
DECLARE @Before INT = (SELECT COUNT(*) FROM dbo.ANIMAL);
DECLARE @Error NVARCHAR(400) = NULL;

BEGIN TRY
    EXEC dbo.usp_RegisterAnimal
         @Name = N'Rollback Test', @SpeciesID = 1, @Gender = N'Male',
         @ArrivalDate = '2026-01-01', @EnclosureID = NULL,
         @FoodID = 9999;                 -- invalid on purpose
END TRY
BEGIN CATCH
    SET @Error = ERROR_MESSAGE();
END CATCH

DECLARE @After INT = (SELECT COUNT(*) FROM dbo.ANIMAL);

SELECT 'T1 ROLLBACK: failed registration leaves no animal row' AS Test,
       CASE WHEN @Error IS NOT NULL AND @Before = @After THEN 'PASS' ELSE 'FAIL' END AS Result,
       @Before AS AnimalsBefore, @After AS AnimalsAfter, @Error AS ErrorRaised;
GO
