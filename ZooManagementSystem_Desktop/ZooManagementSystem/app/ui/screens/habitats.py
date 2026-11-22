"""Habitats and Enclosures: places and their capacity."""
from tkinter import ttk

import auth
import db
from ui import widgets as w

CONDITIONS = {"Good": "Good", "Needs Repair": "Needs Repair", "Under Maintenance": "Under Maintenance"}


class HabitatsScreen(w.Screen):
    def build(self):
        self.section(self, "Habitats")
        self.habitats = w.Table(self, height=6)
        self.habitats.pack(fill="x")
        self.section(self, "Enclosures and occupancy")
        self.enclosures = w.Table(self, height=10)
        self.enclosures.pack(fill="both", expand=True)
        if auth.has_role(self.user, "Manager"):
            bar = self.toolbar(self)
            ttk.Button(bar, text="＋ Add habitat", style="Accent.TButton", command=self.add_habitat).pack(side="left")
            ttk.Button(bar, text="＋ Add enclosure", command=self.add_enclosure).pack(side="left", padx=6)
            ttk.Button(bar, text="Update selected enclosure", command=self.update_enclosure).pack(side="left")

    def refresh(self):
        self.zoo_id = int(db.scalar("SELECT MIN(ZooID) FROM ZOO"))
        self.habitat_rows = db.query(
            "SELECT h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm, COUNT(e.EnclosureID) AS Enclosures "
            "FROM HABITAT h LEFT JOIN ENCLOSURE e ON e.HabitatID = h.HabitatID "
            "WHERE h.ZooID = ? "
            "GROUP BY h.HabitatID, h.Name, h.BiomeType, h.Climate, h.AreaSqm ORDER BY h.Name", [self.zoo_id])
        self.habitats.load(self.habitat_rows)
        rows = db.query(
            "SELECT e.EnclosureID, h.Name AS Habitat, e.Name AS Enclosure, e.Capacity, "
            "       COUNT(a.AnimalID) AS Occupancy, e.Condition, e.LastMaintenance "
            "FROM ENCLOSURE e "
            "JOIN HABITAT h ON e.HabitatID = h.HabitatID "
            "LEFT JOIN ANIMAL a ON a.EnclosureID = e.EnclosureID "
            "GROUP BY e.EnclosureID, h.Name, e.Name, e.Capacity, e.Condition, e.LastMaintenance "
            "ORDER BY h.Name, e.Name")
        for r in rows:
            r["FreeSpots"] = int(r["Capacity"]) - int(r["Occupancy"])
        self.enclosures.load(rows)

    def add_habitat(self):
        v = w.ask_form(self, "Add habitat", [
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "Biome", "label": "Biome type", "type": "text", "default": "Savanna", "required": True},
            {"name": "Climate", "label": "Climate", "type": "text", "default": "Temperate"},
            {"name": "Area", "label": "Area (m²)", "type": "float", "default": 1000, "min": 1}])
        if v:
            self.run(lambda: db.insert("HABITAT", {
                "ZooID": self.zoo_id, "Name": v["Name"], "BiomeType": v["Biome"],
                "Climate": v["Climate"], "AreaSqm": v["Area"]}, "HabitatID"), "Habitat added.", ["Manager"])

    def add_enclosure(self):
        v = w.ask_form(self, "Add enclosure", [
            {"name": "Habitat", "label": "Habitat", "type": "choice", "required": True,
             "options": w.opts(self.habitat_rows, "HabitatID", "Name")},
            {"name": "Name", "label": "Enclosure name", "type": "text", "required": True},
            {"name": "Cap", "label": "Capacity", "type": "int", "default": 4, "required": True, "min": 1},
            {"name": "Cond", "label": "Condition", "type": "choice", "options": CONDITIONS, "required": True}])
        if v:
            self.run(lambda: db.insert("ENCLOSURE", {
                "HabitatID": v["Habitat"], "Name": v["Name"], "Capacity": v["Cap"], "Condition": v["Cond"],
                "LastMaintenance": w.today()}, "EnclosureID"), "Enclosure added.", ["Manager"])

    def update_enclosure(self):
        row = self.enclosures.selected()
        if row is None:
            w.error(self, "Select an enclosure first.")
            return
        v = w.ask_form(self, f"Update enclosure — {row['Enclosure']}", [
            {"name": "Cap", "label": "Capacity", "type": "int", "default": row["Capacity"], "required": True,
             "min": max(1, int(row["Occupancy"]))},
            {"name": "Cond", "label": "Condition", "type": "choice", "options": CONDITIONS,
             "default": row["Condition"], "required": True},
            {"name": "Maint", "label": "Last maintenance", "type": "date", "default": w.today()}])
        if v:
            self.run(lambda: db.execute(
                "UPDATE ENCLOSURE SET Capacity = ?, Condition = ?, LastMaintenance = ? WHERE EnclosureID = ?",
                [v["Cap"], v["Cond"], v["Maint"], int(row["EnclosureID"])]), "Enclosure updated.", ["Manager"])
