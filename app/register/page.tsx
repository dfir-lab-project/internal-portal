import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/auth";
import { registerAction } from "../actions";

type RegisterPageProps = {
  searchParams?: Promise<{ error?: string }>;
};

export default async function RegisterPage({ searchParams }: RegisterPageProps) {
  const user = await getCurrentUser();
  if (user) redirect("/board");

  const params = await searchParams;
  const error = params?.error;

  return (
    <main className="auth-shell">
      <section className="auth-panel">
        <p className="eyebrow">Internal Staff</p>
        <h1>회원가입</h1>
        <p className="muted">내부 직원 게시판에서 사용할 계정을 만듭니다.</p>

        {error === "exists" ? <p className="error">이미 가입된 이메일입니다.</p> : null}
        {error === "password" ? <p className="error">비밀번호는 6자 이상이어야 합니다.</p> : null}

        <form action={registerAction} className="form-stack">
          <label>
            이름
            <input name="name" type="text" autoComplete="name" required />
          </label>
          <label>
            이메일
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label>
            비밀번호
            <input name="password" type="password" autoComplete="new-password" minLength={6} required />
          </label>
          <button type="submit">가입하기</button>
        </form>

        <p className="switch-link">
          이미 계정이 있나요? <Link href="/login">로그인</Link>
        </p>
      </section>
    </main>
  );
}
