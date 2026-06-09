# WAS01 / DB01 Split Deployment

This guide separates the internal staff board into two Ubuntu Server VMs:

```text
WAS01
`- Next.js internal staff board :3001

DB01
`- MongoDB :27017
```

## Network Values

Decide these first:

```text
WAS01_IP=<was01_internal_ip>
DB01_IP=<db01_internal_ip>
APP_DB_PASSWORD=<strong_mongodb_password>
JWT_SECRET=<long_random_secret>
```

Generate `JWT_SECRET` on WAS01:

```bash
openssl rand -base64 48
```

## DB01

Install MongoDB and `mongosh` on DB01 using the team's approved package source.

Copy this repository or at least `scripts/configure-db01-mongodb.sh` to DB01, then run:

```bash
sudo DB01_IP=<DB01_IP> APP_DB_PASSWORD='<strong_mongodb_password>' ./scripts/configure-db01-mongodb.sh
```

The script will:

- bind MongoDB to `127.0.0.1,<DB01_IP>` on port `27017`
- configure `rs0` as a single-node replica set
- create or update `internal_staff.internal_app`
- enable MongoDB authorization
- verify the authenticated app connection

DB01 should listen on:

```text
127.0.0.1:27017
<DB01_IP>:27017
```

## Firewall

Allow only WAS01 to reach MongoDB:

```text
WAS01_IP -> DB01_IP:27017/tcp
```

Block direct MongoDB access from WAN, DMZ, and normal user networks.

## WAS01

On WAS01, from the project root:

```bash
cp .env.was01.example .env
nano .env
```

Set:

```env
DATABASE_URL="mongodb://internal_app:<strong_mongodb_password>@<DB01_IP>:27017/internal_staff?authSource=internal_staff&replicaSet=rs0&directConnection=true&maxPoolSize=10"
JWT_SECRET="<long_random_secret>"
NEXT_PUBLIC_APP_URL="http://<WAS01_IP>:3001"
```

Then install, sync Prisma, build, and start:

```bash
npm install
npx prisma generate
npx prisma db push
npm run build
npm run start
```

For development mode on WAS01:

```bash
npm run dev
```

## Verification

From WAS01:

```bash
npx prisma db push
curl -I http://localhost:3001/login
```

From DB01:

```bash
mongosh "mongodb://internal_app:<strong_mongodb_password>@<DB01_IP>:27017/internal_staff?authSource=internal_staff&replicaSet=rs0&directConnection=true" --eval 'db.runCommand({ ping: 1 })'
```

In the browser, open:

```text
http://<WAS01_IP>:3001/register
http://<WAS01_IP>:3001/login
```

Registering and logging in should redirect to `/board`.
