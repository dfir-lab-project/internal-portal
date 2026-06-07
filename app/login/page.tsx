import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/auth";
import { loginAction } from "../actions";

type LoginPageProps = {
  searchParams?: Promise<{ error?: string }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const user = await getCurrentUser();
  if (user) redirect("/board");

  const params = await searchParams;
  const error = params?.error;

  return (
    <main className="auth-shell">
      <section className="auth-panel">
        <p className="eyebrow">Internal Staff</p>
        <h1>로그인</h1>
        <p className="muted">직원 게시판에 접근하려면 로그인하세요.</p>

        {error === "invalid" ? <p className="error">이메일 또는 비밀번호가 올바르지 않습니다.</p> : null}

        <form action={loginAction} className="form-stack">
          <label>
            이메일
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label>
            비밀번호
            <input name="password" type="password" autoComplete="current-password" required />
          </label>
          <button type="submit">로그인</button>
        </form>

        <p className="switch-link">
          계정이 없나요? <Link href="/register">회원가입</Link>
        </p>
      </section>
    </main>
  );
}
