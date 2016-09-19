# mysql-backup

This image runs pg_dump to backup data using cronjob to folder `/backup`

## Usage:

    docker run -d \
        --env POSTGRES_HOST=mysql.host \
        --env POSTGRES_PORT=27017 \
        --env POSTGRES_USER=admin \
        --env POSTGRES_PASS=password \
        --volume host.folder:/backup
        derdiedasjojo/postgres-backup

Moreover, if you link `derdiedasjojo/postgres-backup` to a postgres container(e.g. `postgres`) with an alias named postgres, this image will try to auto load the `host`, `port`, `user`, `pass` if possible.

    docker run -d -p 27017:27017 -p 28017:28017 -e POSTGRES_PASS="mypass" --name postgres postgres
    docker run -d --link postgres:postgres -v host.folder:/backup derdiedasjojo/postgres-backup

## Parameters

    POSTGRES_HOST      the host/ip of your postgres database
    POSTGRES_PORT      the port number of your postgres database
    POSTGRES_USER      the username of your postgres database
    PGPASSWORD      the password of your postgres database
    POSTGRES_DB        the database name to dump. Default: `--all-databases`
    EXTRA_OPTS      the extra options to pass to pg_dump command
    CRON_TIME       the interval of cron job to run pg_dump. `0 0 * * *` by default, which is every day at 00:00
    MAX_BACKUPS     the number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default
    INIT_BACKUP     if set, create a backup when the container starts
    INIT_RESTORE_LATEST if set, restores latest backup

## Restore from a backup

See the list of backups, you can run:

    docker exec postgres-backup ls /backup

To restore database from a certain backup, simply run:

    docker exec postgres-backup /restore.sh /backup/2015.08.06.171901
