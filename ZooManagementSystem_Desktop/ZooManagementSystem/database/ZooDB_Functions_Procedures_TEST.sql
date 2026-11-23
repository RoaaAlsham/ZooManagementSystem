/* =====================================================================
   Zoo Management System - SQL Server (T-SQL)
   ZooDB_Functions_Procedures_TEST.sql

   Verifies SUBMISSION_PLAN 2.2 and 2.3 ("Done when"):
     * every function returns the correct value for the data,
     * every procedure works on a normal call,
     * business-rule errors are rejected,
     * a failure in the middle of a procedure is rolled back
       (no partial writes).

   HOW TO RUN: after ZooDB_FULL.sql and ZooDB_Functions_Procedures.sql,
   open this file in SSMS, click inside (select nothing), press F5.
   Look at the LAST result grid: every row should say PASS.

   The test creates its own temporary animal "TEST_Animal" (and a feeding
   plan, care assignment and one ticket) and deletes them at the end, so
   the demo data is not changed.
   ===================================================================== */

USE ZooDB;
GO

SET NOCOUNT ON;

DECLARE @Results TABLE (
    No     INT IDENTITY(1,1),
    Test   NVARCHAR(120),
    Result NVARCHAR(10),
    Detail NVARCHAR(400)
);

DECLARE @Today     DATE = CAST(GETDATE() AS DATE);
DECLARE @Giraffe   INT  = (SELECT EnclosureID FROM ENCLOSURE WHERE Name = 'Giraffe Yard');
DECLARE @Zebra     INT  = (SELECT EnclosureID FROM ENCLOSURE WHERE Name = 'Zebra Plains');
DECLARE @Dolphin   INT  = (SELECT EnclosureID FROM ENCLOSURE WHERE Name = 'Dolphin Pool');
DECLARE @Species   INT  = (SELECT SpeciesID FROM SPECIES WHERE ScientificName = 'Giraffa camelopardalis');
DECLARE @Hay       INT  = (SELECT FoodID FROM FOOD_TYPE WHERE Name = 'Hay');
DECLARE @Family    INT  = (SELECT TicketTypeID FROM TICKET_TYPE WHERE Name = 'Family');
DECLARE @Vet       INT  = (SELECT StaffID FROM STAFF WHERE Email = 'vet1@zoo.com');
DECLARE @Keeper    INT  = (SELECT StaffID FROM STAFF WHERE Email = 'keeper1@zoo.com');
DECLARE @Cashier   INT  = (SELECT StaffID FROM STAFF WHERE Email = 'cashier1@zoo.com');
DECLARE @Err NVARCHAR(400);
DECLARE @n INT;
DECLARE @x INT;
DECLARE @d DECIMAL(10,2);
DECLARE @TicketID INT;

-- make sure the Dolphin Pool is under maintenance for test P1-c
UPDATE ENCLOSURE SET Condition = 'Under Maintenance' WHERE EnclosureID = @Dolphin;

/* ---------------------------------------------------------- set-up */
INSERT INTO ANIMAL (SpeciesID, EnclosureID, Name, Gender, ArrivalDate, Origin, HealthStatus)
VALUES (@Species, @Giraffe, 'TEST_Animal', 'Unknown', @Today, 'Test script', 'Healthy');
DECLARE @A INT = SCOPE_IDENTITY();

INSERT INTO CARE_ASSIGNMENT (StaffID, AnimalID, StartDate, Responsibility)
VALUES (@Keeper, @A, @Today, 'Test');

INSERT INTO FEEDING_PLAN (AnimalID, FoodID, QuantityPerMeal, FeedingTime, Frequency)
VALUES (@A, @Hay, 5, '06:45', 'Daily');
DECLARE @Plan INT = SCOPE_IDENTITY();

/* ================================================= FUNCTIONS (F1-F3) */
-- F1: compare with an independent count
SET @x = (SELECT Capacity FROM ENCLOSURE WHERE EnclosureID = @Giraffe)
       - (SELECT COUNT(*) FROM ANIMAL WHERE EnclosureID = @Giraffe AND HealthStatus <> 'Deceased');
