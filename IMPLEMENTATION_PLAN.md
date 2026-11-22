# Zoo Management System — Implementation Plan (Python Stack)

**Goal:** Build the working application for the designed schema and the **10 core screens**, using Python for both backend and frontend.

**Inputs already done:** planning, analysis (10 screens), conceptual/logical/physical design, `Zoo_Database.sql`, `zoo_ui_pages_design.md`.

---

## 1. Recommended Stack

| Layer | Choice | Why |
|---|---|---|
| Language | Python 3.11+ | One language for API and UI |
| API / backend | **FastAPI** | Clear routes, Pydantic validation, OpenAPI docs, async-ready |
| ORM | **SQLAlchemy 2.0** | Maps cleanly to the 20 tables; transactions for multi-table actions |
| Migrations | **Alembic** | Version schema changes after initial SQL load |
| Database | **PostgreSQL** | Matches project SQL dialect; use SQLite only for quick local smoke tests |
| Auth | Sessions or JWT + **passlib** (bcrypt) | Role from `STAFF.Role`; never store plain passwords |
| Frontend (Python) | **NiceGUI** *or* **Reflex** | Full multi-page UI in Python; good fit for forms, tables, dialogs |
| Alternate (simpler UI) | FastAPI + **Jinja2 + HTMX** | Server-rendered pages, less JS, still Python-centric |
| Packaging | `uv` or `pip` + `venv`, `requirements.txt` / `pyproject.toml` | Reproducible installs |
| Config | `.env` + `pydantic-settings` | DB URL, secret key — never commit secrets |

**Default recommendation for this course project:**  
`FastAPI` + `SQLAlchemy` + `PostgreSQL` + `NiceGUI` (UI talks to services/DB in-process or via API).

---

## 2. Target Application Shape

```
ZooManagementSystem/
├── Zoo_Database.sql                 # existing DDL
├── zoo_database_documentation.md
├── zoo_ui_pages_design.md
├── IMPLEMENTATION_PLAN.md           # this file
├── project_report/                  # course report (done)
├── app/
│   ├── main.py                      # FastAPI / NiceGUI entry
│   ├── config.py
│   ├── db/
│   │   ├── session.py
│   │   └── models/                  # SQLAlchemy models (20 tables)
│   ├── schemas/                     # Pydantic request/response
│   ├── services/                    # business logic + transactions
│   ├── api/                         # REST routers (optional if UI in-process)
│   ├── auth/                        # login, password hash, role checks
│   ├── ui/                          # NiceGUI/Reflex pages (10 screens)
│   │   ├── login.py                 # P01
│   │   ├── animals_list.py          # P02
│   │   ├── animal_detail.py         # P03
│   │   ├── habitats.py              # P04
│   │   ├── feeding_today.py         # P05
│   │   ├── veterinary.py            # P06
│   │   ├── inventory.py             # P07
│   │   ├── staff.py                 # P08
│   │   ├── ticketing.py             # P09
│   │   └── admin.py                 # P10
│   └── seed/                        # sample data for demo
├── alembic/
├── tests/
├── .env.example
└── README.md                        # how to run
```

---

## 3. Phased Build Plan

### Phase 0 — Project bootstrap (0.5–1 day)

| Step | Task | Done when |
|---|---|---|
| 0.1 | Create venv, add dependencies (`fastapi`, `uvicorn`, `sqlalchemy`, `psycopg`/`asyncpg`, `alembic`, `passlib`, `python-dotenv`, NiceGUI or Reflex) | App imports cleanly |
| 0.2 | Add `.env.example` (`DATABASE_URL`, `SECRET_KEY`) | Documented; `.env` gitignored |
| 0.3 | Create `app/` package layout above | Folders exist |
| 0.4 | Run PostgreSQL locally (Docker optional: `postgres:16`) | Can connect |
| 0.5 | Apply `Zoo_Database.sql` (or generate models then migrate) | 20 tables exist |
| 0.6 | Smoke query: `SELECT COUNT(*)` from a few tables | Connection verified |

