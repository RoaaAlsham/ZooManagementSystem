"""Run this first:  py check_connection.py

Shows the installed ODBC drivers, connects to ZooDB with the settings in
zoo_settings.ini and prints the number of rows in a few tables.
"""
import pyodbc

import config
import db

print("Installed ODBC drivers:", pyodbc.drivers())
print("Settings file:", config.SETTINGS_FILE)
print("Server:", config.SERVER, "| Database:", config.DATABASE)
try:
    for table in ["ZOO", "STAFF", "ANIMAL", "TICKET"]:
        print(f"  {table:8} rows: {db.scalar(f'SELECT COUNT(*) FROM {table}')}")
    print("\nConnection OK. Start the app with:  py main.py")
except Exception as exc:
    print("\nConnection FAILED:", exc)
    print("Check 'server' in zoo_settings.ini (it must match the Server name in SSMS).")
