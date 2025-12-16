export const metadata = {
  title: 'Week1 Web3 Login',
  description: 'EOA 기반 Web3 로그인 (EIP-1193)',
};

export default function RootLayout(props: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body style={{ fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, Apple Color Emoji, Segoe UI Emoji' }}>
        {props.children}
      </body>
    </html>
  );
}


