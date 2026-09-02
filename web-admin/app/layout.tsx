export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body style={{ fontFamily: 'system-ui', margin: 0, background: '#0a0a0a', color: '#fff' }}>{children}</body>
    </html>
  );
}
