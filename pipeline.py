import sys

import datajoint as dj

USER = sys.argv[1].lower()
PORT = sys.argv[2]
ACTION = sys.argv[3].lower()

dj.config.update(
    {
        "database.host": "localhost",
        "database.user": USER,
        "database.password": "tutorial",
        "database.port": int(f"330{PORT}"),
        "safemode": False,
        "loglevel": "CRITICAL",
    }
)
dj.conn()


schema = dj.Schema("test_permissions")


@schema
class One(dj.Manual):
    definition = """
    a   :   int     # key
    ---
    b   :   int     # value
    """


@schema
class Two(dj.Manual):
    definition = """
    c   :   int     # key
    ---
    d   :   int     # value
    """


@schema
class Three(dj.Manual):
    definition = """
    e  :   int     # key
    -> One
    -> Two
    """


@schema
class Sum(dj.Computed):
    definition = """
    -> Three
    ---
    sum : int
    """

    def make(self, key):
        key["sum"] = key["a"] + key["c"]
        self.insert1(key)


@schema
class Four(dj.Manual):
    definition = """
    f   :   int     # key
    ---
    -> Sum
    """


if ACTION == "insert":
    # basic user inserts
    One.insert1({"a": 1, "b": 2}, skip_duplicates=True)
    Two.insert1({"c": 3, "d": 4}, skip_duplicates=True)
    Three.insert1({"e": 5, "a": 1, "c": 3}, skip_duplicates=True)
    Sum.populate()
    sum_key = Sum.fetch("KEY", as_dict=True)[0]
    Four.insert1({"f": 6, **sum_key}, skip_duplicates=True)

    # basic user cannot delete their own data
    (One & {"a": 1}).delete(safemode=False)

import os

os.environ["SPYGLASS_BASE_DIR"] = "/home/cb/wrk/data/"
os.environ["DJ_SUPPORT_FILEPATH_MANAGEMENT"] = "TRUE"

if ACTION == "declare_spy":
    from spyglass import *  # noqa: F403

if ACTION == "insert_spy":
    from spyglass import common as sgc
    from spyglass import data_import as sdi

    nwb_file_names = [f"minirec2023062{i}.nwb" for i in range(6)]
    sdi.insert_sessions(nwb_file_names[2])

    print(f"USER: {USER}")

if ACTION == "delete_spy":
    from spyglass import common as sgc

    sgc.Nwbfile.delete()
