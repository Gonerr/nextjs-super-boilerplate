'use client'

import { AlertCircleIcon, BadgeDollarSign, BellIcon, ChartLineIcon, MessageCircleIcon, UserCheckIcon, UserRoundIcon } from 'lucide-react'
import { Suspense } from 'react'

import { SpinnerScreen } from '../../Loaders'
import { NavItem } from '../types'
import { SettingsNavigation } from './SettingsNavigation'

type Props = {
  nav: NavItem[]
}

const nav = [
  { title: 'Профиль', url: '/admin/users/[userId]', icon: <UserRoundIcon width={16} height={16} /> },
  { title: 'Верификации', url: '/admin/users/[userId]/verification', icon: <UserCheckIcon width={16} height={16} /> },
  { title: 'Аналитика', url: '/admin/users/[userId]/analytics', icon: <ChartLineIcon width={16} height={16} /> },
  { title: 'Уведомления', url: '/admin/users/[userId]/notification', icon: <BellIcon width={16} height={16} /> },
  { title: 'Жалобы', url: '/admin/users/[userId]/reports', icon: <AlertCircleIcon width={16} height={16} /> },
  { title: 'Чаты', url: '/admin/users/[userId]/chats', icon: <MessageCircleIcon width={16} height={16} /> },
  { title: 'Подписки', url: '/admin/users/[userId]/subscription', icon: <BadgeDollarSign width={16} height={16} /> },
]

export const SettingsNavigationLazy = (props: Omit<Props, 'nav'>) => {
  return (
    <Suspense fallback={<SpinnerScreen />}>
      <SettingsNavigation nav={nav} {...props} />
    </Suspense>
  )
}
