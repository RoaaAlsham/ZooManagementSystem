"""Staff Directory: employees, hierarchy, shifts and keeper workload.

Managers see everybody (including salary) and can add staff and shifts.
Other roles only see their own profile and shifts.
"""
import datetime as dt
import tkinter as tk
from tkinter import ttk

import auth
import db
from ui import widgets as w

ROLES = {r: r for r in auth.ROLES}


class StaffScreen(w.Screen):
    def build(self):
        self.manager = auth.has_role(self.user, "Manager")
        if not self.manager:
            self._profile(self)
            return
        nb = ttk.Notebook(self)
        nb.pack(fill="both", expand=True)

        directory = ttk.Frame(nb, padding=8)
        nb.add(directory, text="Directory")
        bar = ttk.Frame(directory)
        bar.pack(fill="x")
        self.dept = tk.StringVar(value="All")
        self.role = tk.StringVar(value="All")
        ttk.Label(bar, text="Department").pack(side="left")
        depts = ["All"] + [r["Name"] for r in db.query("SELECT Name FROM DEPARTMENT ORDER BY Name")]
        c1 = ttk.Combobox(bar, textvariable=self.dept, values=depts, state="readonly", width=18)
        c1.pack(side="left", padx=(4, 12))
        ttk.Label(bar, text="Role").pack(side="left")
        c2 = ttk.Combobox(bar, textvariable=self.role, values=["All"] + auth.ROLES, state="readonly", width=16)
        c2.pack(side="left", padx=4)
        for c in (c1, c2):
            c.bind("<<ComboboxSelected>>", lambda _e: self.safe_refresh())
        self.staff = w.Table(directory, height=14)
        self.staff.pack(fill="both", expand=True, pady=(8, 0))
        tools = self.toolbar(directory)
        ttk.Button(tools, text="＋ Add employee", style="Accent.TButton", command=self.add_staff).pack(side="left")
        ttk.Button(tools, text="Update selected (salary / role)", command=self.edit_staff).pack(side="left", padx=6)

        shifts = ttk.Frame(nb, padding=8)
        nb.add(shifts, text="Shifts")
        bar = ttk.Frame(shifts)
        bar.pack(fill="x")
        ttk.Label(bar, text="Week starting (YYYY-MM-DD)").pack(side="left")
        monday = w.today() - dt.timedelta(days=w.today().weekday())
        self.week = tk.StringVar(value=monday.isoformat())
        ttk.Entry(bar, textvariable=self.week, width=12).pack(side="left", padx=6)
        ttk.Button(bar, text="Show", command=self.safe_refresh).pack(side="left")
        self.shifts = w.Table(shifts, height=14)
        self.shifts.pack(fill="both", expand=True, pady=(8, 0))
        tools = self.toolbar(shifts)
        ttk.Button(tools, text="＋ Add shift", style="Accent.TButton", command=self.add_shift).pack(side="left")

        workload = ttk.Frame(nb, padding=8)
        nb.add(workload, text="Keeper workload")
        self.section(workload, "Animals each keeper currently cares for")
        self.workload = w.Table(workload, height=7)
        self.workload.pack(fill="x")
        self.section(workload, "Animals without an active keeper")
        self.unassigned = w.Table(workload, height=6)
        self.unassigned.pack(fill="x")

        mine = ttk.Frame(nb, padding=8)
        nb.add(mine, text="My profile")
        self._profile(mine)

    def _profile(self, parent):
        self.section(parent, "My profile")
        self.profile = w.Table(parent, height=2)
        self.profile.pack(fill="x")
        self.section(parent, "My upcoming shifts")
        self.my_shifts = w.Table(parent, height=8)
        self.my_shifts.pack(fill="both", expand=True)
        bar = self.toolbar(parent)
        ttk.Button(bar, text="Change my password", command=self.change_password).pack(side="left")

    def refresh(self):
        uid = [self.user["StaffID"]]
        self.profile.load(db.query(
            "SELECT s.FirstName, s.LastName, s.Role, d.Name AS Department, s.Phone, s.Email, s.HireDate, "
            "       m.FirstName AS Supervisor, m.LastName AS SupervisorLastName "
            "FROM STAFF s JOIN DEPARTMENT d ON s.DepartmentID = d.DepartmentID "
            "LEFT JOIN STAFF m ON s.SupervisorID = m.StaffID WHERE s.StaffID = ?", uid))
        self.my_shifts.load(db.query(
            "SELECT ShiftDate, StartTime, EndTime FROM STAFF_SHIFT WHERE StaffID = ? AND ShiftDate >= ? "
            "ORDER BY ShiftDate, StartTime", uid + [w.today()]))
        if not self.manager:
            return
        sql = ("SELECT s.StaffID, s.FirstName, s.LastName, s.Role, d.Name AS Department, "
               "       m.FirstName AS Supervisor, s.Phone, s.Email, s.HireDate, s.Salary "
               "FROM STAFF s JOIN DEPARTMENT d ON s.DepartmentID = d.DepartmentID "
               "LEFT JOIN STAFF m ON s.SupervisorID = m.StaffID WHERE 1 = 1 ")
        params = []
        if self.dept.get() != "All":
            sql += "AND d.Name = ? "
            params.append(self.dept.get())
        if self.role.get() != "All":
            sql += "AND s.Role = ? "
            params.append(self.role.get())
        self.staff.load(db.query(sql + "ORDER BY s.LastName", params))
        try:
            start = dt.date.fromisoformat(self.week.get().strip())
        except ValueError:
            start = w.today()
        self.shifts.load(db.query(
            "SELECT ss.ShiftID, ss.ShiftDate, ss.StartTime, ss.EndTime, st.FirstName, st.LastName, st.Role "
            "FROM STAFF_SHIFT ss JOIN STAFF st ON ss.StaffID = st.StaffID "
            "WHERE ss.ShiftDate BETWEEN ? AND ? ORDER BY ss.ShiftDate, ss.StartTime",
            [start, start + dt.timedelta(days=6)]))
        self.workload.load(db.query(
            "SELECT st.StaffID, st.FirstName, st.LastName, COUNT(DISTINCT ca.AnimalID) AS AnimalsCaredFor "
            "FROM STAFF st LEFT JOIN CARE_ASSIGNMENT ca ON ca.StaffID = st.StaffID AND ca.EndDate IS NULL "
            "WHERE st.Role = 'Keeper' GROUP BY st.StaffID, st.FirstName, st.LastName ORDER BY AnimalsCaredFor DESC"))
        self.unassigned.load(db.query(
            "SELECT a.AnimalID, a.Name FROM ANIMAL a WHERE a.HealthStatus <> 'Deceased' AND NOT EXISTS "
            "(SELECT 1 FROM CARE_ASSIGNMENT ca WHERE ca.AnimalID = a.AnimalID AND ca.EndDate IS NULL)"))

    def _staff_options(self):
        return w.opts(db.query("SELECT StaffID, FirstName, LastName, Role FROM STAFF ORDER BY FirstName"),
                      "StaffID", lambda r: f"{r['FirstName']} {r['LastName']} ({r['Role']})")

    def add_staff(self):
        depts = w.opts(db.query("SELECT DepartmentID, Name FROM DEPARTMENT ORDER BY Name"), "DepartmentID", "Name")
        v = w.ask_form(self, "Add employee (initial password: 1234)", [
            {"name": "First", "label": "First name", "type": "text", "required": True},
            {"name": "Last", "label": "Last name", "type": "text", "required": True},
            {"name": "Role", "label": "Role", "type": "choice", "options": ROLES, "required": True},
            {"name": "Dept", "label": "Department", "type": "choice", "options": depts, "required": True},
            {"name": "Sup", "label": "Supervisor", "type": "choice", "options": self._staff_options()},
            {"name": "Email", "label": "E-mail", "type": "text", "required": True},
            {"name": "Phone", "label": "Phone", "type": "text"},
            {"name": "Hired", "label": "Hire date", "type": "date", "default": w.today(), "required": True},
            {"name": "Salary", "label": "Salary", "type": "float", "default": 30000, "min": 0}])
        if v:
            self.run(lambda: db.insert("STAFF", {
                "DepartmentID": v["Dept"], "SupervisorID": v["Sup"], "FirstName": v["First"],
                "LastName": v["Last"], "Role": v["Role"], "Phone": v["Phone"], "Email": v["Email"],
                "HireDate": v["Hired"], "Salary": v["Salary"], "PasswordHash": auth.hash_password("1234")},
                "StaffID"), "Employee added.", ["Manager"])

    def edit_staff(self):
        row = self.staff.selected()
        if row is None:
            w.error(self, "Select an employee first.")
            return
        v = w.ask_form(self, f"Update {row['FirstName']} {row['LastName']}", [
            {"name": "Salary", "label": "Salary", "type": "float", "default": row["Salary"], "min": 0},
            {"name": "Role", "label": "Role", "type": "choice", "options": ROLES, "default": row["Role"],
             "required": True}])
        if v:
            self.run(lambda: db.execute("UPDATE STAFF SET Salary = ?, Role = ? WHERE StaffID = ?",
                                        [v["Salary"], v["Role"], int(row["StaffID"])]),
                     "Employee updated.", ["Manager"])

    def add_shift(self):
        v = w.ask_form(self, "Add shift", [
            {"name": "Who", "label": "Employee", "type": "choice", "options": self._staff_options(), "required": True},
            {"name": "Day", "label": "Date", "type": "date", "default": w.today(), "required": True},
            {"name": "Start", "label": "Start", "type": "time", "default": dt.time(8, 0), "required": True},
            {"name": "End", "label": "End", "type": "time", "default": dt.time(16, 0), "required": True}])
        if not v:
            return
        if v["End"] <= v["Start"]:
            w.error(self, "End time must be after start time.")
            return
        self.run(lambda: db.insert("STAFF_SHIFT", {
            "StaffID": v["Who"], "ShiftDate": v["Day"], "StartTime": v["Start"], "EndTime": v["End"]},
            "ShiftID"), "Shift added.", ["Manager"])

    def change_password(self):
        v = w.ask_form(self, "Change my password", [
            {"name": "New", "label": "New password", "type": "password", "required": True},
            {"name": "Again", "label": "Repeat password", "type": "password", "required": True}])
        if not v:
            return
        if v["New"] != v["Again"] or len(v["New"]) < 4:
            w.error(self, "Passwords must match and have at least 4 characters.")
            return
        self.run(lambda: db.execute("UPDATE STAFF SET PasswordHash = ? WHERE StaffID = ?",
                                    [auth.hash_password(v["New"]), self.user["StaffID"]]), "Password changed.")
