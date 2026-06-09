#!/usr/bin/env bash
set -euo pipefail

DB01_IP="${DB01_IP:-192.168.100.135}"
REPLICA_SET="${REPLICA_SET:-rs0}"
CONF="/etc/mongod.conf"
BACKUP="/etc/mongod.conf.$(date +%Y%m%d%H%M%S).bak"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo DB01_IP=${DB01_IP} $0"
  exit 1
fi

if ! command -v mongod >/dev/null 2>&1; then
  echo "mongod is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "$CONF does not exist."
  exit 1
fi

cp "$CONF" "$BACKUP"
echo "Backed up $CONF to $BACKUP"

cat > "$CONF" <<EOF
# mongod.conf

storage:
  dbPath: /var/lib/mongodb

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1,${DB01_IP}

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

replication:
  replSetName: ${REPLICA_SET}

security:
  authorization: enabled
EOF

install -d -o mongodb -g mongodb /var/lib/mongodb /var/log/mongodb
touch /var/log/mongodb/mongod.log
chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb
chmod 755 /var/lib/mongodb /var/log/mongodb
chmod 600 /var/log/mongodb/mongod.log

echo "Validating mongod config..."
mongod --config "$CONF" --configExpand none --help >/dev/null

echo "Restarting mongod..."
systemctl daemon-reload
systemctl restart mongod
systemctl enable mongod >/dev/null

echo
echo "Service status:"
systemctl --no-pager --full status mongod

echo
echo "Listening sockets on 27017:"
ss -lntp | grep ':27017' || {
  echo "mongod is not listening on 27017."
  exit 1
}

echo
echo "Replica set status:"
if command -v mongosh >/dev/null 2>&1; then
  mongosh --quiet --host "${DB01_IP}" --port 27017 --eval '
    try {
      const status = rs.status();
      print("replicaSet=" + status.set + ", myState=" + status.myState + ", ok=" + status.ok);
    } catch (e) {
      print("rs.status() failed: " + e.message);
      print("If this is a new DB01 MongoDB, initialize once with:");
      print("rs.initiate({ _id: \"'"${REPLICA_SET}"'\", members: [{ _id: 0, host: \"'"${DB01_IP}"':27017\" }] })");
    }
  '
else
  echo "mongosh is not installed; skipped replica set check."
fi

echo
echo "DB01 MongoDB config completed for ${DB01_IP}:27017 (${REPLICA_SET})."
