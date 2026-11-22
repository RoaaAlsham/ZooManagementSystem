"""Connection settings for the Zoo Management System.

Settings are read from zoo_settings.ini, which sits next to main.py (or next to
ZooManagementSystem.exe). Change SERVER there if your SQL Server instance has
another name - no need to touch the code or rebuild the .exe.

Default ".\\SQLEXPRESS" means "SQL Server Express on this computer", so the
app works on any PC where ZooDB was created with ZooDB_FULL.sql.
"""
import configparser
import os
import sys

if getattr(sys, "frozen", False):  # running as ZooManagementSystem.exe
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SETTINGS_FILE = os.path.join(BASE_DIR, "zoo_settings.ini")

_cfg = configparser.ConfigParser()
_cfg.read(SETTINGS_FILE, encoding="utf-8")
_db = _cfg["database"] if _cfg.has_section("database") else {}


def _get(key, env, default):
    return os.environ.get(env) or _db.get(key, "") or default


# SQL Server instance (see the "Server name" in SSMS)
SERVER = _get("server", "ZOO_SERVER", r".\SQLEXPRESS")
DATABASE = _get("database", "ZOO_DATABASE", "ZooDB")

# Empty -> Windows Authentication (same login as SSMS).
# Fill both -> SQL Server Authentication.
USERNAME = _get("username", "ZOO_USER", "")
PASSWORD = _get("password", "ZOO_PASSWORD", "")

# Empty -> pick the best installed ODBC driver automatically.
ODBC_DRIVER = _get("odbc_driver", "ZOO_ODBC_DRIVER", "")
