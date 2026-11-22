"""Reusable Tkinter building blocks: theme, data table, form dialog, screen base."""
import datetime as dt
import decimal
import tkinter as tk
from tkinter import messagebox, ttk

import auth
import db

# ---------------------------------------------------------------- theme
COLORS = {
    "bg": "#f4f6f3",
    "panel": "#ffffff",
    "sidebar": "#1f3b2c",
    "sidebar_fg": "#e8f0ea",
    "sidebar_active": "#2e6b47",
    "accent": "#2e7d32",
    "accent_dark": "#1b5e20",
    "text": "#1c2430",
    "muted": "#5d6577",
    "danger": "#c62828",
    "line": "#d9ded8",
}
FONT = ("Segoe UI", 10)
FONT_BOLD = ("Segoe UI", 10, "bold")
FONT_TITLE = ("Segoe UI", 18, "bold")
FONT_SUB = ("Segoe UI", 12, "bold")


def apply_theme(root):
    style = ttk.Style(root)
    style.theme_use("clam")
    c = COLORS
    root.configure(bg=c["bg"])
    style.configure(".", font=FONT, background=c["bg"], foreground=c["text"])
    style.configure("TFrame", background=c["bg"])
    style.configure("Panel.TFrame", background=c["panel"], relief="solid", borderwidth=1)
    style.configure("TLabel", background=c["bg"], foreground=c["text"])
    style.configure("Panel.TLabel", background=c["panel"])
    style.configure("Title.TLabel", font=FONT_TITLE, background=c["bg"])
    style.configure("Sub.TLabel", font=FONT_SUB, background=c["bg"])
    style.configure("Muted.TLabel", foreground=c["muted"], background=c["bg"])
    style.configure("Metric.TLabel", font=("Segoe UI", 16, "bold"), background=c["panel"])
    style.configure("MetricCap.TLabel", foreground=c["muted"], background=c["panel"])
    style.configure("TButton", padding=(10, 5))
    style.configure("Accent.TButton", background=c["accent"], foreground="white", padding=(12, 6),
                    font=FONT_BOLD)
    style.map("Accent.TButton", background=[("active", c["accent_dark"]), ("disabled", "#9bb59d")])
    style.configure("Danger.TButton", background=c["danger"], foreground="white", padding=(12, 6))
    style.map("Danger.TButton", background=[("active", "#8e1c1c")])
    style.configure("Treeview", rowheight=26, fieldbackground=c["panel"], background=c["panel"])
    style.configure("Treeview.Heading", font=FONT_BOLD, background="#e4ebe3")
    style.map("Treeview", background=[("selected", "#c8e6c9")], foreground=[("selected", c["text"])])
    style.configure("TNotebook", background=c["bg"])
    style.configure("TNotebook.Tab", padding=(14, 6), font=FONT)
    style.map("TNotebook.Tab", background=[("selected", c["panel"])])
    style.configure("TLabelframe", background=c["bg"])
    style.configure("TLabelframe.Label", font=FONT_BOLD, background=c["bg"])
    style.configure("green.Horizontal.TProgressbar", background=c["accent"])


# ---------------------------------------------------------------- formatting
def fmt(value):
    if value is None:
        return ""
    if isinstance(value, dt.datetime):
        return value.strftime("%Y-%m-%d %H:%M")
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, dt.time):
        return value.strftime("%H:%M")
    if isinstance(value, (float, decimal.Decimal)):
        f = float(value)
        return str(int(f)) if f == int(f) else f"{f:.2f}"
    text = str(value)
    if len(text) >= 16 and text[4] == "-" and text[10] in " T" and text[13] == ":":
        return text[:16].replace("T", " ")
    return text


def opts(rows, id_col, label):
    """Turn query rows into {id: label} for choice fields."""
    if callable(label):
        return {int(r[id_col]): label(r) for r in rows}
    return {int(r[id_col]): str(r[label]) for r in rows}


