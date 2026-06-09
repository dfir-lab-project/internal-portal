#!/usr/bin/env bash
set -euo pipefail

DB01_IP="${DB01_IP:-}"
REPLICA_SET="${REPLICA_SET:-rs0}"
APP_DB="${APP_DB:-internal_staff}"
APP_DB_USER="${APP_DB_USER:-internal_app}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-}"
CONF="/etc/mongod.conf"
BACKUP="/etc/mongod.conf.$(date +%Y%m%d%H%M%S).bak"

usage() {
  cat <<USAGE
Usage:
  sudo DB01_IP=<db01_internal_ip> APP_DB_PASSWORD=<strong_password> $0

Optional environment variables:
  REPLICA_SET=rs0
  APP_DB=internal_staff
  APP_DB_USER=internal_app
USAGE
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  usage
  exit 1
fi

if [[ -z "$DB01_IP" || -z "$APP_DB_PASSWORD" ]]; then
  usage
  exit 1
fi

if ! command -v mongod >/dev/null 2>&1; then
  echo "mongod is not installed or not in PATH."
  exit 1
fi

if ! command -v mongosh >/dev/null 2>&1; then
  echo "mongosh is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "$CONF does not exist."
  exit 1
fi

cp "$CONF" "$BACKUP"
echo "Backed up $CONF to $BACKUP"

write_config() {
  local auth_mode="$1"

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
  authorization: ${auth_mode}
EOF
}

restart_mongod() {
  echo "Validating mongod config..."
  mongod --config "$CONF" --configExpand none --help >/dev/null

  echo "Restarting mongod..."
  systemctl daemon-reload
  systemctl restart mongod
  systemctl enable mongod >/dev/null
}

wait_for_mongod() {
  for _ in $(seq 1 30); do
    if mongosh --quiet --host 127.0.0.1 --port 27017 --eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "mongod did not become ready on 127.0.0.1:27017."
  exit 1
}

echo "Writing temporary DB01 MongoDB config with authorization disabled..."
write_config "disabled"

install -d -o mongodb -g mongodb /var/lib/mongodb /var/log/mongodb
touch /var/log/mongodb/mongod.log
chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb
chmod 755 /var/lib/mongodb /var/log/mongodb
chmod 600 /var/log/mongodb/mongod.log

restart_mongod
wait_for_mongod

echo "Initializing or verifying replica set ${REPLICA_SET}..."
DB01_IP="$DB01_IP" REPLICA_SET="$REPLICA_SET" mongosh --quiet --host 127.0.0.1 --port 27017 --eval '
  const replSet = process.env.REPLICA_SET;
  const host = process.env.DB01_IP + ":27017";

  try {
    const status = rs.status();
    const config = rs.conf();

    if (config._id !== replSet) {
      throw new Error("Existing replica set name is " + config._id + ", expected " + replSet);
    }

    if (config.members.length !== 1 || config.members[0].host !== host) {
      config.version += 1;
      config.members = [{ _id: 0, host }];
      rs.reconfig(config, { force: true });
      print("Replica set member reconfigured to " + host);
    } else {
      print("Replica set already configured as " + replSet + "/" + host);
    }
  } catch (e) {
    if (String(e.message).includes("no replset config has been received")) {
      rs.initiate({ _id: replSet, members: [{ _id: 0, host }] });
      print("Replica set initiated as " + replSet + "/" + host);
    } else {
      throw e;
    }
  }
'

echo "Waiting for PRIMARY..."
primary_ready=false
for _ in $(seq 1 30); do
  if mongosh --quiet --host 127.0.0.1 --port 27017 --eval 'rs.status().myState' | grep -q '^1$'; then
    primary_ready=true
    break
  fi
  sleep 1
done

if [[ "$primary_ready" != "true" ]]; then
  echo "Replica set did not become PRIMARY."
  exit 1
fi

echo "Creating or updating ${APP_DB}.${APP_DB_USER}..."
APP_DB="$APP_DB" APP_DB_USER="$APP_DB_USER" APP_DB_PASSWORD="$APP_DB_PASSWORD" mongosh --quiet --host 127.0.0.1 --port 27017 --eval '
  const appDb = process.env.APP_DB;
  const user = process.env.APP_DB_USER;
  const password = process.env.APP_DB_PASSWORD;
  const dbRef = db.getSiblingDB(appDb);
  const roles = [
    { role: "readWrite", db: appDb },
    { role: "dbAdmin", db: appDb }
  ];

  if (dbRef.getUser(user)) {
    dbRef.updateUser(user, { pwd: password, roles });
    print("Updated user " + appDb + "." + user);
  } else {
    dbRef.createUser({ user, pwd: password, roles });
    print("Created user " + appDb + "." + user);
  }
'

echo "Enabling MongoDB authorization..."
write_config "enabled"
restart_mongod
wait_for_mongod

echo "Verifying authenticated app connection..."
APP_DB="$APP_DB" APP_DB_USER="$APP_DB_USER" APP_DB_PASSWORD="$APP_DB_PASSWORD" DB01_IP="$DB01_IP" REPLICA_SET="$REPLICA_SET" mongosh --quiet --eval '
  const appDb = process.env.APP_DB;
  const user = encodeURIComponent(process.env.APP_DB_USER);
  const password = encodeURIComponent(process.env.APP_DB_PASSWORD);
  const host = process.env.DB01_IP + ":27017";
  const replSet = process.env.REPLICA_SET;
  const uri = `mongodb://${user}:${password}@${host}/${appDb}?authSource=${appDb}&replicaSet=${replSet}&directConnection=true`;
  const conn = new Mongo(uri);
  printjson(conn.getDB(appDb).runCommand({ ping: 1 }));
'

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
echo "DB01 MongoDB config completed."
echo "Use this on WAS01:"
echo "DATABASE_URL=\"mongodb://${APP_DB_USER}:<APP_DB_PASSWORD>@${DB01_IP}:27017/${APP_DB}?authSource=${APP_DB}&replicaSet=${REPLICA_SET}&directConnection=true&maxPoolSize=10\""
