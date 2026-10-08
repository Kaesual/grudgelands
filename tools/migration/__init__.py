"""The world-migration tool behind tools/migrate.py (contract R3-R6).

cli     the command line, check mode, exit codes and output events
world   opening a world from world.mt (SQLite, PostgreSQL), layouts
data    the data API a step works with (characters, auth, mod storage,
        markers, raw connections)
codec   core.serialize / core.deserialize, JSON, item strings
steps/  one file per declared `migrate` version
"""