INSERT INTO @Results (Test, Result, Detail)
SELECT 'F1 fn_EnclosureFreeSpaces (Giraffe Yard)',
       CASE WHEN dbo.fn_EnclosureFreeSpaces(@Giraffe) = @x THEN 'PASS' ELSE 'FAIL' END,
       CONCAT('returned ', dbo.fn_EnclosureFreeSpaces(@Giraffe), ', expected ', @x);

INSERT INTO @Results (Test, Result, Detail)
SELECT 'F1 unknown enclosure returns NULL',
       CASE WHEN dbo.fn_EnclosureFreeSpaces(-1) IS NULL THEN 'PASS' ELSE 'FAIL' END, '';

-- F2: Family price x 2
SET @d = (SELECT Price * 2 FROM TICKET_TYPE WHERE TicketTypeID = @Family);
INSERT INTO @Results (Test, Result, Detail)
SELECT 'F2 fn_TicketLineTotal (Family x 2)',
       CASE WHEN dbo.fn_TicketLineTotal(@Family, 2) = @d THEN 'PASS' ELSE 'FAIL' END,
       CONCAT('returned ', dbo.fn_TicketLineTotal(@Family, 2), ', expected ', @d);

INSERT INTO @Results (Test, Result, Detail)
SELECT 'F2 quantity 0 returns NULL',
       CASE WHEN dbo.fn_TicketLineTotal(@Family, 0) IS NULL THEN 'PASS' ELSE 'FAIL' END, '';

-- F3: not fed yet
INSERT INTO @Results (Test, Result, Detail)
SELECT 'F3 fn_IsFedToday before feeding = 0',
       CASE WHEN dbo.fn_IsFedToday(@Plan) = 0 THEN 'PASS' ELSE 'FAIL' END, '';

/* ======================================== P5 usp_LogFeeding */
BEGIN TRY
    EXEC dbo.usp_LogFeeding @PlanID = @Plan, @StaffID = @Keeper, @QuantityGiven = 5, @Notes = N'Test';
    SET @n = (SELECT COUNT(*) FROM FEEDING_LOG WHERE PlanID = @Plan);
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P5 usp_LogFeeding logs a feeding',
           CASE WHEN @n = 1 AND dbo.fn_IsFedToday(@Plan) = 1 THEN 'PASS' ELSE 'FAIL' END,
           CONCAT('logs for plan: ', @n, ', fn_IsFedToday = ', dbo.fn_IsFedToday(@Plan));
