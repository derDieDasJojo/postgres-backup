#!/bin/bash

if [ "${POSTGRES_ENV_POSTGRES_PASS}" == "**Random**" ]; then
        unset POSTGRES_ENV_POSTGRES_PASS
fi

POSTGRES_HOST=${POSTGRES_PORT_3306_TCP_ADDR:-${POSTGRES_HOST}}
POSTGRES_HOST=${POSTGRES_PORT_1_3306_TCP_ADDR:-${POSTGRES_HOST}}
POSTGRES_PORT=${POSTGRES_PORT_3306_TCP_PORT:-${POSTGRES_PORT}}
POSTGRES_PORT=${POSTGRES_PORT_1_3306_TCP_PORT:-${POSTGRES_PORT}}
POSTGRES_USER=${POSTGRES_USER:-${POSTGRES_ENV_POSTGRES_USER}}
PGPASSWORD=${PGPASSWORD:-${POSTGRES_ENV_POSTGRES_PASS}}

[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { echo "=> POSTGRES_PORT cannot be empty" && exit 1; }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
[ -z "${PGPASSWORD}" ] && { echo "=> PGPASSWORD cannot be empty" && exit 1; }

BACKUP_CMD="pg_dump -h${POSTGRES_HOST} -p${POSTGRES_PORT} -U${POSTGRES_USER} ${EXTRA_OPTS} ${POSTGRES_DB} > /backup/"'${BACKUP_NAME}'
BACKUP_UPLOAD_CMD="sshpass -p '"${BACKUP_SERVER_PASS}"' scp -r -oStrictHostKeyChecking=no /backup/"'${BACKUP_NAME}'" ${BACKUP_SERVER_USER}@${BACKUP_SERVER}:/mongobackup/${BACKUP_REMOTE_SUBFOLDER}/${BACKUP_NAME}"
SFTP_CMD="sshpass -p ${BACKUP_SERVER_PASS} sftp ${BACKUP_SERVER_USER}@${BACKUP_SERVER}"

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}

BACKUP_NAME=\$(date +\%Y.\%m.\%d.\%H\%M\%S).sql

echo "=> Backup started: \${BACKUP_NAME}"
if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"

    echo "=> Uploading Backup started"
    echo ${BACKUP_UPLOAD_CMD}
    ${BACKUP_UPLOAD_CMD} && echo "  Upload succeeded" || echo "  Upload failed"

else
    echo "   Backup failed"
    rm -rf /backup/\${BACKUP_NAME}
fi

if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls /backup -N1 | wc -l) -gt \${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(ls /backup -N1 | sort | head -n 1)
        echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
        rm -rf /backup/\${BACKUP_TO_BE_DELETED}
    done
fi

if [ -n "\${MAX_REMOTE_BACKUPS}" ]; then
    while [ \$(echo ls /backup/${BACKUP_REMOTE_SUBFOLDER} | ${SFTP_CMD} | wc -l ) -ge \${MAX_REMOTE_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(echo ls -1 /backup/${BACKUP_REMOTE_SUBFOLDER} | ${SFTP_CMD} | sort | head -n 1)
        echo "   Deleting REMOTE backup \${BACKUP_TO_BE_DELETED}"
        DBFOLDER_TO_BE_DELETED=\$(echo ls -1 \${BACKUP_TO_BE_DELETED} | ${SFTP_CMD} | sort | head -n 1)
        echo rm \${DBFOLDER_TO_BE_DELETED}/* | ${SFTP_CMD}
        echo rmdir \${DBFOLDER_TO_BE_DELETED} | ${SFTP_CMD}
        echo rmdir \${BACKUP_TO_BE_DELETED} | ${SFTP_CMD}
    done
fi


echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
echo "=> Restore database from \$1"
if pg_restore -h${POSTGRES_HOST} -p${POSTGRES_PORT} -U${POSTGRES_USER} < \$1 ;then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh

touch /postgres_backup.log
tail -F /postgres_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
    echo "=> Restore lates backup"
    until nc -z $POSTGRES_HOST $POSTGRES_PORT
    do
        echo "waiting database container..."
        sleep 1
    done
    ls -d -1 /backup/* | tail -1 | xargs /restore.sh
fi

echo "${CRON_TIME} /backup.sh >> /postgres_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f