# ---------------------------------------------------------------- table
class Table(ttk.Frame):
    """A Treeview with scrollbars that shows query rows."""

    def __init__(self, parent, height=10, on_double_click=None):
        super().__init__(parent)
        self.tree = ttk.Treeview(self, show="headings", height=height, selectmode="browse")
        ys = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        xs = ttk.Scrollbar(self, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        ys.grid(row=0, column=1, sticky="ns")
        xs.grid(row=1, column=0, sticky="ew")
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
        self.rows = []
        self.tree.tag_configure("odd", background="#f7faf6")
        if on_double_click:
            self.tree.bind("<Double-1>", lambda _e: on_double_click())

    def load(self, rows, columns=None):
        self.rows = list(rows)
        cols = columns or (list(self.rows[0].keys()) if self.rows else [])
        self.tree.delete(*self.tree.get_children())
        self.tree["columns"] = cols
        for c in cols:
            sample = [len(fmt(r.get(c))) for r in self.rows[:50]] + [len(c)]
            width = min(max(sample) * 8 + 20, 320)
            self.tree.heading(c, text=c)
            self.tree.column(c, width=width, minwidth=60, stretch=True,
                             anchor="e" if self._numeric(c) else "w")
        for i, r in enumerate(self.rows):
            self.tree.insert("", "end", iid=str(i), values=[fmt(r.get(c)) for c in cols],
                             tags=("odd",) if i % 2 else ())

    def _numeric(self, col):
        vals = [r.get(col) for r in self.rows if r.get(col) is not None]
        return bool(vals) and all(isinstance(v, (int, float, decimal.Decimal)) for v in vals)

    def selected(self):
        sel = self.tree.selection()
        return self.rows[int(sel[0])] if sel else None


# ---------------------------------------------------------------- form dialog
class FormDialog(tk.Toplevel):
    """Modal form. fields = list of dicts:
       {name, label, type, default, options, required, none_label}
       type: text | password | int | float | date | time | choice | check | multiline
    """

    def __init__(self, parent, title, fields, submit_text="Save"):
        super().__init__(parent)
        self.title(title)
        self.configure(bg=COLORS["bg"])
        self.transient(parent.winfo_toplevel())
        self.resizable(False, False)
        self.result = None
        self.fields = fields
        self.vars = {}
        self.choice_keys = {}

        body = ttk.Frame(self, padding=18)
        body.pack(fill="both", expand=True)
        ttk.Label(body, text=title, style="Sub.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 10))
        for i, f in enumerate(fields, start=1):
            self._add_field(body, i, f)
        btns = ttk.Frame(body)
        btns.grid(row=len(fields) + 1, column=0, columnspan=2, sticky="e", pady=(14, 0))
        ttk.Button(btns, text="Cancel", command=self.destroy).pack(side="right", padx=(6, 0))
        ttk.Button(btns, text=submit_text, style="Accent.TButton", command=self._submit).pack(side="right")
        self.bind("<Return>", lambda _e: self._submit())
        self.bind("<Escape>", lambda _e: self.destroy())
        self.update_idletasks()
        px, py = parent.winfo_rootx(), parent.winfo_rooty()
        self.geometry(f"+{px + 80}+{py + 60}")
        self.grab_set()

    def _add_field(self, body, row, f):
        label = f["label"] + (" *" if f.get("required") else "")
        if f["type"] == "info":
            ttk.Label(body, text=f["label"], style="Muted.TLabel", wraplength=420).grid(
                row=row, column=0, columnspan=2, sticky="w", pady=4)
            return
        ttk.Label(body, text=label).grid(row=row, column=0, sticky="w", padx=(0, 12), pady=4)
        t = f["type"]
        default = f.get("default")
        if t == "check":
            var = tk.BooleanVar(value=bool(default))
            ttk.Checkbutton(body, variable=var).grid(row=row, column=1, sticky="w")
        elif t == "choice":
            options = f.get("options", {})
            keys = list(options.keys())
            labels = [options[k] for k in keys]
            if not f.get("required"):
                keys = [None] + keys
                labels = [f.get("none_label", "— none —")] + labels
            self.choice_keys[f["name"]] = (keys, labels)
            var = tk.StringVar()
            combo = ttk.Combobox(body, textvariable=var, values=labels, state="readonly", width=38)
            combo.grid(row=row, column=1, sticky="w")
            if default in keys:
                var.set(labels[keys.index(default)])
            elif labels:
                var.set(labels[0])
        else:
            var = tk.StringVar(value="" if default is None else fmt(default))
            ttk.Entry(body, textvariable=var, width=40, show="•" if t == "password" else "").grid(
                row=row, column=1, sticky="w")
            hint = {"date": "YYYY-MM-DD", "time": "HH:MM"}.get(t)
            if hint:
                ttk.Label(body, text=hint, style="Muted.TLabel").grid(row=row, column=2, sticky="w", padx=6)
        self.vars[f["name"]] = var

    def _value(self, f):
        raw = self.vars[f["name"]].get()
        t = f["type"]
        if t == "check":
            return bool(raw)
        if t == "choice":
            keys, labels = self.choice_keys[f["name"]]
            return keys[labels.index(raw)] if raw in labels else None
        raw = raw.strip()
        if raw == "":
            if f.get("required"):
                raise ValueError(f"'{f['label']}' is required.")
            return None
        try:
            if t == "int":
                return int(raw)
            if t == "float":
                return float(raw.replace(",", "."))
            if t == "date":
                return dt.date.fromisoformat(raw)
            if t == "time":
                h, m = raw.split(":")[:2]
                return dt.time(int(h), int(m))
        except ValueError:
            raise ValueError(f"'{f['label']}' has a wrong format.") from None
        return raw

    def _submit(self):
        try:
            values = {f["name"]: self._value(f) for f in self.fields if f["type"] != "info"}
            for f in self.fields:
                if f.get("required") and f["type"] == "choice" and values.get(f["name"]) is None:
                    raise ValueError(f"'{f['label']}' is required.")
                mn = f.get("min")
                v = values.get(f["name"])
                if mn is not None and v is not None and v < mn:
                    raise ValueError(f"'{f['label']}' must be at least {fmt(mn)}.")
        except ValueError as exc:
            messagebox.showerror("Check the form", str(exc), parent=self)
            return
        self.result = values
        self.destroy()


def ask_form(parent, title, fields, submit_text="Save"):
    """Show a modal form and return the values (dict) or None if cancelled."""
    dlg = FormDialog(parent, title, fields, submit_text)
    parent.wait_window(dlg)
    return dlg.result


def info(parent, message):
    messagebox.showinfo("Zoo Management System", message, parent=parent)


def error(parent, message):
    messagebox.showerror("Zoo Management System", message, parent=parent)


def confirm(parent, message):
    return messagebox.askyesno("Please confirm", message, parent=parent)


# ---------------------------------------------------------------- screen base
class Screen(ttk.Frame):
    """Base class of every screen. Subclasses implement build() and refresh()."""

    title = ""
    icon = ""

    def __init__(self, parent, user):
        super().__init__(parent, padding=(24, 18))
        self.user = user
        header = ttk.Frame(self)
        header.pack(fill="x")
        ttk.Label(header, text=f"{self.icon}  {self.title}", style="Title.TLabel").pack(side="left")
        ttk.Button(header, text="⟳ Refresh", command=self.safe_refresh).pack(side="right")
        ttk.Separator(self).pack(fill="x", pady=(10, 12))
        self.build()
        self.safe_refresh()

    def build(self):
        pass

    def refresh(self):
        pass

    def safe_refresh(self):
        try:
            self.refresh()
        except Exception as exc:
            error(self, db.friendly_error(exc))

    def run(self, action, success, roles=None):
        """Run a database write with a permission check, then refresh the screen."""
        try:
            if roles:
                auth.require_role(self.user, *roles)
            action()
        except auth.PermissionDenied as exc:
            error(self, str(exc))
            return False
        except Exception as exc:
            error(self, db.friendly_error(exc))
            return False
        info(self, success)
        self.safe_refresh()
        return True

    def section(self, parent, text):
        ttk.Label(parent, text=text, style="Sub.TLabel").pack(anchor="w", pady=(8, 4))

    def toolbar(self, parent):
        bar = ttk.Frame(parent)
        bar.pack(fill="x", pady=(6, 2))
        return bar

    def metric(self, parent, caption):
        box = ttk.Frame(parent, style="Panel.TFrame", padding=(16, 10))
        box.pack(side="left", padx=(0, 10))
        ttk.Label(box, text=caption, style="MetricCap.TLabel").pack(anchor="w")
        value = ttk.Label(box, text="-", style="Metric.TLabel")
        value.pack(anchor="w")
        return value


def today():
    return dt.date.today()
