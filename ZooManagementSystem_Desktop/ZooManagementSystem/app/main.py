"""Zoo Management System - desktop application (Tkinter + SQL Server).

Run:  py main.py      (or double-click "Start Zoo App.bat")
"""
import tkinter as tk
from tkinter import ttk

import auth
import db
from ui import widgets as w
from ui.screens.admin import AdminScreen
from ui.screens.animals import AnimalsScreen
from ui.screens.feeding import FeedingScreen
from ui.screens.habitats import HabitatsScreen
from ui.screens.inventory import InventoryScreen
from ui.screens.staff import StaffScreen
from ui.screens.ticketing import TicketingScreen
from ui.screens.vet import VetScreen

SCREENS = {
    "Animals": (AnimalsScreen, "🐾"),
    "Habitats & Enclosures": (HabitatsScreen, "🌿"),
    "Feeding Today": (FeedingScreen, "🍖"),
    "Veterinary Center": (VetScreen, "🩺"),
    "Food Inventory": (InventoryScreen, "📦"),
    "Staff": (StaffScreen, "👥"),
    "Ticketing": (TicketingScreen, "🎟"),
    "Admin Settings": (AdminScreen, "⚙"),
}


class LoginFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app, padding=40)
        self.app = app
        card = ttk.Frame(self, style="Panel.TFrame", padding=36)
        card.place(relx=0.5, rely=0.45, anchor="center")
        ttk.Label(card, text="🦁", font=("Segoe UI Emoji", 40), style="Panel.TLabel").pack()
        ttk.Label(card, text="Zoo Management System", font=w.FONT_TITLE, style="Panel.TLabel").pack(pady=(4, 2))
        ttk.Label(card, text="Sign in with your staff e-mail and password",
                  style="Panel.TLabel", foreground=w.COLORS["muted"]).pack(pady=(0, 18))
        ttk.Label(card, text="E-mail", style="Panel.TLabel").pack(anchor="w")
        self.email = tk.StringVar()
        e = ttk.Entry(card, textvariable=self.email, width=36)
        e.pack(pady=(2, 10), ipady=3)
        ttk.Label(card, text="Password", style="Panel.TLabel").pack(anchor="w")
        self.password = tk.StringVar()
        ttk.Entry(card, textvariable=self.password, show="•", width=36).pack(pady=(2, 16), ipady=3)
        ttk.Button(card, text="Sign in", style="Accent.TButton", command=self.submit).pack(fill="x")
        self.message = ttk.Label(card, text="", style="Panel.TLabel", foreground=w.COLORS["danger"])
        self.message.pack(pady=(10, 0))
        ttk.Label(card, text="Demo: manager@zoo.com · keeper1@zoo.com · vet1@zoo.com · "
                             "cashier1@zoo.com  (password 1234)",
                  style="Panel.TLabel", foreground=w.COLORS["muted"], font=("Segoe UI", 8)).pack(pady=(14, 0))
        app.bind("<Return>", lambda _e: self.submit())
        e.focus_set()

    def submit(self):
        try:
            user = auth.login(self.email.get(), self.password.get())
        except Exception as exc:
            w.error(self, db.friendly_error(exc))
            return
        if user is None:
            self.message.configure(text="Wrong e-mail or password.")
            return
        self.app.unbind("<Return>")
        self.app.show_main(user)


class MainFrame(ttk.Frame):
    def __init__(self, app, user):
        super().__init__(app)
        self.app = app
        self.user = user
        self.current = None
        self.buttons = {}

        side = tk.Frame(self, bg=w.COLORS["sidebar"], width=230)
        side.pack(side="left", fill="y")
        side.pack_propagate(False)
        tk.Label(side, text="🦁 Zoo Manager", bg=w.COLORS["sidebar"], fg="white",
                 font=("Segoe UI", 14, "bold")).pack(anchor="w", padx=18, pady=(20, 4))
        tk.Label(side, text=f"{user['FirstName']} {user['LastName']}", bg=w.COLORS["sidebar"],
                 fg=w.COLORS["sidebar_fg"], font=w.FONT_BOLD).pack(anchor="w", padx=18)
        tk.Label(side, text=f"Role: {user['Role']}", bg=w.COLORS["sidebar"],
                 fg="#a9c4b2", font=w.FONT).pack(anchor="w", padx=18, pady=(0, 18))
        for page in auth.allowed_pages(user):
            _cls, icon = SCREENS[page]
            b = tk.Button(side, text=f"  {icon}  {page}", anchor="w", relief="flat", bd=0,
                          bg=w.COLORS["sidebar"], fg=w.COLORS["sidebar_fg"], font=("Segoe UI", 11),
                          activebackground=w.COLORS["sidebar_active"], activeforeground="white",
                          cursor="hand2", command=lambda p=page: self.open(p))
            b.pack(fill="x", padx=8, pady=1, ipady=6)
            self.buttons[page] = b
        tk.Button(side, text="  ⎋  Log out", anchor="w", relief="flat", bd=0, bg=w.COLORS["sidebar"],
                  fg="#ffb4a9", font=("Segoe UI", 11), activebackground=w.COLORS["sidebar_active"],
                  cursor="hand2", command=app.show_login).pack(side="bottom", fill="x", padx=8, pady=14, ipady=6)

        self.content = ttk.Frame(self)
        self.content.pack(side="left", fill="both", expand=True)
        self.open(auth.HOME_PAGE.get(user["Role"], auth.allowed_pages(user)[0]))

    def open(self, page):
        if page not in auth.allowed_pages(self.user):  # access check
            w.error(self, "You do not have access to this screen.")
            return
        for name, b in self.buttons.items():
            b.configure(bg=w.COLORS["sidebar_active"] if name == page else w.COLORS["sidebar"])
        if self.current is not None:
            self.current.destroy()
        cls, icon = SCREENS[page]
        cls.title, cls.icon = page, icon
        self.current = cls(self.content, self.user)
        self.current.pack(fill="both", expand=True)
        self.page = page


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Zoo Management System")
        self.geometry("1360x840")
        self.minsize(1100, 680)
        w.apply_theme(self)
        self.frame = None
        self.show_login()

    def _swap(self, frame):
        if self.frame is not None:
            self.frame.destroy()
        self.frame = frame
        frame.pack(fill="both", expand=True)

    def show_login(self):
        self._swap(LoginFrame(self))

    def show_main(self, user):
        self._swap(MainFrame(self, user))


if __name__ == "__main__":
    App().mainloop()
