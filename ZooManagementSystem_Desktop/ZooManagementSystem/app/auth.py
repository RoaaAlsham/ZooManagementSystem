"""Login and role-based access control."""
import hashlib

import db

ROLES = ["Manager", "Keeper", "Veterinarian", "Cashier", "Maintenance"]

# Which roles can open which screen.
PAGE_ACCESS = {
    "Animals": ["Manager", "Keeper", "Veterinarian"],
    "Habitats & Enclosures": ["Manager", "Keeper", "Veterinarian", "Maintenance"],
    "Feeding Today": ["Manager", "Keeper", "Veterinarian"],
    "Veterinary Center": ["Manager", "Veterinarian"],
    "Food Inventory": ["Manager", "Keeper", "Veterinarian"],
    "Staff": ROLES,
    "Ticketing": ["Manager", "Cashier"],
    "Admin Settings": ["Manager"],
}

HOME_PAGE = {
    "Manager": "Animals",
    "Keeper": "Feeding Today",
    "Veterinarian": "Veterinary Center",
    "Cashier": "Ticketing",
    "Maintenance": "Habitats & Enclosures",
}


def hash_password(password):
    return hashlib.sha256(password.encode("utf-8")).hexdigest().upper()


def login(email, password):
    rows = db.query(
        "SELECT StaffID, FirstName, LastName, Role, DepartmentID, PasswordHash "
        "FROM STAFF WHERE Email = ?",
        [email.strip()],
    )
    if not rows:
        return None
    row = rows[0]
    if (row["PasswordHash"] or "").strip().upper() != hash_password(password):
        return None
    return {
        "StaffID": int(row["StaffID"]),
        "FirstName": row["FirstName"],
        "LastName": row["LastName"],
        "Role": row["Role"],
        "DepartmentID": int(row["DepartmentID"]),
    }


def allowed_pages(user):
    return [page for page, roles in PAGE_ACCESS.items() if user["Role"] in roles]


def has_role(user, *roles):
    return user["Role"] in roles


class PermissionDenied(Exception):
    pass


def require_role(user, *roles):
    """Server-side check before every write."""
    if user["Role"] not in roles:
        raise PermissionDenied("You do not have permission for this action.")
