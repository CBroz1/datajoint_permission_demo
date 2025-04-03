# MySQL Permission Error Demo

## Database Configuration

Scripts provided by Dirk Kleinhesselink to demonstrate the Frank Lab's MySQL
configuration.  The scripts are designed to be run on a Linux system with
Docker installed.

1. Local settings files
    - `mysql.env` - Copy `example.mysql.env` to `mysql.env` and fill in values
    - `my.cnf` - Copy `example.my.cnf` to `my.cnf` and modify
        the values to remove the need for credentials in the command line.
        For a production system, leave this file blank.
2. Custom image: download and build
    - `container/1_load-image.sh` - Download and load the mysql-8.0.34 image
        into the local docker repository.
    - `container/2_build-mysql8.sh`[^1] - Build the custom MySQL container image
        from the Dockerfile.base and the mysql-8.0.34 image.
3. `container/3_init-mysql8.sh` - Initialize the MySQL container
    - Loads `mysql.env`
    - Makes folders for various paths (see `mysql.env`)
    - Starts the MySQL container
    - Maps scripts/configs into the container (see `container/bin` and
        `container/conf`)
    - Generates security certificates via openssl
4. `container/4_start-mysql8.sh` - Start the MySQL container
5. `container/5_shell.sh` - Open a shell in the MySQL container
6. `container/6_stop-mysql8.sh` - Stop the MySQL container
7. `container/7_relaunch-mysql8.sh` - Relaunch the MySQL container.  This is
    used to reinitialize the container after it has been stopped.
8. `container/8_destroy-mysql8.sh` - Destroy the MySQL container. Removes the
    container and the data volume.

[^1] Only use the build script if you do not have the container image already
or if you want to make a newer/updated image.  Note that the Dockerfile.base
has hard-coded references to now out-dated community mysql 8 repositories. To
build a newer container, you will need to know what repository file is available
and update the Dockerfile.base file first.  docker build is being deprecated.

The /var/lib/mysql folder will be mapped back to a folder outside the container
as will the mysql-backup folder.

## 3/26/25 Steps

- select single Nwbfile entries in all common tables listed in issue
- run export of these entries
- modify export varchars
  - initially run modified
  - issues importing from common with mismatching table definitions
- ensure log tables exist (from spy.X import schema; schema.log)
  - initially ran w/o and cascading delete attempted to declare it
  - declaring a table within a transaction raises an error
- as admin, import decoding tables not previously declared
  - basic user did not have permission to declare w/in dj_helper_fn:77
- as basic1, insert minirec file with insert_sessions
- as basic2, attempt to delete ...
  - session from export: No issue
  - minirec session above: REPLICATED

- declare tables with spyglass as admin
- insert minirec file with insert_sessions as basic1
