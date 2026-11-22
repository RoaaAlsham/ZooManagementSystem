"""Animals: list with filters, Add Animal, and the Animal Detail window
(care team, medical, vaccinations, feeding plans, transfers, edit).

Transactions on this screen:
  * Add animal      -> ANIMAL + VACCINATION + CARE_ASSIGNMENT + FEEDING_PLAN
  * Transfer animal -> ANIMAL_TRANSFER + UPDATE ANIMAL
  * Mark deceased   -> UPDATE ANIMAL + UPDATE CARE_ASSIGNMENT
"""
import datetime as dt
import tkinter as tk
from tkinter import ttk

import auth
import db
from ui import widgets as w

HEALTH = ["Healthy", "Under Treatment", "Quarantine", "Deceased"]
GENDER = {"Male": "Male", "Female": "Female", "Unknown": "Unknown"}


# ---------------------------------------------------------------- lookups
def species_options():
    return w.opts(db.query("SELECT SpeciesID, CommonName FROM SPECIES ORDER BY CommonName"),
                  "SpeciesID", "CommonName")


def staff_options(role):
    return w.opts(db.query("SELECT StaffID, FirstName, LastName FROM STAFF WHERE Role = ? ORDER BY FirstName",
                           [role]), "StaffID", lambda r: f"{r['FirstName']} {r['LastName']}")


def food_options():
    return w.opts(db.query("SELECT FoodID, Name, Unit FROM FOOD_TYPE ORDER BY Name"),
                  "FoodID", lambda r: f"{r['Name']} ({r['Unit']})")


def enclosures_with_space(exclude_id=None):
    """Enclosures that are not under maintenance and still have free places."""
    rows = db.query(
        "SELECT e.EnclosureID, e.Name, h.Name AS Habitat, e.Capacity, COUNT(a.AnimalID) AS Occupancy "
        "FROM ENCLOSURE e "
        "JOIN HABITAT h ON e.HabitatID = h.HabitatID "
        "LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID "
        "WHERE e.Condition <> 'Under Maintenance' "
        "GROUP BY e.EnclosureID, e.Name, h.Name, e.Capacity "
        "HAVING e.Capacity - COUNT(a.AnimalID) > 0 "
        "ORDER BY h.Name, e.Name")
    rows = [r for r in rows if r["EnclosureID"] != exclude_id]
    return w.opts(rows, "EnclosureID",
                  lambda r: f"{r['Name']} ({r['Habitat']}) — free: {int(r['Capacity']) - int(r['Occupancy'])}")


def has_free_space(enclosure_id):
    r = db.query(
        "SELECT e.Capacity, e.Condition, "
        "       (SELECT COUNT(*) FROM ANIMAL a WHERE a.EnclosureID = e.EnclosureID) AS Occupancy "
        "FROM ENCLOSURE e WHERE e.EnclosureID = ?", [enclosure_id])[0]
    return r["Condition"] != "Under Maintenance" and int(r["Occupancy"]) < int(r["Capacity"])


