# DataJoint Permission Error Demo

This repo aimed to replicate an error that users with
limited privelages experiece when using DataJoint 0.14.1 to perform cascading
deletes, as discussed in
[this datajoint issue](https://github.com/datajoint/datajoint-python/issues/1110)
and [this mysql forum post](https://bugs.mysql.com/bug.php?id=99336).
We were not able to replicate the error, leading to the conclusion that there
is an issue with our MySQL setup, having upgraded from 5.7 to 8.0.

To run the demo, execute `_startup.sh`. After running this script, get a more
interactive debug mode with `ipython -i pipeline.py basic 8 delete`.
