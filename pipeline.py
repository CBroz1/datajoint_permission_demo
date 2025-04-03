import os
import sys
import traceback
import warnings

import datajoint as dj
from datajoint_utilities.dj_search.lists import drop_schemas
from IPython import get_ipython

warnings.filterwarnings("ignore", category=UserWarning, module="hdmf")

os.environ["SPYGLASS_BASE_DIR"] = "/home/cb/wrk/spyglass/tests/_data"
os.environ["DJ_SUPPORT_FILEPATH_MANAGEMENT"] = "TRUE"

ipython = get_ipython()
if ipython:
    orig_stdout = sys.stdout
    sys.stdout = open(os.devnull, "w")
    ipython.run_line_magic("xmode", "Minimal")
    sys.stdout = orig_stdout


PORT = 6
USER = sys.argv[1].lower()
ACTION = sys.argv[2].lower()

dj.config.update(
    {
        "database.host": "localhost",
        "database.user": USER,
        "database.password": "tutorial",
        "database.port": int(f"330{PORT}"),
        "safemode": False,
        "loglevel": "CRITICAL",
        "stores": {
            "analysis": {
                "location": "/home/cb/wrk/spyglass/tests/_data/analysis/",
                "protocol": "file",
                "stage": "/home/cb/wrk/spyglass/tests/_data/analysis/",
            },
            "raw": {
                "location": "/home/cb/wrk/spyglass/tests/_data/raw",
                "protocol": "file",
                "stage": "/home/cb/wrk/spyglass/tests/_data/raw",
            },
        },
        "custom": {
            "debug_mode": "true",
            "test_mode": "true",
            "spyglass_dirs": {
                "base": "/home/cb/wrk/spyglass/tests/_data",
            },
        },
    }
)
dj.conn()

if not dj.conn().is_connected():
    raise RuntimeError("Failed to connect to the database.")
    sys.exit(1)


print(f"RUNNING: {USER}, {ACTION}")

u1 = {"lab_member_name": "user1"}
u2 = {"lab_member_name": "user2"}
kwargs = {"skip_duplicates": True}


def drop_all_schemas(prefix="", dry_run=True, force_drop=True):
    drop_schemas(prefix, dry_run=dry_run, force_drop=force_drop)


if ACTION == "declare":
    drop_all_schemas(prefix="", dry_run=False, force_drop=True)

    from spyglass import *  # noqa: F403
    from spyglass import common as sgc  # noqa: F403
    from spyglass.utils.dj_helper_fn import declare_all_merge_tables

    declare_all_merge_tables()

    sgc.LabMember.insert(
        [
            {**u1, "first_name": "user1", "last_name": "User"},
            {**u2, "first_name": "user2", "last_name": "User"},
        ],
        **kwargs,
    )
    sgc.LabMember.LabMemberInfo.insert(
        [
            {**u2, "datajoint_user_name": "user2", "google_user_name": "user2"},
            {**u2, "datajoint_user_name": "user2", "google_user_name": "user2"},
        ],
        **kwargs,
    )


if ACTION == "insert":
    from spyglass import common as sgc
    from spyglass import data_import as sdi

    nwb_file_names = [f"minirec2023062{i}.nwb" for i in range(6)]
    sdi.insert_sessions(nwb_file_names[2])

    for session in sgc.Session:
        sgc.Session.Experimenter.insert(
            [{**session, **u1}, {**session, **u2}],
            ignore_extra_fields=True,
            **kwargs,
        )


if ACTION == "delete":
    from spyglass import common as sgc

    sgc.Nwbfile.delete()
