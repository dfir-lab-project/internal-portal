import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Internal Staff Board",
  description: "Internal employee board for the Ubuntu VM lab",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