**Checkpoint:** Empty schema loaded; `uvicorn` / NiceGUI starts with a hello page.

---

### Phase 1 — Data layer & auth foundation (1–2 days)

Aligns with UI build order: **P01, P10, P08**.

| Step | Task | Screens / artifacts |
|---|---|---|
| 1.1 | Map all 20 tables to SQLAlchemy models (PK/FK/CHECK mirrored where practical) | Models |
| 1.2 | Session factory + dependency (`get_db`) | DB access |
| 1.3 | Add auth fields if missing (e.g. `PasswordHash` on STAFF, or separate `USER_ACCOUNT`) — document the small schema extension | Auth |
| 1.4 | Implement password hash/verify; login service | **P01** backend |
| 1.5 | Session/JWT middleware; `require_role(...)` helpers | Security |
| 1.6 | Seed: 1 zoo, departments, conservation statuses, ticket types, admin/keeper/vet/cashier users | Demo logins |
| 1.7 | Build **P01 Login** UI | **P01** |
| 1.8 | Build thin **P10 Admin** (zoo, departments, species, conservation, ticket types) | **P10** |
| 1.9 | Build **P08 Staff** (directory, add/edit, shifts tab) | **P08** |

**Checkpoint:** Login as Manager/Keeper/Vet/Cashier; manage staff and lookups.

---

### Phase 2 — Places & animals hub (2–3 days)

| Step | Task | Screens |
|---|---|---|
| 2.1 | Habitat / enclosure CRUD + occupancy queries | **P04** |
| 2.2 | Animal list with filters + pagination | **P02** |
| 2.3 | Add Animal wizard (single DB transaction: animal + optional medical/vaccine/care/plan) | **P02** modal |
| 2.4 | Animal Detail tabs: overview, care, medical, vaccines, feeding plans, transfers | **P03** |
| 2.5 | Edit animal + mark deceased (end care assignments) | **P03** |
| 2.6 | Transfer dialog (INSERT transfer + UPDATE animal in one transaction) | **P03** |
| 2.7 | Enforce capacity / maintenance rules in service layer | Services |
| 2.8 | Role gates: cashier cannot open animal screens | Auth |

**Checkpoint:** Register animal → place in enclosure → assign keeper → set diet → transfer → history visible.

---

### Phase 3 — Daily feeding (0.5–1 day)

| Step | Task | Screens |
|---|---|---|
| 3.1 | Today’s feeding checklist query (plan vs log) | **P05** |
| 3.2 | “Mark fed” → INSERT `FEEDING_LOG` | **P05** |
| 3.3 | Filters: my animals, habitat, time; disable double-log | **P05** |
| 3.4 | Link from checklist row → P03 | UX |

**Checkpoint:** Keeper logs a full day’s feedings; Late/Done/Pending statuses correct.

---

### Phase 4 — Health & supplies (1–2 days)

| Step | Task | Screens |
|---|---|---|
| 4.1 | Vet queues: due vaccines, overdue checkups, under treatment | **P06** |
| 4.2 | Add checkup (+ optional health status update) in one transaction | **P06** |
| 4.3 | Record vaccination | **P06** |
| 4.4 | Stock estimate (purchases − consumption), expiring soon | **P07** |
| 4.5 | Record delivery (`FOOD_STOCK`) + food type CRUD | **P07** |
| 4.6 | Suppliers tab (CRUD + spending summary) | **P07** |

**Checkpoint:** Vet clears a due vaccine; manager records a delivery and sees stock move.

---

### Phase 5 — Visitors (0.5 day)

| Step | Task | Screens |
|---|---|---|
| 5.1 | Ticket type buttons from `TICKET_TYPE` | **P09** |
| 5.2 | Sell ticket (quantity × price → `TICKET`) | **P09** |
| 5.3 | Today’s sales list; Cashier-only nav | **P09** |

**Checkpoint:** Cashier completes a sale; Manager can view sales if needed.

---

### Phase 6 — Hardening, seed demo, docs (1 day)