# ---------------------------------------------------------------- list screen
class AnimalsScreen(w.Screen):
    def build(self):
        bar = ttk.Frame(self)
        bar.pack(fill="x")
        self.name = tk.StringVar()
        ttk.Label(bar, text="Name").pack(side="left")
        ttk.Entry(bar, textvariable=self.name, width=16).pack(side="left", padx=(4, 12))
        self.filters = {}
        for label, values in [
            ("Species", ["All"] + list(species_options().values())),
            ("Health", ["All"] + HEALTH),
            ("Habitat", ["All"] + [r["Name"] for r in db.query("SELECT Name FROM HABITAT ORDER BY Name")]),
        ]:
            ttk.Label(bar, text=label).pack(side="left")
            var = tk.StringVar(value="All")
            ttk.Combobox(bar, textvariable=var, values=values, state="readonly", width=18).pack(
                side="left", padx=(4, 12))
            self.filters[label] = var
        ttk.Button(bar, text="Search", command=self.safe_refresh).pack(side="left")

        self.count = ttk.Label(self, text="", style="Muted.TLabel")
        self.count.pack(anchor="w", pady=(10, 4))
        self.table = w.Table(self, height=16, on_double_click=self.open_detail)
        self.table.pack(fill="both", expand=True)

        tools = self.toolbar(self)
        ttk.Button(tools, text="Open details", command=self.open_detail).pack(side="left")
        if auth.has_role(self.user, "Manager"):
            ttk.Button(tools, text="＋ Add animal", style="Accent.TButton",
                       command=self.add_animal).pack(side="left", padx=8)
        ttk.Label(tools, text="Tip: double-click an animal to open its details.",
                  style="Muted.TLabel").pack(side="right")

    def refresh(self):
        sql = ("SELECT a.AnimalID, a.Name, s.CommonName AS Species, a.Gender, a.BirthDate, "
               "       a.HealthStatus, e.Name AS Enclosure, h.Name AS Habitat "
               "FROM ANIMAL a "
               "JOIN SPECIES s ON a.SpeciesID = s.SpeciesID "
               "LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID "
               "LEFT JOIN HABITAT h ON e.HabitatID = h.HabitatID WHERE 1 = 1 ")
        params = []
        if self.name.get().strip():
            sql += "AND a.Name LIKE ? "
            params.append(f"%{self.name.get().strip()}%")
        for label, col in [("Species", "s.CommonName"), ("Health", "a.HealthStatus"), ("Habitat", "h.Name")]:
            value = self.filters[label].get()
            if value and value != "All":
                sql += f"AND {col} = ? "
                params.append(value)
        rows = db.query(sql + "ORDER BY a.Name", params)
        self.table.load(rows)
        self.count.configure(text=f"{len(rows)} animal(s)")

    def open_detail(self):
        row = self.table.selected()
        if row is None:
            w.error(self, "Select an animal first.")
            return
        AnimalDetail(self, int(row["AnimalID"]))

    def add_animal(self):
        vets, keepers, foods = staff_options("Veterinarian"), staff_options("Keeper"), food_options()
        values = w.ask_form(self, "Register a new animal", [
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "SpeciesID", "label": "Species", "type": "choice", "options": species_options(), "required": True},
            {"name": "Gender", "label": "Gender", "type": "choice", "options": GENDER, "required": True},
            {"name": "BirthDate", "label": "Birth date (empty if unknown)", "type": "date"},
            {"name": "ArrivalDate", "label": "Arrival date", "type": "date", "default": w.today(), "required": True},
            {"name": "Origin", "label": "Origin", "type": "text", "default": "Born in zoo"},
            {"name": "EnclosureID", "label": "Enclosure", "type": "choice", "options": enclosures_with_space(),
             "none_label": "— no enclosure —"},
            {"name": "_i1", "label": "Optional — arrival vaccination:", "type": "info"},
            {"name": "VetID", "label": "Veterinarian", "type": "choice", "options": vets, "none_label": "— skip —"},
            {"name": "Vaccine", "label": "Vaccine name", "type": "text"},
            {"name": "NextDue", "label": "Next dose due", "type": "date", "default": w.today() + dt.timedelta(days=365)},
            {"name": "_i2", "label": "Optional — care and diet:", "type": "info"},
            {"name": "KeeperID", "label": "Keeper", "type": "choice", "options": keepers, "none_label": "— skip —"},
            {"name": "FoodID", "label": "Food", "type": "choice", "options": foods, "none_label": "— skip —"},
            {"name": "Qty", "label": "Quantity per meal", "type": "float", "default": 1.0, "min": 0.1},
            {"name": "Time", "label": "Feeding time", "type": "time", "default": dt.time(9, 0)},
        ], submit_text="Register animal")
        if values is None:
            return
        v = values
        if v["BirthDate"] and v["ArrivalDate"] < v["BirthDate"]:
            w.error(self, "Arrival date cannot be before birth date.")
            return
        if v["EnclosureID"] is not None and not has_free_space(v["EnclosureID"]):
            w.error(self, "This enclosure is full or under maintenance.")
            return

        def do_register():
            with db.transaction() as tx:
                new_id = tx.insert("ANIMAL", {
                    "SpeciesID": v["SpeciesID"], "EnclosureID": v["EnclosureID"], "Name": v["Name"],
                    "Gender": v["Gender"], "BirthDate": v["BirthDate"], "ArrivalDate": v["ArrivalDate"],
                    "Origin": v["Origin"], "HealthStatus": "Healthy"}, "AnimalID")
                if v["VetID"] and v["Vaccine"]:
                    tx.insert("VACCINATION", {
                        "AnimalID": new_id, "VetID": v["VetID"], "VaccineName": v["Vaccine"],
                        "DateGiven": w.today(), "NextDue": v["NextDue"]}, "VaccinationID")
                if v["KeeperID"]:
                    tx.insert("CARE_ASSIGNMENT", {
                        "StaffID": v["KeeperID"], "AnimalID": new_id, "StartDate": w.today(),
                        "Responsibility": "Daily care"}, "AssignmentID")
                if v["FoodID"]:
                    tx.insert("FEEDING_PLAN", {
                        "AnimalID": new_id, "FoodID": v["FoodID"], "QuantityPerMeal": v["Qty"] or 1.0,
                        "FeedingTime": v["Time"] or dt.time(9, 0), "Frequency": "Daily"}, "PlanID")

        self.run(do_register, f"{v['Name']} was registered.", roles=["Manager"])


