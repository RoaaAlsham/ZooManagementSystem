"""Admin Settings: zoo profile, departments, species, conservation statuses, ticket types."""
from tkinter import ttk

import db
from ui import widgets as w

DIETS = {d: d for d in ["Carnivore", "Herbivore", "Omnivore", "Insectivore"]}


class AdminScreen(w.Screen):
    def build(self):
        nb = ttk.Notebook(self)
        nb.pack(fill="both", expand=True)
        self.tables = {}
        tabs = [
            ("Zoo", [("Edit zoo profile", self.edit_zoo)]),
            ("Departments", [("＋ Add department", self.add_department)]),
            ("Species", [("＋ Add species", self.add_species)]),
            ("Conservation status", [("＋ Add status", self.add_status)]),
            ("Ticket types", [("＋ Add ticket type", self.add_ticket_type), ("Change price of selected", self.change_price)]),
        ]
        for name, buttons in tabs:
            tab = ttk.Frame(nb, padding=8)
            nb.add(tab, text=name)
            table = w.Table(tab, height=14)
            table.pack(fill="both", expand=True)
            self.tables[name] = table
            bar = self.toolbar(tab)
            for i, (text, cmd) in enumerate(buttons):
                ttk.Button(bar, text=text, style="Accent.TButton" if i == 0 else "TButton",
                           command=cmd).pack(side="left", padx=(0, 6))

    def refresh(self):
        self.tables["Zoo"].load(db.query("SELECT ZooID, Name, City, Address, Phone, OpenDate FROM ZOO"))
        self.tables["Departments"].load(db.query(
            "SELECT d.DepartmentID, d.Name, d.Description, COUNT(s.StaffID) AS Employees "
            "FROM DEPARTMENT d LEFT JOIN STAFF s ON s.DepartmentID = d.DepartmentID "
            "GROUP BY d.DepartmentID, d.Name, d.Description ORDER BY d.Name"))
        self.tables["Species"].load(db.query(
            "SELECT s.SpeciesID, s.CommonName, s.ScientificName, s.DietType, s.AvgLifespanYears, "
            "       cs.Code, cs.Name AS Status, "
            "       (SELECT COUNT(*) FROM ANIMAL a WHERE a.SpeciesID = s.SpeciesID) AS Animals "
            "FROM SPECIES s JOIN CONSERVATION_STATUS cs ON s.StatusID = cs.StatusID ORDER BY s.CommonName"))
        self.statuses = db.query("SELECT StatusID, Code, Name, Description FROM CONSERVATION_STATUS ORDER BY StatusID")
        self.tables["Conservation status"].load(self.statuses)
        self.tables["Ticket types"].load(db.query(
            "SELECT TicketTypeID, Name, Price, Description FROM TICKET_TYPE ORDER BY Price"))

    def edit_zoo(self):
        z = self.tables["Zoo"].rows[0]
        v = w.ask_form(self, "Edit zoo profile", [
            {"name": "Name", "label": "Name", "type": "text", "default": z["Name"], "required": True},
            {"name": "City", "label": "City", "type": "text", "default": z["City"], "required": True},
            {"name": "Address", "label": "Address", "type": "text", "default": z["Address"]},
            {"name": "Phone", "label": "Phone", "type": "text", "default": z["Phone"]}])
        if v:
            self.run(lambda: db.execute("UPDATE ZOO SET Name = ?, City = ?, Address = ?, Phone = ? WHERE ZooID = ?",
                                        [v["Name"], v["City"], v["Address"], v["Phone"], int(z["ZooID"])]),
                     "Zoo profile saved.", ["Manager"])

    def add_department(self):
        v = w.ask_form(self, "Add department", [
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "Desc", "label": "Description", "type": "text"}])
        if v:
            zoo_id = int(db.scalar("SELECT MIN(ZooID) FROM ZOO"))
            self.run(lambda: db.insert("DEPARTMENT", {"ZooID": zoo_id, "Name": v["Name"], "Description": v["Desc"]},
                                       "DepartmentID"), "Department added.", ["Manager"])

    def add_species(self):
        v = w.ask_form(self, "Add species", [
            {"name": "Common", "label": "Common name", "type": "text", "required": True},
            {"name": "Sci", "label": "Scientific name", "type": "text", "required": True},
            {"name": "Diet", "label": "Diet", "type": "choice", "options": DIETS, "required": True},
            {"name": "Life", "label": "Average lifespan (years)", "type": "int", "default": 15, "min": 1},
            {"name": "Status", "label": "Conservation status", "type": "choice", "required": True,
             "options": w.opts(self.statuses, "StatusID", lambda r: f"{r['Code']} — {r['Name']}")}])
        if v:
            self.run(lambda: db.insert("SPECIES", {
                "StatusID": v["Status"], "CommonName": v["Common"], "ScientificName": v["Sci"],
                "DietType": v["Diet"], "AvgLifespanYears": v["Life"]}, "SpeciesID"), "Species added.", ["Manager"])

    def add_status(self):
        v = w.ask_form(self, "Add conservation status", [
            {"name": "Code", "label": "Code (max 5 letters)", "type": "text", "required": True},
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "Desc", "label": "Description", "type": "text"}])
        if not v:
            return
        if len(v["Code"]) > 5:
            w.error(self, "The code can have at most 5 letters.")
            return
        self.run(lambda: db.insert("CONSERVATION_STATUS", {
            "Code": v["Code"].upper(), "Name": v["Name"], "Description": v["Desc"]}, "StatusID"),
            "Status added.", ["Manager"])

    def add_ticket_type(self):
        v = w.ask_form(self, "Add ticket type", [
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "Price", "label": "Price", "type": "float", "default": 100, "required": True, "min": 0},
            {"name": "Desc", "label": "Description", "type": "text"}])
        if v:
            self.run(lambda: db.insert("TICKET_TYPE", {"Name": v["Name"], "Price": v["Price"], "Description": v["Desc"]},
                                       "TicketTypeID"), "Ticket type added.", ["Manager"])

    def change_price(self):
        row = self.tables["Ticket types"].selected()
        if row is None:
            w.error(self, "Select a ticket type first.")
            return
        v = w.ask_form(self, f"Change price — {row['Name']}", [
            {"name": "Price", "label": "New price", "type": "float", "default": row["Price"], "required": True, "min": 0}])
        if v:
            self.run(lambda: db.execute("UPDATE TICKET_TYPE SET Price = ? WHERE TicketTypeID = ?",
                                        [v["Price"], int(row["TicketTypeID"])]), "Price updated.", ["Manager"])
