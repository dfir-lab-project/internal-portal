# Internal Staff Board

Ubuntu VM에서 실행하는 내부 직원용 게시판 웹 사이트입니다.

## 기능

- 회원가입
- 로그인 / 로그아웃
- 로그인한 직원만 접근 가능한 게시판
- 게시글 목록
- 별도 글쓰기 페이지
- 여러 파일 첨부 및 다운로드

## 기술 스택

- Next.js 15
- React 19
- Prisma 6
- MongoDB
- bcryptjs
- jsonwebtoken

## 실행 포트

외부 사용자용 웹사이트와 같이 띄울 수 있도록 내부 직원용 웹사이트는 `3001` 포트를 사용합니다.

```text
http://localhost:3001
http://<VM_IP>:3001
```

현재 VM 예시:

```text
http://192.168.215.131:3001
```

## 환경 변수

로컬 개발에서는 `.env.example`을 복사해서 프로젝트 루트에 `.env`를 만듭니다.

```env
DATABASE_URL="mongodb://127.0.0.1:27018/internal_staff?replicaSet=rs0"
JWT_SECRET="change_this_to_a_long_random_internal_staff_secret"
NEXT_PUBLIC_APP_URL="http://localhost:3001"
```

Prisma MongoDB connector는 transaction 처리를 위해 replica set이 필요합니다. 로컬에서는 아래처럼 `27018` 포트에 단일 노드 replica set을 띄웁니다.

```bash
mkdir -p data/db
mongod --dbpath ./data/db --port 27018 --bind_ip 127.0.0.1 --replSet rs0
mongosh --port 27018 --eval 'rs.initiate({ _id: "rs0", members: [{ _id: 0, host: "127.0.0.1:27018" }] })'
```

이미 `rs0`가 초기화된 `data/db`를 다시 사용하는 경우에는 `rs.initiate`를 다시 실행하지 않아도 됩니다.

DB01/WAS01 분리 배포에서는 `.env.was01.example`을 WAS01의 `.env`로 복사해서 `<DB01_IP>`, `<WAS01_IP>`, 비밀번호, secret을 실제 값으로 바꿉니다.
DB01의 MongoDB는 `rs0` replica set으로 초기화되어 있어야 하며, 전체 분리 배포 절차는 `docs/WAS01_DB01_DEPLOYMENT.md`를 참고합니다.

`JWT_SECRET`은 운영 환경에서 충분히 긴 임의 문자열로 바꿔야 합니다.

```bash
openssl rand -base64 48
```

`.env`는 GitHub에 올리지 않습니다.

## DB01 MongoDB 서비스 설정

DB01에서 MongoDB가 `127.0.0.1`에만 묶여 있으면 WAS01이 접속할 수 없습니다. DB01 서버에서 아래 스크립트를 `sudo`로 실행해 MongoDB를 `27017` 포트와 DB01 내부 IP에 바인딩하고, `rs0` replica set 설정을 적용합니다.

```bash
sudo DB01_IP=<DB01_IP> APP_DB_PASSWORD='<strong_mongodb_password>' ./scripts/configure-db01-mongodb.sh
```

성공하면 `ss -lntp` 결과에 `<DB01_IP>:27017`이 보이고, `systemctl status mongod`가 `active (running)` 상태여야 합니다.

## MongoDB 앱 계정

MongoDB 인증이 켜져 있다면 아래처럼 앱 계정을 만듭니다.

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

## 설치

```bash
npm install
npx prisma generate
npx prisma db push
```

## 개발 실행

```bash
npm run dev
```

## 빌드 후 실행

```bash
npm run build
npm run start
```

## 업로드 파일

게시글 첨부파일은 `public/uploads`에 저장됩니다.

업로드 파일 자체는 GitHub에 올리지 않도록 `.gitignore`에서 제외하고, 폴더 유지를 위해 `public/uploads/.gitkeep`만 추적합니다.