# ---------------------------------------------------------------- detail window
class AnimalDetail(tk.Toplevel):
    def __init__(self, screen, animal_id):
        super().__init__(screen)
        self.screen = screen
        self.user = screen.user
        self.animal_id = animal_id
        self.configure(bg=w.COLORS["bg"])
        self.geometry("1100x680")
        self.transient(screen.winfo_toplevel())

        body = ttk.Frame(self, padding=18)
        body.pack(fill="both", expand=True)
        self.header = ttk.Label(body, text="", style="Title.TLabel")
        self.header.pack(anchor="w")
        self.facts = ttk.Label(body, text="", style="Muted.TLabel")
        self.facts.pack(anchor="w", pady=(2, 8))
        metrics = ttk.Frame(body)
        metrics.pack(fill="x", pady=(0, 10))
        self.m_health = screen.metric(metrics, "Health")
        self.m_cons = screen.metric(metrics, "Conservation")
        self.m_loc = screen.metric(metrics, "Location")
        self.m_age = screen.metric(metrics, "Age")

        actions = ttk.Frame(body)
        actions.pack(fill="x", pady=(0, 8))
        if auth.has_role(self.user, "Manager", "Veterinarian"):
            ttk.Button(actions, text="Edit animal", command=self.edit).pack(side="left")
        if auth.has_role(self.user, "Manager"):
            ttk.Button(actions, text="Transfer…", style="Accent.TButton", command=self.transfer).pack(side="left", padx=6)
            self.place_btn = ttk.Button(actions, text="Place in enclosure", command=self.place)
            self.place_btn.pack(side="left")
            ttk.Button(actions, text="Mark deceased", style="Danger.TButton", command=self.deceased).pack(side="left", padx=6)

        nb = ttk.Notebook(body)
        nb.pack(fill="both", expand=True)
        self.tables = {}
        for name in ["Care team", "Medical", "Vaccinations", "Feeding plans", "Transfers"]:
            tab = ttk.Frame(nb, padding=8)
            nb.add(tab, text=name)
            table = w.Table(tab, height=8)
            table.pack(fill="both", expand=True)
            self.tables[name] = table
            bar = ttk.Frame(tab)
            bar.pack(fill="x", pady=(6, 0))
            if name == "Care team" and auth.has_role(self.user, "Manager"):
                ttk.Button(bar, text="Assign keeper", command=self.assign_keeper).pack(side="left")
                ttk.Button(bar, text="End selected assignment", command=self.end_assignment).pack(side="left", padx=6)
            if name == "Feeding plans" and auth.has_role(self.user, "Manager", "Veterinarian"):
                ttk.Button(bar, text="Add diet line", command=self.add_plan).pack(side="left")
                ttk.Button(bar, text="Change quantity of selected", command=self.change_plan).pack(side="left", padx=6)
            if name == "Medical":
                ttk.Label(bar, text="New checkups are recorded in the Veterinary Center.",
                          style="Muted.TLabel").pack(side="left")
        self.refresh()

    # ---------------------------------------------------------- data
    def refresh(self):
        a = db.query(
            "SELECT a.AnimalID, a.Name, a.Gender, a.BirthDate, a.ArrivalDate, a.Origin, a.HealthStatus, "
            "       a.EnclosureID, s.CommonName, s.ScientificName, s.DietType, "
            "       cs.Code AS StatusCode, cs.Name AS ConservationStatus, "
            "       e.Name AS Enclosure, h.Name AS Habitat "
            "FROM ANIMAL a "
            "JOIN SPECIES s ON a.SpeciesID = s.SpeciesID "
            "JOIN CONSERVATION_STATUS cs ON s.StatusID = cs.StatusID "
            "LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID "
            "LEFT JOIN HABITAT h ON e.HabitatID = h.HabitatID "
            "WHERE a.AnimalID = ?", [self.animal_id])[0]
        self.a = a
        self.title(f"Animal — {a['Name']}")
        birth = db.to_date(a["BirthDate"])
        self.header.configure(text=f"{a['Name']} — {a['CommonName']}")
        self.facts.configure(text=f"{a['ScientificName']} · Diet: {a['DietType']} · Gender: {a['Gender']} · "
                                  f"Arrived: {w.fmt(a['ArrivalDate'])} · Origin: {a['Origin'] or '-'} · "
                                  f"Habitat: {a['Habitat'] or '-'}")
        self.m_health.configure(text=a["HealthStatus"])
        self.m_cons.configure(text=f"{a['StatusCode']} · {a['ConservationStatus']}")
        self.m_loc.configure(text=a["Enclosure"] or "No enclosure")
        self.m_age.configure(text=f"{(w.today() - birth).days // 365} years" if birth else "unknown")

        aid = [self.animal_id]
        self.tables["Care team"].load(db.query(
            "SELECT ca.AssignmentID, st.FirstName, st.LastName, ca.Responsibility, ca.StartDate, ca.EndDate "
            "FROM CARE_ASSIGNMENT ca JOIN STAFF st ON ca.StaffID = st.StaffID "
            "WHERE ca.AnimalID = ? ORDER BY ca.EndDate, ca.StartDate DESC", aid))
        self.tables["Medical"].load(db.query(
            "SELECT m.CheckupDate, m.Diagnosis, m.Treatment, m.NextCheckup, "
            "       st.FirstName AS Vet, st.LastName AS VetLastName "
            "FROM MEDICAL_RECORD m JOIN STAFF st ON m.VetID = st.StaffID "
            "WHERE m.AnimalID = ? ORDER BY m.CheckupDate DESC", aid))
        self.tables["Vaccinations"].load(db.query(
            "SELECT v.VaccineName, v.DateGiven, v.NextDue, st.FirstName AS Vet, st.LastName AS VetLastName "
            "FROM VACCINATION v JOIN STAFF st ON v.VetID = st.StaffID "
            "WHERE v.AnimalID = ? ORDER BY v.DateGiven DESC", aid))
        self.tables["Feeding plans"].load(db.query(
            "SELECT fp.PlanID, ft.Name AS Food, fp.QuantityPerMeal, ft.Unit, fp.FeedingTime, fp.Frequency, "
            "       (SELECT MAX(fl.FedAt) FROM FEEDING_LOG fl WHERE fl.PlanID = fp.PlanID) AS LastFed "
            "FROM FEEDING_PLAN fp JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID "
            "WHERE fp.AnimalID = ? ORDER BY fp.FeedingTime", aid))
        self.tables["Transfers"].load(db.query(
            "SELECT t.TransferDate, ef.Name AS FromEnclosure, et.Name AS ToEnclosure, t.Reason "
            "FROM ANIMAL_TRANSFER t "
            "JOIN ENCLOSURE ef ON t.FromEnclosureID = ef.EnclosureID "
            "JOIN ENCLOSURE et ON t.ToEnclosureID = et.EnclosureID "
            "WHERE t.AnimalID = ? ORDER BY t.TransferDate DESC", aid))
        if hasattr(self, "place_btn"):
            self.place_btn.configure(state="normal" if a["EnclosureID"] is None
                                     and a["HealthStatus"] != "Deceased" else "disabled")

    def run(self, action, success, roles):
        if self.screen.run(action, success, roles=roles):
            self.refresh()

    def _alive(self):
        if self.a["HealthStatus"] == "Deceased":
            w.error(self, "This animal is marked as deceased.")
            return False
        return True

    # ---------------------------------------------------------- actions
    def edit(self):
        a = self.a
        v = w.ask_form(self, "Edit animal", [
            {"name": "Name", "label": "Name", "type": "text", "default": a["Name"], "required": True},
            {"name": "Gender", "label": "Gender", "type": "choice", "options": GENDER,
             "default": a["Gender"], "required": True},
            {"name": "Health", "label": "Health status", "type": "choice",
             "options": {h: h for h in HEALTH[:-1]}, "default": a["HealthStatus"], "required": True},
            {"name": "Origin", "label": "Origin", "type": "text", "default": a["Origin"]},
        ])
        if v:
            self.run(lambda: db.execute(
                "UPDATE ANIMAL SET Name = ?, Gender = ?, HealthStatus = ?, Origin = ? WHERE AnimalID = ?",
                [v["Name"], v["Gender"], v["Health"], v["Origin"], self.animal_id]),
                "Animal updated.", ["Manager", "Veterinarian"])

    def transfer(self):
        if not self._alive():
            return
        current = self.a["EnclosureID"]
        if current is None:
            w.error(self, "The animal has no current enclosure. Use 'Place in enclosure'.")
            return
        v = w.ask_form(self, "Transfer animal", [
            {"name": "info", "label": "The move is saved in one transaction: transfer history + new location.",
             "type": "info"},
            {"name": "To", "label": "Destination", "type": "choice",
             "options": enclosures_with_space(exclude_id=current), "required": True},
            {"name": "Reason", "label": "Reason", "type": "text", "default": "Space"},
        ], submit_text="Confirm transfer")
        if not v:
            return
        if not has_free_space(v["To"]):
            w.error(self, "This enclosure is full or under maintenance.")
            return

        def do_transfer():
            with db.transaction() as tx:
                tx.insert("ANIMAL_TRANSFER", {
                    "AnimalID": self.animal_id, "FromEnclosureID": int(current), "ToEnclosureID": v["To"],
                    "TransferDate": w.today(), "Reason": v["Reason"]}, "TransferID")
                tx.execute("UPDATE ANIMAL SET EnclosureID = ? WHERE AnimalID = ?", [v["To"], self.animal_id])

        self.run(do_transfer, "Transfer saved.", ["Manager"])

    def place(self):
        if not self._alive():
            return
        v = w.ask_form(self, "Place in enclosure", [
            {"name": "To", "label": "Enclosure", "type": "choice", "options": enclosures_with_space(), "required": True}])
        if v and has_free_space(v["To"]):
            self.run(lambda: db.execute("UPDATE ANIMAL SET EnclosureID = ? WHERE AnimalID = ?",
                                        [v["To"], self.animal_id]), "Animal placed.", ["Manager"])

    def deceased(self):
        if not self._alive():
            return
        if not w.confirm(self, f"Mark {self.a['Name']} as deceased?\n\nHealth becomes 'Deceased', the enclosure "
                               "is cleared and active care assignments end. History is kept."):
            return

        def do_deceased():
            with db.transaction() as tx:
                tx.execute("UPDATE ANIMAL SET HealthStatus = 'Deceased', EnclosureID = NULL WHERE AnimalID = ?",
                           [self.animal_id])
                tx.execute("UPDATE CARE_ASSIGNMENT SET EndDate = ? WHERE AnimalID = ? AND EndDate IS NULL",
                           [w.today(), self.animal_id])

        self.run(do_deceased, "Animal marked as deceased.", ["Manager"])

    def assign_keeper(self):
        v = w.ask_form(self, "Assign a keeper", [
            {"name": "Keeper", "label": "Keeper", "type": "choice", "options": staff_options("Keeper"), "required": True},
            {"name": "Resp", "label": "Responsibility", "type": "text", "default": "Daily care"}])
        if v:
            self.run(lambda: db.insert("CARE_ASSIGNMENT", {
                "StaffID": v["Keeper"], "AnimalID": self.animal_id, "StartDate": w.today(),
                "Responsibility": v["Resp"]}, "AssignmentID"), "Keeper assigned.", ["Manager"])

    def end_assignment(self):
        row = self.tables["Care team"].selected()
        if row is None or row["EndDate"] is not None:
            w.error(self, "Select an active assignment first.")
            return
        self.run(lambda: db.execute("UPDATE CARE_ASSIGNMENT SET EndDate = ? WHERE AssignmentID = ?",
                                    [w.today(), int(row["AssignmentID"])]), "Assignment ended.", ["Manager"])

    def add_plan(self):
        v = w.ask_form(self, "Add diet line", [
            {"name": "Food", "label": "Food", "type": "choice", "options": food_options(), "required": True},
            {"name": "Qty", "label": "Quantity per meal", "type": "float", "default": 1.0, "required": True, "min": 0.1},
            {"name": "Time", "label": "Feeding time", "type": "time", "default": dt.time(9, 0), "required": True},
            {"name": "Freq", "label": "Frequency", "type": "choice", "required": True,
             "options": {"Daily": "Daily", "Every 2 days": "Every 2 days", "Weekly": "Weekly"}}])
        if v:
            self.run(lambda: db.insert("FEEDING_PLAN", {
                "AnimalID": self.animal_id, "FoodID": v["Food"], "QuantityPerMeal": v["Qty"],
                "FeedingTime": v["Time"], "Frequency": v["Freq"]}, "PlanID"),
                "Feeding plan added.", ["Manager", "Veterinarian"])

    def change_plan(self):
        row = self.tables["Feeding plans"].selected()
        if row is None:
            w.error(self, "Select a diet line first.")
            return
        v = w.ask_form(self, f"Change quantity — {row['Food']}", [
            {"name": "Qty", "label": "New quantity per meal", "type": "float",
             "default": row["QuantityPerMeal"], "required": True, "min": 0.1}])
        if v:
            self.run(lambda: db.execute("UPDATE FEEDING_PLAN SET QuantityPerMeal = ? WHERE PlanID = ?",
                                        [v["Qty"], int(row["PlanID"])]),
                     "Feeding plan updated.", ["Manager", "Veterinarian"])
