import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { logoutAction } from "../actions";

type Attachment = {
  originalName: string;
  url: string;
  size?: number;
  type?: string;
};

function getAttachments(value: unknown): Attachment[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is Attachment => {
    return Boolean(item && typeof item === "object" && "url" in item && "originalName" in item);
  });
}

function formatDate(date: Date) {
  return new Intl.DateTimeFormat("ko-KR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatSize(size?: number) {
  if (!size) return "";
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / 1024 / 1024).toFixed(1)} MB`;
}

export default async function BoardPage() {
  const user = await requireUser();
  const posts = await prisma.post.findMany({
    orderBy: { createdAt: "desc" },
    include: { author: { select: { name: true, email: true } } },
  });

  return (
    <main className="board-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Internal Staff</p>
          <h1>직원 게시판</h1>
          <p className="muted">{user.name}님으로 로그인했습니다.</p>
        </div>
        <div className="header-actions">
          <Link className="button-link" href="/board/new">글쓰기</Link>
          <form action={logoutAction}>
            <button className="secondary" type="submit">로그아웃</button>
          </form>
        </div>
      </header>

      <section className="posts">
        <div className="section-title">
          <div>
            <h2>게시글</h2>
            <span>{posts.length}개</span>
          </div>
        </div>

        {posts.length === 0 ? (
          <p className="empty">아직 게시글이 없습니다.</p>
        ) : (
          posts.map((post) => {
            const attachments = getAttachments(post.attachments);
            return (
              <article className="post-card" key={post.id}>
                <div className="post-head">
                  <div>
                    <h3>{post.title}</h3>
                    <p className="muted">
                      {post.author.name} · {formatDate(post.createdAt)}
                    </p>
                  </div>
                </div>
                <p className="post-content">{post.content}</p>

                {attachments.length > 0 ? (
                  <div className="attachments">
                    <strong>첨부파일</strong>
                    <ul>
                      {attachments.map((file) => (
                        <li key={file.url}>
                          <a href={file.url} download>
                            {file.originalName}
                          </a>
                          <span>{formatSize(file.size)}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                ) : null}
              </article>
            );
          })
        )}
      </section>
    </main>
  );
}
