import './globals.css'

import { Viewport } from 'next'
import { Geist, Geist_Mono } from 'next/font/google'

import { QueryProvider } from '~/providers'
import { AuthProvider } from '~/providers/auth'
import { NotifyProvider } from '~/providers/notify'

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
})

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
})

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <head>
        <title>Circle Test APP</title>
        <meta name="description" content="Circle Test" />
        <link rel="icon" href="/favicon.ico" />
        <link rel="apple-touch-icon" href="/favicon-32x32.png" />

        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="application-name" content="Circle Test" />
        <meta name="apple-mobile-web-app-title" content="Circle Test" />
        <meta name="msapplication-starturl" content="/" />

        <link rel="apple-touch-icon" sizes="512x512" href="/android-chrome-512x512.png" />
        <link rel="icon" type="image/png" sizes="512x512" href="/android-chrome-512x512.png" />
      </head>
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <QueryProvider>
          <AuthProvider>
            <NotifyProvider>{children}</NotifyProvider>
          </AuthProvider>
        </QueryProvider>
      </body>
    </html>
  )
}
