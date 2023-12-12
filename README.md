# DataJoint Permission Error Demo

**WORK IN PROGRESS**

This repo serves as a stand-alone demonstration of the error that users with
limited privelages experiece when using DataJoint 0.14.1 to perform cascading
deletes, as discussed further in
[this issue](https://github.com/datajoint/datajoint-python/issues/1110).

To run the demo, execute `_startup.sh`. After running this script, get a more
interactive debug mode with `ipython -i pipeline.py basic 8 delete` followed by
`%debug`.
