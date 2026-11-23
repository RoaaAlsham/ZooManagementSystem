# Zoo Management System — Desktop Application

A role-based **desktop application** for the 20-table **ZooDB** database.
Built with **Python + Tkinter** (user interface) and **Microsoft SQL Server** (database), connected through **pyodbc**.

## Requirements

| Tool | Notes |
|---|---|
| Microsoft SQL Server (Express is enough) + SSMS | holds the ZooDB database |
| Python 3.10+ | Tkinter is included in the standard Windows installer |
| ODBC driver | "ODBC Driver 17/18 for SQL Server" (the built-in Windows "SQL Server" driver also works) |

## 1. Create the database (once per computer)

1. Open **SSMS** and connect to your server.
2. **File → Open → File…** → choose `database/ZooDB_FULL.sql`.
3. Click inside the script (select nothing) and press **F5**.
   The script deletes an old ZooDB, creates the 20 tables and inserts sample data.
4. Then open `database/ZooDB_Functions_Procedures.sql` and press **F5** (creates 3 functions and 5 stored procedures).
5. Optional: run `database/ZooDB_Functions_Procedures_TEST.sql` — the last result grid must show only PASS.

## 2. Connection settings

Open `app/zoo_settings.ini`. The default `server = .\SQLEXPRESS` works on any PC with
SQL Server Express. If your SSMS "Server name" is different (for example `localhost`),
write it there. No code change is needed.

## 3. Run the application

**Option A — with Python** (in the `app` folder):

```powershell
py -m pip install -r requirements.txt
py check_connection.py
py main.py
```

or simply double-click **`Start Zoo App.bat`**.

**Option B — as a Windows .exe (no Python needed on the target PC):**
double-click **`Build EXE.bat`** once. It creates `dist\ZooManagementSystem.exe`
and copies `zoo_settings.ini` next to it. Copy both files to any PC that has
SQL Server with ZooDB and double-click the .exe.

## 4. Demo accounts (password: `1234`)

| E-mail | Role | Home screen |
|---|---|---|
| manager@zoo.com | Manager | Animals (full access) |
| keeper1@zoo.com | Keeper | Feeding Today |
| vet1@zoo.com | Veterinarian | Veterinary Center |
| cashier1@zoo.com | Cashier | Ticketing |
| maint1@zoo.com | Maintenance | Habitats & Enclosures |

## 5. Screens and privileges

| Screen | Manager | Keeper | Veterinarian | Cashier | Maintenance |
|---|---|---|---|---|---|
| Animals (list, detail window, add) | full | read | edit health / diet | – | – |
| Habitats & Enclosures | full | read | read | – | read |
| Feeding Today | log | log | read | – | – |
| Veterinary Center | read | – | full | – | – |
| Food Inventory + Suppliers | full | read stock | read stock | – | – |
| Staff (+ shifts, workload) | full | own profile | own profile | own profile | own profile |
| Ticketing | reports | – | – | sell | – |
| Admin Settings | full | – | – | – | – |

The menu only shows allowed screens, and every write operation checks the role again
before touching the database (`auth.require_role`).

## 6. Transactions

These actions change several tables in **one transaction** (all or nothing —
`commit` on success, `rollback` on any error, see `db.transaction()`):

| Action | Where | Tables |
|---|---|---|
| Register animal | Animals → Add animal | ANIMAL, VACCINATION, CARE_ASSIGNMENT, FEEDING_PLAN |
| Transfer animal | Animal detail → Transfer | ANIMAL_TRANSFER, ANIMAL |
| Mark deceased | Animal detail → Mark deceased | ANIMAL, CARE_ASSIGNMENT |
| Checkup with status change | Veterinary Center → New checkup | MEDICAL_RECORD, ANIMAL |

## 7. Business rules enforced by the application

* An animal can only be placed in an enclosure that has free capacity and is not under maintenance.
* A feeding can be logged only once per plan per day.
* Arrival date cannot be before birth date; tickets cannot be sold for past dates.
* Ticket total price is always `quantity × current price` read from the database.
* History is never deleted: animals are marked *Deceased*, care assignments get an end date.

## 8. Project structure

```
app/
├── main.py              # entry point: login window, main window, role-based menu
├── auth.py              # password hashing (SHA-256), screen access rules
├── db.py                # all database access, parameterized queries, transactions
├── config.py            # reads zoo_settings.ini
├── zoo_settings.ini     # server / database name
├── check_connection.py  # connection test
├── Start Zoo App.bat    # double-click to run
├── Build EXE.bat        # builds dist\ZooManagementSystem.exe
└── ui/
    ├── widgets.py       # theme, data table, form dialog, screen base class
    └── screens/         # one file per screen
        animals.py habitats.py feeding.py vet.py inventory.py staff.py ticketing.py admin.py
database/
└── ZooDB_FULL.sql       # T-SQL: create database, 20 tables, sample data
```

## 9. Security

* All SQL uses `?` parameters (no string concatenation) — no SQL injection.
* Passwords are stored as SHA-256 hashes in `STAFF.PasswordHash`, never in plain text.
* Database errors are shown as friendly messages (duplicate value, rule violation, linked record).
