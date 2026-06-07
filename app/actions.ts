"use server";

import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import bcrypt from "bcryptjs";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { clearSession, requireUser, setSession } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

function requiredText(formData: FormData, key: string) {
  const value = String(formData.get(key) ?? "").trim();
  if (!value) throw new Error(`${key} is required`);
  return value;
}

function safeFileName(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function isUploadedFile(entry: FormDataEntryValue): entry is File {
  return (
    typeof entry === "object" &&
    entry !== null &&
    "arrayBuffer" in entry &&
    "size" in entry &&
    typeof entry.size === "number" &&
    entry.size > 0
  );
}

export async function registerAction(formData: FormData) {
  const name = requiredText(formData, "name");
  const email = requiredText(formData, "email").toLowerCase();
  const password = requiredText(formData, "password");

  if (password.length < 6) redirect("/register?error=password");

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) redirect("/register?error=exists");

  const user = await prisma.user.create({
    data: {
      name,
      email,
      password: await bcrypt.hash(password, 10),
    },
  });

  await setSession({ userId: user.id, email: user.email });
  redirect("/board");
}

export async function loginAction(formData: FormData) {
  const email = requiredText(formData, "email").toLowerCase();
  const password = requiredText(formData, "password");

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) redirect("/login?error=invalid");

  const ok = await bcrypt.compare(password, user.password);
  if (!ok) redirect("/login?error=invalid");

  await setSession({ userId: user.id, email: user.email });
  redirect("/board");
}

export async function logoutAction() {
  await clearSession();
  redirect("/login");
}

export async function createPostAction(formData: FormData) {
  const user = await requireUser();
  const title = requiredText(formData, "title");
  const content = requiredText(formData, "content");
  const files = formData.getAll("files").filter(isUploadedFile);

  const uploadDir = path.join(process.cwd(), "public", "uploads");
  await mkdir(uploadDir, { recursive: true });

  const attachments = [];
  for (const file of files) {
    const storedName = `${Date.now()}-${randomUUID()}-${safeFileName(file.name || "file")}`;
    const diskPath = path.join(uploadDir, storedName);
    const bytes = Buffer.from(await file.arrayBuffer());
    await writeFile(diskPath, bytes);
    attachments.push({
      originalName: file.name || storedName,
      storedName,
      url: `/uploads/${storedName}`,
      size: file.size,
      type: file.type || "application/octet-stream",
    });
  }

  await prisma.post.create({
    data: {
      title,
      content,
      attachments,
      authorId: user.id,
    },
  });

  revalidatePath("/board");
  redirect("/board");
}