| Step | Task |
|---|---|
| 6.1 | Map DB errors → friendly messages (see UI design §7.2) |
| 6.2 | Server-side role checks on every mutating service |
| 6.3 | Richer seed dataset (enough animals, plans, tickets for a live demo) |
| 6.4 | Basic automated tests: auth, transfer transaction, feeding log, ticket sale |
| 6.5 | Root `README.md`: install, migrate/load SQL, seed, run, demo accounts |
| 6.6 | Optional screenshots for the course report appendix |

**Checkpoint:** Fresh clone → follow README → demo all 10 screens.

---

### Phase 7 — Stretch (optional)

| Step | Task |
|---|---|
| 7.1 | **P11 Dashboard** (stretch) — missed feedings, due vaccines, low stock, full enclosures |
| 7.2 | Simple exports (CSV) from dashboard / ticketing |
| 7.3 | Indexes for hot filters if lists get slow |

---

## 4. Build Order vs Screens (quick view)

```
Phase 0  Bootstrap + load Zoo_Database.sql
Phase 1  P01 → P10 → P08
Phase 2  P04 → P02 → P03
Phase 3  P05
Phase 4  P06 → P07
Phase 5  P09
Phase 6  Tests, seed, README
Phase 7  P11 (optional dashboard)
```

Screen IDs **P01–P10** are sequential for the core build. Older IDs in [`zoo_ui_pages_design.md`](zoo_ui_pages_design.md) map as: Login→P01, Animal List→P02, Animal Detail→P03, Habitats→P04, Feeding→P05, Vet→P06, Inventory→P07, Staff→P08, Ticketing→P09, Admin→P10.

---

## 5. Implementation Rules (keep consistent with design)

1. **Parameterized queries / ORM binds only** — no string-concatenated SQL.  
2. **Multi-table writes in one transaction** — register animal, transfer, mark deceased, checkup+status.  
3. **No hard delete** of history-bearing rows — end assignment, mark deceased, deactivate.  
4. **Authorize on the server** — hide UI *and* reject forbidden API/service calls.  
5. **Reuse SQL from** `zoo_ui_pages_design.md` — treat that doc as the query checklist per screen.  
6. **One hub for animal work** — keep add/edit, transfer, feeding plans, and care on **P02/P03**; do not split them into extra routes.  
7. **Small schema extensions OK** if documented (password hash, `IsActive`) — keep 3NF and update the report appendix if required by the course.

---

## 6. Suggested Milestones (calendar)

| Milestone | Deliverable | Rough effort |
|---|---|---|
| M0 | Runnable empty app + DB loaded | ~1 day |
| M1 | Login + Admin + Staff | ~2 days |
| M2 | Habitats + Animals hub | ~3 days |
| M3 | Feeding + Vet + Inventory + Tickets | ~3 days |
| M4 | Demo-ready (seed, tests, README) | ~1 day |
| **Total (core)** | **10 screens working** | **~8–10 days** |
| M5 | Dashboard stretch | +1 day |

Adjust for team size; two people can split UI vs services after Phase 1.

---

## 7. Definition of Done (project)

- [ ] All **10** screens usable end-to-end with seeded data  
- [ ] All **20** tables read and/or written by at least one screen  
- [ ] Roles enforced (Manager, Keeper, Veterinarian, Cashier)  
- [ ] Critical transactions atomic (animal register, transfer, deceased, checkup)  
- [ ] README enables a new machine to run the demo  
- [ ] Course report remains accurate (link this plan from `project_report/README.md` if desired)  

---

## 8. Immediate Next Actions (start here)

1. Choose UI library: **NiceGUI** (default) or Jinja2+HTMX.  
2. Create venv + `pyproject.toml` / `requirements.txt`.  
3. Start PostgreSQL and apply [`Zoo_Database.sql`](Zoo_Database.sql).  
4. Scaffold `app/` and SQLAlchemy models for Organization + Places tables first.  
5. Implement **P01 Login** with hashed passwords and role-based redirect.  

After that, follow **Phase 1 → 5** without skipping the animal hub (**P03**)—it carries the most merged functionality.
