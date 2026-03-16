#!/bin/sh
set -eu

# Fly volumes are mounted at runtime, so fix ownership after the mount is attached.
mkdir -p /data
chown -R nobody:root /data
chmod 0770 /data
find /data -maxdepth 1 -type f \( -name '*.db' -o -name '*.db-shm' -o -name '*.db-wal' \) -exec chmod 0660 {} +

if [ "$#" -eq 0 ]; then
  set -- /app/bin/server
fi

exec gosu nobody "$@"
