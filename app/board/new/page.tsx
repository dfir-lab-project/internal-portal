import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { createPostAction, logoutAction } from "../../actions";

export default async function NewPostPage() {
  const user = await requireUser();

  return (
    <main className="board-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Internal Staff</p>
          <h1>새 게시글 작성</h1>
          <p className="muted">{user.name}님으로 로그인했습니다.</p>
        </div>
        <div className="header-actions">
          <Link className="button-link secondary-link" href="/board">목록</Link>
          <form action={logoutAction}>
            <button className="secondary" type="submit">로그아웃</button>
          </form>
        </div>
      </header>

      <section className="composer">
        <form action={createPostAction} className="post-form">
          <label>
            제목
            <input name="title" type="text" required />
          </label>
          <label>
            내용
            <textarea name="content" rows={10} required />
          </label>
          <label>
            첨부파일
            <input name="files" type="file" multiple />
          </label>
          <div className="form-actions">
            <Link className="button-link secondary-link" href="/board">취소</Link>
            <button type="submit">등록</button>
          </div>
        </form>
      </section>
    </main>
  );
}
