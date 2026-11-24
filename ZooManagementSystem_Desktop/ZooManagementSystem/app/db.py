"""Database access layer (Microsoft SQL Server through pyodbc).

All SQL in the application goes through this module:
  * query()       -> SELECT, returns a list of dictionaries (one per row)
  * scalar()      -> SELECT that returns one value
  * execute()     -> one INSERT / UPDATE / DELETE, committed immediately
  * insert()      -> INSERT one row and return its new IDENTITY value
  * transaction() -> several statements that must succeed or fail together
                     (application-level; used for simple helpers)
  * exec_proc()   -> call a stored procedure dbo.usp_...; multi-table business
                     actions run as DATABASE-LEVEL transactions inside them

Every query uses ? placeholders (parameterized queries), never string
concatenation of user input, so SQL injection is not possible.

A SQLite backend (environment variable ZOO_BACKEND=sqlite) exists only for
automated testing; the real application always uses SQL Server.
"""
import datetime as dt
import decimal
import os
import re
from contextlib import contextmanager

import config

BACKEND = os.environ.get("ZOO_BACKEND", "mssql")

_PREFERRED_DRIVERS = [
    "ODBC Driver 18 for SQL Server",
    "ODBC Driver 17 for SQL Server",
    "SQL Server Native Client 11.0",
    "SQL Server",
]


def _pick_driver(pyodbc):
    installed = pyodbc.drivers()
    for name in _PREFERRED_DRIVERS:
        if name in installed:
            return name
    raise RuntimeError(
        "No SQL Server ODBC driver found. Install 'ODBC Driver 18 for SQL Server' "
        "from Microsoft. Installed drivers: " + ", ".join(installed)
    )


def connect():
    if BACKEND == "sqlite":
        import sqlite3

        conn = sqlite3.connect(os.environ.get("ZOO_SQLITE_PATH", "zoo_test.db"))
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    import pyodbc

    driver = config.ODBC_DRIVER or _pick_driver(pyodbc)
    parts = [f"DRIVER={{{driver}}}", f"SERVER={config.SERVER}", f"DATABASE={config.DATABASE}"]
    if config.USERNAME:
        parts += [f"UID={config.USERNAME}", f"PWD={config.PASSWORD}"]
    else:
        parts.append("Trusted_Connection=yes")
    if "ODBC Driver" in driver:
        parts.append("TrustServerCertificate=yes")
    return pyodbc.connect(";".join(parts), autocommit=False, timeout=10)


def _param(value):
    """Convert Python values to what the database driver expects."""
    if isinstance(value, decimal.Decimal):
        return float(value)
    if BACKEND == "sqlite":
        if isinstance(value, dt.datetime):
            return value.strftime("%Y-%m-%d %H:%M:%S")
        if isinstance(value, dt.date):
            return value.isoformat()
        if isinstance(value, dt.time):
            return value.strftime("%H:%M")
    return value


def _params(params):
    return [_param(p) for p in (params or [])]


def query(sql, params=None):
    """Run a SELECT and return a list of dictionaries."""
    conn = connect()
    try:
        cur = conn.cursor()
        cur.execute(sql, _params(params))
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]
    finally:
        conn.close()


def columns_of(sql, params=None):
    """Column names of a SELECT (used to draw empty tables)."""
    conn = connect()
    try:
        cur = conn.cursor()
        cur.execute(sql, _params(params))
        return [c[0] for c in cur.description]
    finally:
        conn.close()


def scalar(sql, params=None):
    rows = query(sql, params)
    if not rows:
        return None
    return next(iter(rows[0].values()))


class Tx:
    """A cursor wrapper used inside transaction()."""

    def __init__(self, conn):
        self.conn = conn
        self.cur = conn.cursor()

    def execute(self, sql, params=None):
        self.cur.execute(sql, _params(params))
        return self.cur.rowcount

    def insert(self, table, data, id_col):
        """INSERT a row and return its new IDENTITY value."""
        cols = ", ".join(data.keys())
        marks = ", ".join("?" for _ in data)
        values = _params(list(data.values()))
        if BACKEND == "sqlite":
            self.cur.execute(f"INSERT INTO {table} ({cols}) VALUES ({marks})", values)
            return self.cur.lastrowid
        self.cur.execute(
            f"INSERT INTO {table} ({cols}) OUTPUT INSERTED.{id_col} VALUES ({marks})", values
        )
        return int(self.cur.fetchone()[0])


@contextmanager
def transaction():
    """All statements inside the block are committed together, or none of them (rollback)."""
    conn = connect()
    try:
        tx = Tx(conn)
        yield tx
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def execute(sql, params=None):
    with transaction() as tx:
        return tx.execute(sql, params)


def insert(table, data, id_col):
    with transaction() as tx:
        return tx.insert(table, data, id_col)


_PROC_NAME = re.compile(r"^usp_[A-Za-z0-9_]+$")


def exec_proc(name, params=None):
    """Call a stored procedure dbo.usp_... with named parameters.

        db.exec_proc("usp_TransferAnimal", {"AnimalID": 3, "ToEnclosureID": 5, "Reason": "Space"})

    The procedure itself runs BEGIN TRANSACTION / COMMIT / ROLLBACK, so the
    commit-or-rollback decision is made INSIDE SQL Server (database-level
    transaction). The connection is in autocommit mode so Python does not
    wrap a second transaction around it.
    Returns the first row the procedure SELECTs (e.g. {"AnimalID": 13}) or None.
    """
    if not _PROC_NAME.match(name):
        raise ValueError("Invalid procedure name: " + name)
    params = params or {}
    sql = f"EXEC dbo.{name} " + ", ".join(f"@{key} = ?" for key in params)
    conn = connect()
    try:
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute(sql, _params(list(params.values())))
        while cur.description is None and cur.nextset():
            pass
        if cur.description is None:
            return None
        row = cur.fetchone()
        if row is None:
            return None
        return dict(zip([c[0] for c in cur.description], row))
    finally:
        conn.close()


# ---------------------------------------------------------------- helpers
def to_date(value):
    if value is None:
        return None
    if isinstance(value, dt.datetime):
        return value.date()
    if isinstance(value, dt.date):
        return value
    return dt.date.fromisoformat(str(value)[:10])


def to_time(value):
    if value is None:
        return None
    if isinstance(value, dt.time):
        return value
    parts = str(value).split(":")
    return dt.time(int(parts[0]), int(parts[1]))


def friendly_error(exc):
    """Translate database errors into messages a user understands."""
    msg = str(exc)
    # Business-rule errors raised by our procedures with THROW 500xx
    rule = re.search(r"\[SQL Server\]([^\[]+?)\s*\(50\d{3}\)", msg)
    if rule:
        return rule.group(1).strip()
    low = msg.lower()
    if "unique" in low or "duplicate key" in low:
        return "This record already exists (a value that must be unique is repeated)."
    if "check constraint" in low:
        return "A value is not allowed by the rules of the database (CHECK constraint)."
    if "foreign key" in low or "reference constraint" in low:
        return "This record is linked to other records, so the operation is not allowed."
    if "cannot insert the value null" in low or "not null" in low:
        return "A required field is empty."
    if "login failed" in low or "server does not exist" in low or "08001" in low:
        return ("Cannot connect to SQL Server. Check that SQL Server is running and that "
                "SERVER in config.py is correct.\n\n" + msg)
    return "Database error: " + msg
