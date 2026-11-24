"""Ticketing: point of sale for cashiers, sales reports for managers."""
import datetime as dt
import tkinter as tk
from tkinter import ttk

import auth
import db
from ui import widgets as w


class TicketingScreen(w.Screen):
    def build(self):
        self.cashier = auth.has_role(self.user, "Cashier")
        if self.cashier:
            box = ttk.LabelFrame(self, text="Sell tickets", padding=12)
            box.pack(fill="x", pady=(0, 10))
            self.types = db.query("SELECT TicketTypeID, Name, Price FROM TICKET_TYPE ORDER BY Price")
            self.labels = [f"{r['Name']} — {w.fmt(r['Price'])} ₺" for r in self.types]
            self.ttype = tk.StringVar(value=self.labels[0] if self.labels else "")
            self.qty = tk.StringVar(value="1")
            self.visit = tk.StringVar(value=w.today().isoformat())
            ttk.Label(box, text="Ticket type").grid(row=0, column=0, sticky="w")
            combo = ttk.Combobox(box, textvariable=self.ttype, values=self.labels, state="readonly", width=26)
            combo.grid(row=1, column=0, padx=(0, 12))
            ttk.Label(box, text="Quantity").grid(row=0, column=1, sticky="w")
            ttk.Spinbox(box, from_=1, to=50, textvariable=self.qty, width=6).grid(row=1, column=1, padx=(0, 12))
            ttk.Label(box, text="Visit date (YYYY-MM-DD)").grid(row=0, column=2, sticky="w")
            ttk.Entry(box, textvariable=self.visit, width=14).grid(row=1, column=2, padx=(0, 12))
            self.total = ttk.Label(box, text="", style="Sub.TLabel")
            self.total.grid(row=1, column=3, padx=12)
            ttk.Button(box, text="Sell", style="Accent.TButton", command=self.sell).grid(row=1, column=4)
            for var in (self.ttype, self.qty):
                var.trace_add("write", lambda *_: self.update_total())
            self.update_total()

        metrics = ttk.Frame(self)
        metrics.pack(fill="x")
        self.m_tickets = self.metric(metrics, "Tickets sold today")
        self.m_revenue = self.metric(metrics, "Revenue today")
        self.section(self, "Today's sales")
        self.sales = w.Table(self, height=8)
        self.sales.pack(fill="both", expand=True)
        if auth.has_role(self.user, "Manager"):
            row = ttk.Frame(self)
            row.pack(fill="both", expand=True)
            left, right = ttk.Frame(row), ttk.Frame(row)
            left.pack(side="left", fill="both", expand=True, padx=(0, 8))
            right.pack(side="left", fill="both", expand=True)
            self.section(left, "Daily visitors and revenue")
            self.daily = w.Table(left, height=6)
            self.daily.pack(fill="both", expand=True)
            self.section(right, "Revenue by ticket type")
            self.by_type = w.Table(right, height=6)
            self.by_type.pack(fill="both", expand=True)

    def _selected_type(self):
        if self.ttype.get() not in self.labels:
            return None
        return self.types[self.labels.index(self.ttype.get())]

    def update_total(self):
        t = self._selected_type()
        try:
            qty = int(self.qty.get())
        except ValueError:
            qty = 0
        total = float(t["Price"]) * qty if t else 0
        self.total.configure(text=f"Total: {total:.2f} ₺")

    def sell(self):
        t = self._selected_type()
        try:
            qty = int(self.qty.get())
            visit = dt.date.fromisoformat(self.visit.get().strip())
        except ValueError:
            w.error(self, "Check the quantity and the visit date (YYYY-MM-DD).")
            return
        if t is None or qty < 1:
            w.error(self, "Choose a ticket type and a quantity of at least 1.")
            return
        if visit < w.today():
            w.error(self, "The visit date cannot be in the past.")
            return
        price = float(db.scalar("SELECT Price FROM TICKET_TYPE WHERE TicketTypeID = ?", [int(t["TicketTypeID"])]))
        total = round(price * qty, 2)
        if self.run(lambda: db.insert("TICKET", {
                "TicketTypeID": int(t["TicketTypeID"]), "SoldByStaffID": self.user["StaffID"], "VisitDate": visit,
                "PurchasedAt": dt.datetime.now().replace(microsecond=0), "Quantity": qty, "TotalPrice": total},
                "TicketID"), f"Sold {qty} ticket(s) — total {total:.2f} ₺", ["Cashier"]):
            self.qty.set("1")

    def refresh(self):
        rows = db.query(
            "SELECT TicketID, TicketType, Quantity, TotalPrice, VisitDate, PurchasedAt, SoldBy "
            "FROM dbo.vw_TicketSalesToday "
            "ORDER BY PurchasedAt DESC")
        self.sales.load(rows)
        self.m_tickets.configure(text=str(sum(int(r["Quantity"]) for r in rows)))
        self.m_revenue.configure(text=f"{sum(float(r['TotalPrice']) for r in rows):.2f} ₺")
        if auth.has_role(self.user, "Manager"):
            self.daily.load(db.query(
                "SELECT t.VisitDate, SUM(t.Quantity) AS Visitors, SUM(t.TotalPrice) AS Revenue "
                "FROM TICKET t GROUP BY t.VisitDate ORDER BY t.VisitDate DESC"))
            self.by_type.load(db.query(
                "SELECT tt.Name AS TicketType, COUNT(t.TicketID) AS Sales, COALESCE(SUM(t.Quantity), 0) AS Tickets, "
                "       COALESCE(SUM(t.TotalPrice), 0) AS Revenue "
                "FROM TICKET_TYPE tt LEFT JOIN TICKET t ON t.TicketTypeID = tt.TicketTypeID "
                "GROUP BY tt.Name ORDER BY Revenue DESC"))
