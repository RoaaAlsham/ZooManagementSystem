"""Feeding Today: the keeper's daily worksheet (feeding plan vs. feeding log)."""
import datetime as dt
import tkinter as tk
from tkinter import ttk

import auth
import db
from ui import widgets as w


class FeedingScreen(w.Screen):
    def build(self):
        top = ttk.Frame(self)
        top.pack(fill="x")
        ttk.Label(top, text=f"Date: {w.today():%d.%m.%Y}", style="Sub.TLabel").pack(side="left")
        self.mine = tk.BooleanVar(value=auth.has_role(self.user, "Keeper"))
        ttk.Checkbutton(top, text="Only my animals", variable=self.mine, command=self.safe_refresh).pack(
            side="left", padx=20)
        ttk.Label(top, text="Habitat").pack(side="left")
        self.habitat = tk.StringVar(value="All")
        habitats = ["All"] + [r["Name"] for r in db.query("SELECT Name FROM HABITAT ORDER BY Name")]
        combo = ttk.Combobox(top, textvariable=self.habitat, values=habitats, state="readonly", width=20)
        combo.pack(side="left", padx=6)
        combo.bind("<<ComboboxSelected>>", lambda _e: self.safe_refresh())

        prog = ttk.Frame(self)
        prog.pack(fill="x", pady=10)
        self.progress = ttk.Progressbar(prog, length=360, style="green.Horizontal.TProgressbar")
        self.progress.pack(side="left")
        self.progress_text = ttk.Label(prog, text="")
        self.progress_text.pack(side="left", padx=10)

        self.table = w.Table(self, height=16, on_double_click=self.mark_fed)
        self.table.pack(fill="both", expand=True)
        if auth.has_role(self.user, "Keeper", "Manager"):
            bar = self.toolbar(self)
            ttk.Button(bar, text="✔ Mark selected as fed", style="Accent.TButton", command=self.mark_fed).pack(side="left")
            ttk.Label(bar, text="Tip: double-click a row to mark it as fed.", style="Muted.TLabel").pack(side="right")

    def refresh(self):
        start = dt.datetime.combine(w.today(), dt.time(0, 0))
        rows = db.query(
            "SELECT fp.PlanID, fp.FeedingTime, a.AnimalID, a.Name AS Animal, e.Name AS Enclosure, "
            "       h.Name AS Habitat, ft.Name AS Food, fp.QuantityPerMeal, ft.Unit, "
            "       fl.LogID, fl.FedAt, fl.QuantityGiven "
            "FROM FEEDING_PLAN fp "
            "JOIN ANIMAL a ON fp.AnimalID = a.AnimalID "
            "JOIN FOOD_TYPE ft ON fp.FoodID = ft.FoodID "
            "LEFT JOIN ENCLOSURE e ON a.EnclosureID = e.EnclosureID "
            "LEFT JOIN HABITAT h ON e.HabitatID = h.HabitatID "
            "LEFT JOIN FEEDING_LOG fl ON fl.PlanID = fp.PlanID AND fl.FedAt >= ? AND fl.FedAt < ? "
            "WHERE a.HealthStatus <> 'Deceased' "
            "ORDER BY fp.FeedingTime, a.Name", [start, start + dt.timedelta(days=1)])
        if self.mine.get():
            mine = {int(r["AnimalID"]) for r in db.query(
                "SELECT AnimalID FROM CARE_ASSIGNMENT WHERE StaffID = ? AND EndDate IS NULL", [self.user["StaffID"]])}
            rows = [r for r in rows if int(r["AnimalID"]) in mine]
        if self.habitat.get() != "All":
            rows = [r for r in rows if r["Habitat"] == self.habitat.get()]
        now = dt.datetime.now().time()
        for r in rows:
            if r["LogID"] is not None:
                r["Status"] = "✔ Done"
            elif db.to_time(r["FeedingTime"]) < now:
                r["Status"] = "⏰ Late"
            else:
                r["Status"] = "⏳ Pending"
        done = sum(1 for r in rows if r["Status"] == "✔ Done")
        self.progress["maximum"] = max(len(rows), 1)
        self.progress["value"] = done
        self.progress_text.configure(text=f"{done} / {len(rows)} feedings done")
        self.table.load(rows, ["Status", "FeedingTime", "Animal", "Enclosure", "Food", "QuantityPerMeal",
                               "Unit", "FedAt", "QuantityGiven", "PlanID"])

    def mark_fed(self):
        if not auth.has_role(self.user, "Keeper", "Manager"):
            return
        row = self.table.selected()
        if row is None:
            w.error(self, "Select a feeding first.")
            return
        if row["Status"] == "✔ Done":
            w.error(self, "This feeding is already logged today.")
            return
        v = w.ask_form(self, f"Feed {row['Animal']} — {row['Food']}", [
            {"name": "Qty", "label": f"Quantity given ({row['Unit']})", "type": "float",
             "default": row["QuantityPerMeal"], "required": True, "min": 0},
            {"name": "Notes", "label": "Notes (appetite, refusal …)", "type": "text"}], submit_text="Save feeding")
        if v:
            self.run(lambda: db.insert("FEEDING_LOG", {
                "PlanID": int(row["PlanID"]), "StaffID": self.user["StaffID"],
                "FedAt": dt.datetime.now().replace(microsecond=0), "QuantityGiven": v["Qty"],
                "Notes": v["Notes"]}, "LogID"), "Feeding saved.", ["Keeper", "Manager"])