END TRY
BEGIN CATCH
    INSERT INTO @Results VALUES ('P5 usp_LogFeeding logs a feeding', 'FAIL', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXEC dbo.usp_LogFeeding @PlanID = @Plan, @StaffID = @Keeper, @QuantityGiven = 5;
    INSERT INTO @Results VALUES ('P5 second feeding today is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P5 second feeding today is rejected',
           CASE WHEN ERROR_NUMBER() = 50045
                 AND (SELECT COUNT(*) FROM FEEDING_LOG WHERE PlanID = @Plan) = 1 THEN 'PASS' ELSE 'FAIL' END,
           ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_LogFeeding @PlanID = @Plan, @StaffID = @Cashier, @QuantityGiven = 5;
    INSERT INTO @Results VALUES ('P5 cashier cannot log a feeding', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P5 cashier cannot log a feeding',
           CASE WHEN ERROR_NUMBER() = 50043 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

/* ======================================== P1 usp_TransferAnimal */
BEGIN TRY
    EXEC dbo.usp_TransferAnimal @AnimalID = @A, @ToEnclosureID = @Zebra, @Reason = N'Test transfer';
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P1 usp_TransferAnimal (history + new location)',
           CASE WHEN (SELECT EnclosureID FROM ANIMAL WHERE AnimalID = @A) = @Zebra
                 AND (SELECT COUNT(*) FROM ANIMAL_TRANSFER WHERE AnimalID = @A) = 1 THEN 'PASS' ELSE 'FAIL' END,
           'ANIMAL_TRANSFER row inserted and ANIMAL.EnclosureID updated together';
END TRY
BEGIN CATCH
    INSERT INTO @Results VALUES ('P1 usp_TransferAnimal (history + new location)', 'FAIL', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXEC dbo.usp_TransferAnimal @AnimalID = @A, @ToEnclosureID = @Zebra;
    INSERT INTO @Results VALUES ('P1 transfer to the same enclosure is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P1 transfer to the same enclosure is rejected',
           CASE WHEN ERROR_NUMBER() = 50004
                 AND (SELECT COUNT(*) FROM ANIMAL_TRANSFER WHERE AnimalID = @A) = 1 THEN 'PASS' ELSE 'FAIL' END,
           ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_TransferAnimal @AnimalID = @A, @ToEnclosureID = @Dolphin;
    INSERT INTO @Results VALUES ('P1 transfer to an enclosure under maintenance is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P1 transfer to an enclosure under maintenance is rejected',
           CASE WHEN ERROR_NUMBER() = 50006
                 AND (SELECT EnclosureID FROM ANIMAL WHERE AnimalID = @A) = @Zebra THEN 'PASS' ELSE 'FAIL' END,
           ERROR_MESSAGE();
END CATCH;

/* ======================================== P3 usp_RegisterCheckup */
BEGIN TRY
    EXEC dbo.usp_RegisterCheckup @AnimalID = @A, @VetID = @Vet, @Diagnosis = N'Test cough',
         @Treatment = N'Rest', @NextCheckup = NULL, @NewHealthStatus = N'Under Treatment';
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P3 usp_RegisterCheckup (record + health status)',
           CASE WHEN (SELECT COUNT(*) FROM MEDICAL_RECORD WHERE AnimalID = @A) = 1
                 AND (SELECT HealthStatus FROM ANIMAL WHERE AnimalID = @A) = 'Under Treatment' THEN 'PASS' ELSE 'FAIL' END,
           'MEDICAL_RECORD inserted and ANIMAL.HealthStatus updated together';
END TRY
BEGIN CATCH
    INSERT INTO @Results VALUES ('P3 usp_RegisterCheckup (record + health status)', 'FAIL', ERROR_MESSAGE());
END CATCH;

-- ROLLBACK proof: the INSERT into MEDICAL_RECORD succeeds, then the UPDATE
-- of ANIMAL fails on the CHECK constraint ('Sick' is not an allowed status).
-- The whole transaction must be rolled back: still only 1 medical record.
BEGIN TRY
    EXEC dbo.usp_RegisterCheckup @AnimalID = @A, @VetID = @Vet, @Diagnosis = N'Should be rolled back',
         @NewHealthStatus = N'Sick';
    INSERT INTO @Results VALUES ('P3 ROLLBACK: failure after INSERT leaves no partial data', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P3 ROLLBACK: failure after INSERT leaves no partial data',
           CASE WHEN (SELECT COUNT(*) FROM MEDICAL_RECORD WHERE AnimalID = @A) = 1
                 AND (SELECT HealthStatus FROM ANIMAL WHERE AnimalID = @A) = 'Under Treatment' THEN 'PASS' ELSE 'FAIL' END,
           CONCAT('medical records still: ', (SELECT COUNT(*) FROM MEDICAL_RECORD WHERE AnimalID = @A),
                  ' | error: ', LEFT(ERROR_MESSAGE(), 200));
END CATCH;

BEGIN TRY
    EXEC dbo.usp_RegisterCheckup @AnimalID = @A, @VetID = @Keeper, @Diagnosis = N'Not a vet';
    INSERT INTO @Results VALUES ('P3 non-veterinarian is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P3 non-veterinarian is rejected',
           CASE WHEN ERROR_NUMBER() = 50023 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

/* ======================================== P4 usp_SellTicket */
SET @n = (SELECT COUNT(*) FROM TICKET);
BEGIN TRY
    EXEC dbo.usp_SellTicket @TicketTypeID = @Family, @Quantity = 2, @VisitDate = @Today, @SoldByStaffID = @Cashier;
    SET @TicketID = (SELECT MAX(TicketID) FROM TICKET);
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P4 usp_SellTicket (total = price x quantity)',
           CASE WHEN (SELECT COUNT(*) FROM TICKET) = @n + 1
                 AND (SELECT TotalPrice FROM TICKET WHERE TicketID = @TicketID) = dbo.fn_TicketLineTotal(@Family, 2)
                THEN 'PASS' ELSE 'FAIL' END,
           CONCAT('TotalPrice = ', (SELECT TotalPrice FROM TICKET WHERE TicketID = @TicketID));
END TRY
BEGIN CATCH
    INSERT INTO @Results VALUES ('P4 usp_SellTicket (total = price x quantity)', 'FAIL', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXEC dbo.usp_SellTicket @TicketTypeID = @Family, @Quantity = 0, @SoldByStaffID = @Cashier;
    INSERT INTO @Results VALUES ('P4 quantity 0 is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P4 quantity 0 is rejected',
           CASE WHEN ERROR_NUMBER() = 50031 AND (SELECT COUNT(*) FROM TICKET) = @n + 1 THEN 'PASS' ELSE 'FAIL' END,
           ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_SellTicket @TicketTypeID = @Family, @Quantity = 1, @VisitDate = '2000-01-01', @SoldByStaffID = @Cashier;
    INSERT INTO @Results VALUES ('P4 past visit date is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P4 past visit date is rejected',
           CASE WHEN ERROR_NUMBER() = 50033 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_SellTicket @TicketTypeID = @Family, @Quantity = 1, @SoldByStaffID = @Keeper;
    INSERT INTO @Results VALUES ('P4 keeper cannot sell tickets', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P4 keeper cannot sell tickets',
           CASE WHEN ERROR_NUMBER() = 50034 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

/* ======================================== P2 usp_MarkAnimalDeceased */
BEGIN TRY
    EXEC dbo.usp_MarkAnimalDeceased @AnimalID = @A;
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P2 usp_MarkAnimalDeceased (animal + care ended)',
           CASE WHEN (SELECT HealthStatus FROM ANIMAL WHERE AnimalID = @A) = 'Deceased'
                 AND (SELECT EnclosureID FROM ANIMAL WHERE AnimalID = @A) IS NULL
                 AND (SELECT COUNT(*) FROM CARE_ASSIGNMENT WHERE AnimalID = @A AND EndDate IS NULL) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'ANIMAL updated and open CARE_ASSIGNMENT rows ended together';
END TRY
BEGIN CATCH
    INSERT INTO @Results VALUES ('P2 usp_MarkAnimalDeceased (animal + care ended)', 'FAIL', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXEC dbo.usp_MarkAnimalDeceased @AnimalID = @A;
    INSERT INTO @Results VALUES ('P2 marking twice is rejected', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P2 marking twice is rejected',
           CASE WHEN ERROR_NUMBER() = 50012 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_TransferAnimal @AnimalID = @A, @ToEnclosureID = @Giraffe;
    INSERT INTO @Results VALUES ('P1 deceased animal cannot be transferred', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P1 deceased animal cannot be transferred',
           CASE WHEN ERROR_NUMBER() = 50002 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC dbo.usp_LogFeeding @PlanID = @Plan, @StaffID = @Keeper, @QuantityGiven = 1;
    INSERT INTO @Results VALUES ('P5 deceased animal cannot be fed', 'FAIL', 'was accepted');
END TRY
BEGIN CATCH
    INSERT INTO @Results (Test, Result, Detail)
    SELECT 'P5 deceased animal cannot be fed',
           CASE WHEN ERROR_NUMBER() = 50042 THEN 'PASS' ELSE 'FAIL' END, ERROR_MESSAGE();
END CATCH;

INSERT INTO @Results (Test, Result, Detail)
SELECT 'No open transaction left behind',
       CASE WHEN @@TRANCOUNT = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('@@TRANCOUNT = ', @@TRANCOUNT);

/* ---------------------------------------------------------- clean-up */
DELETE FROM FEEDING_LOG     WHERE PlanID = @Plan;
DELETE FROM FEEDING_PLAN    WHERE PlanID = @Plan;
DELETE FROM MEDICAL_RECORD  WHERE AnimalID = @A;
DELETE FROM CARE_ASSIGNMENT WHERE AnimalID = @A;
DELETE FROM ANIMAL_TRANSFER WHERE AnimalID = @A;
DELETE FROM ANIMAL          WHERE AnimalID = @A;
IF @TicketID IS NOT NULL
    DELETE FROM TICKET WHERE TicketID = @TicketID;

/* ---------------------------------------------------------- summary */
SELECT No, Result, Test, Detail FROM @Results ORDER BY No;

SELECT SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END) AS Failed
FROM @Results;
