import os
import sys

import datajoint as dj

os.environ["SPYGLASS_BASE_DIR"] = "/home/cb/wrk/spyglass/tests/_data"
os.environ["DJ_SUPPORT_FILEPATH_MANAGEMENT"] = "TRUE"

PORT = 6
USER = sys.argv[1].lower()
ACTION = sys.argv[2].lower()

print(f"USER: {USER}\nACTION: {ACTION}")

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
            "spyglass_dirs": {
                "base": "/home/cb/wrk/spyglass/tests/_data",
            },
        },
    }
)
dj.conn()


if ACTION == "declare_spy":
    from spyglass import *  # noqa: F403
    from spyglass.common import *  # noqa: F403
    from spyglass.common.common_device import CameraDevice  # noqa: F403
    from spyglass.decoding.v1.dj_decoder_conversion import (
        convert_classes_to_dict,
    )  # noqa: F403
    from spyglass.position.v1.imported_pose import ImportedPose  # noqa: F403
    from spyglass.spikesorting.imported import (
        ImportedSpikeSorting,
    )  # noqa: F403
    from spyglass.utils.dj_helper_fn import declare_all_merge_tables

    declare_all_merge_tables()

if ACTION == "insert_spy":
    from spyglass import common as sgc
    from spyglass import data_import as sdi

    # nwb_file_names = [f"minirec2023062{i}.nwb" for i in range(6)]
    # sdi.insert_sessions(nwb_file_names[2])

    mk = {"lab_member_name": "user1"}
    kwarg = {"skip_duplicates": True}
    sgc.LabMember.insert1(
        {**mk, "first_name": "user1", "last_name": "User"}, **kwarg
    )
    sgc.LabMember.LabMemberInfo.insert1(
        {**mk, "datajoint_user_name": "user1", "google_user_name": "user1"},
        **kwarg,
    )
    for session in sgc.Session.fetch("KEY", as_dict=True):
        sgc.Session.Experimenter.insert1({**session, **mk}, **kwarg)

    mk = {"lab_member_name": "user2"}
    kwarg = {"skip_duplicates": True}
    print("a")
    sgc.LabMember.insert1(
        {**mk, "first_name": "user2", "last_name": "User"}, **kwarg
    )
    sgc.LabMember.LabMemberInfo.insert1(
        {**mk, "datajoint_user_name": "user2", "google_user_name": "user2"},
        **kwarg,
    )
    for session in sgc.Session.fetch("KEY", as_dict=True):
        sgc.Session.Experimenter.insert1({**session, **mk}, **kwarg)

if ACTION == "delete_spy":
    from spyglass import common as sgc

    sgc.Nwbfile.delete()
