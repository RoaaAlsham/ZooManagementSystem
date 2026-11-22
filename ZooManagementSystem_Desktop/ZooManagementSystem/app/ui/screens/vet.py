"""Veterinary Center: due vaccines, overdue checkups, new medical records.

Transaction: new checkup + health status change (MEDICAL_RECORD + ANIMAL).
"""
import datetime as dt
from tkinter import ttk

import auth
import db
from ui import widgets as w

HEALTH = {"Healthy": "Healthy", "Under Treatment": "Under Treatment", "Quarantine": "Quarantine"}


class VetScreen(w.Screen):
    def build(self):
        self.section(self, "Vaccines due in the next 30 days (or overdue)")
        self.vaccines = w.Table(self, height=6)
        self.vaccines.pack(fill="x")
        row = ttk.Frame(self)
        row.pack(fill="both", expand=True)
        left, right = ttk.Frame(row), ttk.Frame(row)
        left.pack(side="left", fill="both", expand=True, padx=(0, 8))
        right.pack(side="left", fill="both", expand=True)
        self.section(left, "Overdue checkups")
        self.overdue = w.Table(left, height=7)
        self.overdue.pack(fill="both", expand=True)
        self.section(right, "Under treatment / quarantine")
        self.treatment = w.Table(right, height=7)
        self.treatment.pack(fill="both", expand=True)
        bar = self.toolbar(self)
        if auth.has_role(self.user, "Veterinarian"):
            ttk.Button(bar, text="＋ New checkup", style="Accent.TButton", command=self.checkup).pack(side="left")
            ttk.Button(bar, text="＋ Record vaccination", command=self.vaccinate).pack(side="left", padx=6)
        else:
            ttk.Label(bar, text="Only veterinarians can add medical records.", style="Muted.TLabel").pack(side="left")

    def refresh(self):
        t = w.today()
        rows = db.query(
            "SELECT a.AnimalID, a.Name AS Animal, v.VaccineName, v.DateGiven, v.NextDue "
            "FROM VACCINATION v JOIN ANIMAL a ON v.AnimalID = a.AnimalID "
            "WHERE v.NextDue <= ? AND a.HealthStatus <> 'Deceased' "
            "  AND NOT EXISTS (SELECT 1 FROM VACCINATION v2 WHERE v2.AnimalID = v.AnimalID "
            "                  AND v2.VaccineName = v.VaccineName AND v2.DateGiven > v.DateGiven) "
            "ORDER BY v.NextDue", [t + dt.timedelta(days=30)])
        for r in rows:
            r["Status"] = "🔴 Overdue" if db.to_date(r["NextDue"]) < t else "🟡 Due soon"
        self.vaccines.load(rows, ["Status", "Animal", "VaccineName", "DateGiven", "NextDue", "AnimalID"])
        self.overdue.load(db.query(
            "SELECT a.AnimalID, a.Name AS Animal, MAX(m.NextCheckup) AS NextCheckup "
            "FROM ANIMAL a JOIN MEDICAL_RECORD m ON m.AnimalID = a.AnimalID "
            "WHERE a.HealthStatus <> 'Deceased' GROUP BY a.AnimalID, a.Name "
            "HAVING MAX(m.NextCheckup) < ? ORDER BY NextCheckup", [t]))
        self.treatment.load(db.query(
            "SELECT a.AnimalID, a.Name AS Animal, s.CommonName AS Species, a.HealthStatus "
            "FROM ANIMAL a JOIN SPECIES s ON a.SpeciesID = s.SpeciesID "
            "WHERE a.HealthStatus IN ('Under Treatment', 'Quarantine') ORDER BY a.Name"))

    def _animals(self):
        return w.opts(db.query("SELECT AnimalID, Name FROM ANIMAL WHERE HealthStatus <> 'Deceased' ORDER BY Name"),
                      "AnimalID", lambda r: f"{r['Name']} (#{r['AnimalID']})")

    def checkup(self):
        t = w.today()
        v = w.ask_form(self, "New checkup", [
            {"name": "info", "label": "The checkup and the new health status are saved in one transaction.",
             "type": "info"},
            {"name": "Animal", "label": "Animal", "type": "choice", "options": self._animals(), "required": True},
            {"name": "Diagnosis", "label": "Diagnosis", "type": "text"},
            {"name": "Treatment", "label": "Treatment", "type": "text"},
            {"name": "Next", "label": "Next checkup", "type": "date", "default": t + dt.timedelta(days=30),
             "min": t + dt.timedelta(days=1)},
            {"name": "Status", "label": "New health status", "type": "choice", "options": HEALTH, "required": True}],
            submit_text="Save checkup")
        if not v:
            return

        def do_checkup():
            with db.transaction() as tx:
                tx.insert("MEDICAL_RECORD", {
                    "AnimalID": v["Animal"], "VetID": self.user["StaffID"], "CheckupDate": t,
                    "Diagnosis": v["Diagnosis"], "Treatment": v["Treatment"], "NextCheckup": v["Next"]}, "RecordID")
                tx.execute("UPDATE ANIMAL SET HealthStatus = ? WHERE AnimalID = ?", [v["Status"], v["Animal"]])

        self.run(do_checkup, "Checkup saved.", ["Veterinarian"])

    def vaccinate(self):
        t = w.today()
        v = w.ask_form(self, "Record vaccination", [
            {"name": "Animal", "label": "Animal", "type": "choice", "options": self._animals(), "required": True},
            {"name": "Vaccine", "label": "Vaccine name", "type": "text", "required": True},
            {"name": "Next", "label": "Next dose due", "type": "date", "default": t + dt.timedelta(days=365),
             "min": t + dt.timedelta(days=1)}])
        if v:
            self.run(lambda: db.insert("VACCINATION", {
                "AnimalID": v["Animal"], "VetID": self.user["StaffID"], "VaccineName": v["Vaccine"],
                "DateGiven": t, "NextDue": v["Next"]}, "VaccinationID"), "Vaccination saved.", ["Veterinarian"])
