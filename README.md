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

`.env.example`을 참고해서 프로젝트 루트에 `.env`를 만듭니다.

```env
DATABASE_URL="mongodb://internal_app:internal_password_1234@127.0.0.1/internal_staff?authSource=internal_staff&directConnection=true"
JWT_SECRET="change_this_to_a_long_random_secret"
NEXT_PUBLIC_APP_URL="http://localhost:3001"
```

`JWT_SECRET`은 운영 환경에서 충분히 긴 임의 문자열로 바꿔야 합니다.

```bash
openssl rand -base64 48
```

`.env`는 GitHub에 올리지 않습니다.

## MongoDB 앱 계정

MongoDB 인증이 켜져 있다면 아래처럼 앱 계정을 만듭니다.

```javascript
use internal_staff

db.createUser({
  user: "internal_app",
  pwd: "internal_password_1234",
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
