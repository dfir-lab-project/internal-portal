# DB01 MongoDB Setup for Internal Staff Board

Target architecture:

```text
WAS01 / Ubuntu VM
`- Internal Staff Board / Next.js :3001

DB01 / Ubuntu VM
`- MongoDB :27017
```

## 1. Configure MongoDB on DB01

Install MongoDB on DB01 using the team's approved package source. Then configure MongoDB to listen on the DB01 internal-server-zone IP and run as a single-node replica set for Prisma.

Edit `/etc/mongod.conf` on DB01:

```yaml
net:
  port: 27017
  bindIp: 127.0.0.1,<DB01_IP>

replication:
  replSetName: rs0

security:
  authorization: enabled
```

Restart MongoDB:

```bash
sudo systemctl restart mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

If this is a new DB01 MongoDB instance, initialize the replica set once:

```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "<DB01_IP>:27017" }
  ]
})
```

## 2. Create the internal app database user on DB01

Open `mongosh` on DB01 as an admin user and run:

```javascript
use internal_staff

db.createUser({
  user: "internal_app",
  pwd: "CHANGE_ME_STRONG_PASSWORD",
  roles: [
    { role: "readWrite", db: "internal_staff" },
    { role: "dbAdmin", db: "internal_staff" }
  ]
})
```

The `dbAdmin` role is useful while Prisma creates indexes during lab setup. Remove it later if the app no longer needs schema/index changes.

## 3. Allow only WAS01 to reach DB01

pfSense should allow:

```text
WAS01_IP -> DB01_IP:27017/tcp
```

Block direct access from WAN, DMZ, and User PC Zone unless the team has a specific admin path.

## 4. Configure WAS01

On WAS01, from the internal staff project root:

```bash
cp .env.db01.example .env
nano .env
```

Set:

```env
DATABASE_URL="mongodb://internal_app:CHANGE_ME_STRONG_PASSWORD@<DB01_IP>:27017/internal_staff?authSource=internal_staff&replicaSet=rs0&directConnection=true&maxPoolSize=10"
JWT_SECRET="CHANGE_ME_TO_A_LONG_RANDOM_INTERNAL_STAFF_SECRET"
NEXT_PUBLIC_APP_URL="http://<WAS01_IP>:3001"
```

Then run:

```bash
npm install
npx prisma generate
npx prisma db push
npm run build
npm run start
```

## Verification

From WAS01:

```bash
npx prisma db push
curl -I http://localhost:3001/login
```

From WEB01 or an allowed internal host, verify the app path that Nginx or pfSense routes to WAS01.
