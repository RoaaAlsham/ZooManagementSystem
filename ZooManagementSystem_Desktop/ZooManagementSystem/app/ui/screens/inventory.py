"""Food Inventory: stock, expiry, deliveries, food types and suppliers."""
import datetime as dt
from tkinter import ttk

import auth
import db
from ui import widgets as w

CATEGORIES = {c: c for c in ["Meat", "Fish", "Fruit", "Vegetable", "Grain", "Insect", "Supplement"]}


class InventoryScreen(w.Screen):
    def build(self):
        self.manager = auth.has_role(self.user, "Manager")
        nb = ttk.Notebook(self)
        nb.pack(fill="both", expand=True)

        stock = ttk.Frame(nb, padding=8)
        nb.add(stock, text="Stock")
        self.section(stock, "Estimated stock (purchased − consumed)")
        self.stock = w.Table(stock, height=9)
        self.stock.pack(fill="both", expand=True)
        self.section(stock, "Expiring in the next 14 days")
        self.expiring = w.Table(stock, height=5)
        self.expiring.pack(fill="x")
        if self.manager:
            bar = self.toolbar(stock)
            ttk.Button(bar, text="＋ Add food type", command=self.add_food).pack(side="left")

        deliveries = ttk.Frame(nb, padding=8)
        nb.add(deliveries, text="Deliveries")
        if self.manager:
            self.deliveries = w.Table(deliveries, height=14)
            self.deliveries.pack(fill="both", expand=True)
            bar = self.toolbar(deliveries)
            ttk.Button(bar, text="＋ Record delivery", style="Accent.TButton", command=self.add_delivery).pack(side="left")
        else:
            ttk.Label(deliveries, text="Only managers can see purchase prices.", style="Muted.TLabel").pack(anchor="w")

        suppliers = ttk.Frame(nb, padding=8)
        nb.add(suppliers, text="Suppliers")
        self.suppliers = w.Table(suppliers, height=14)
        self.suppliers.pack(fill="both", expand=True)
        if self.manager:
            bar = self.toolbar(suppliers)
            ttk.Button(bar, text="＋ Add supplier", style="Accent.TButton", command=self.add_supplier).pack(side="left")
            ttk.Button(bar, text="Update selected supplier", command=self.edit_supplier).pack(side="left", padx=6)

    def refresh(self):
        t = w.today()
        self.stock.load(db.query(
            "SELECT ft.FoodID, ft.Name AS Food, ft.Category, ft.Unit, "
            "       COALESCE(p.Purchased, 0) AS Purchased, COALESCE(c.Consumed, 0) AS Consumed, "
            "       COALESCE(p.Purchased, 0) - COALESCE(c.Consumed, 0) AS EstimatedStock "
            "FROM FOOD_TYPE ft "
            "LEFT JOIN (SELECT FoodID, SUM(Quantity) AS Purchased FROM FOOD_STOCK GROUP BY FoodID) p "
            "       ON p.FoodID = ft.FoodID "
            "LEFT JOIN (SELECT fp.FoodID, SUM(fl.QuantityGiven) AS Consumed "
            "           FROM FEEDING_LOG fl JOIN FEEDING_PLAN fp ON fl.PlanID = fp.PlanID "
            "           GROUP BY fp.FoodID) c ON c.FoodID = ft.FoodID "
            "ORDER BY EstimatedStock"))
        self.expiring.load(db.query(
            "SELECT ft.Name AS Food, fs.Quantity, ft.Unit, fs.ExpiryDate, sp.Name AS Supplier "
            "FROM FOOD_STOCK fs JOIN FOOD_TYPE ft ON fs.FoodID = ft.FoodID "
            "JOIN SUPPLIER sp ON fs.SupplierID = sp.SupplierID "
            "WHERE fs.ExpiryDate BETWEEN ? AND ? ORDER BY fs.ExpiryDate", [t, t + dt.timedelta(days=14)]))
        if self.manager:
            self.deliveries.load(db.query(
                "SELECT fs.StockID, fs.PurchaseDate, ft.Name AS Food, fs.Quantity, ft.Unit, fs.UnitPrice, "
                "       fs.Quantity * fs.UnitPrice AS Total, fs.ExpiryDate, sp.Name AS Supplier "
                "FROM FOOD_STOCK fs JOIN FOOD_TYPE ft ON fs.FoodID = ft.FoodID "
                "JOIN SUPPLIER sp ON fs.SupplierID = sp.SupplierID ORDER BY fs.PurchaseDate DESC"))
            self.suppliers.load(db.query(
                "SELECT sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone, sp.Address, "
                "       COALESCE(SUM(fs.Quantity * fs.UnitPrice), 0) AS TotalSpent, MAX(fs.PurchaseDate) AS LastDelivery "
                "FROM SUPPLIER sp LEFT JOIN FOOD_STOCK fs ON fs.SupplierID = sp.SupplierID "
                "GROUP BY sp.SupplierID, sp.Name, sp.ContactPerson, sp.Phone, sp.Address ORDER BY TotalSpent DESC"))
        else:
            self.suppliers.load(db.query("SELECT Name, ContactPerson, Phone FROM SUPPLIER ORDER BY Name"))

    def add_food(self):
        v = w.ask_form(self, "Add food type", [
            {"name": "Name", "label": "Name", "type": "text", "required": True},
            {"name": "Cat", "label": "Category", "type": "choice", "options": CATEGORIES, "required": True},
            {"name": "Unit", "label": "Unit", "type": "text", "default": "kg", "required": True},
            {"name": "Cal", "label": "Calories per unit", "type": "float", "default": 100, "min": 0}])
        if v:
            self.run(lambda: db.insert("FOOD_TYPE", {
                "Name": v["Name"], "Category": v["Cat"], "Unit": v["Unit"], "CaloriesPerUnit": v["Cal"]},
                "FoodID"), "Food type added.", ["Manager"])

    def add_delivery(self):
        t = w.today()
        v = w.ask_form(self, "Record a delivery", [
            {"name": "Food", "label": "Food", "type": "choice", "required": True,
             "options": w.opts(db.query("SELECT FoodID, Name FROM FOOD_TYPE ORDER BY Name"), "FoodID", "Name")},
            {"name": "Sup", "label": "Supplier", "type": "choice", "required": True,
             "options": w.opts(db.query("SELECT SupplierID, Name FROM SUPPLIER ORDER BY Name"), "SupplierID", "Name")},
            {"name": "Qty", "label": "Quantity", "type": "float", "default": 10, "required": True, "min": 0.1},
            {"name": "Price", "label": "Unit price", "type": "float", "default": 10, "required": True, "min": 0},
            {"name": "Bought", "label": "Purchase date", "type": "date", "default": t, "required": True},
            {"name": "Expiry", "label": "Expiry date", "type": "date", "default": t + dt.timedelta(days=30)}],
            submit_text="Save delivery")
        if not v:
            return
        if v["Expiry"] and v["Expiry"] <= v["Bought"]:
            w.error(self, "Expiry date must be after the purchase date.")
            return
        self.run(lambda: db.insert("FOOD_STOCK", {
            "FoodID": v["Food"], "SupplierID": v["Sup"], "Quantity": v["Qty"], "UnitPrice": v["Price"],
            "PurchaseDate": v["Bought"], "ExpiryDate": v["Expiry"]}, "StockID"), "Delivery saved.", ["Manager"])

    def add_supplier(self):
        v = w.ask_form(self, "Add supplier", [
            {"name": "Name", "label": "Company name", "type": "text", "required": True},
            {"name": "Contact", "label": "Contact person", "type": "text"},
            {"name": "Phone", "label": "Phone", "type": "text"},
            {"name": "Address", "label": "Address", "type": "text"}])
        if v:
            self.run(lambda: db.insert("SUPPLIER", {
                "Name": v["Name"], "ContactPerson": v["Contact"], "Phone": v["Phone"], "Address": v["Address"]},
                "SupplierID"), "Supplier added.", ["Manager"])

    def edit_supplier(self):
        row = self.suppliers.selected()
        if row is None:
            w.error(self, "Select a supplier first.")
            return
        v = w.ask_form(self, f"Update supplier — {row['Name']}", [
            {"name": "Contact", "label": "Contact person", "type": "text", "default": row["ContactPerson"]},
            {"name": "Phone", "label": "Phone", "type": "text", "default": row["Phone"]},
            {"name": "Address", "label": "Address", "type": "text", "default": row["Address"]}])
        if v:
            self.run(lambda: db.execute(
                "UPDATE SUPPLIER SET ContactPerson = ?, Phone = ?, Address = ? WHERE SupplierID = ?",
                [v["Contact"], v["Phone"], v["Address"], int(row["SupplierID"])]), "Supplier updated.", ["Manager"])
