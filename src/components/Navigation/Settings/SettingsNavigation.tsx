'use client'

import Link from 'next/link'
import { useParams, usePathname } from 'next/navigation'

import { cn } from '~/utils/cn'
import { matchesPathname } from '~/utils/matchPath'

import { Typography } from '../../ui'
import { NavItem } from '../types'

type Props = {
  nav: NavItem[]
}

export const SettingsNavigation = (props: Props) => {
  const { nav: definedNav } = props

  const pathname = usePathname()
  const { userId } = useParams<{ userId: string }>()

  const nav = definedNav?.map((item) => ({
    ...item,
    url: item?.url?.replace('[userId]', userId),
  }))

  return (
    <ul className="flex justify-start overflow-x-auto mx-[-8px] px-2 md:px-0 md:mx-0">
      {nav?.map((item) => {
        const isCurrent = matchesPathname(item.url, pathname)

        return (
          <li key={[item.url, item.title].join('-')}>
            <Link
              className={cn(
                'flex flex-row p-2 bg-slate-100/50 dark:bg-slate-900 justify-start items-center select-none gap-1 rounded-t-md leading-none no-underline outline-none transition-colors hover:text-accent-foreground',
                {
                  'text-accent-foreground pointer-events-none bg-slate-100': isCurrent,
                  'hover:translate-y-1.5 bg-slate-200/50 translate-y-1': !isCurrent,
                },
              )}
              href={item.url}
            >
              {item.icon}
              <div>
                <Typography
                  variant="Body/XS/Regular"
                  className={cn('text-xs', {
                    'font-semibold': isCurrent,
                  })}
                >
                  {item.title}
                </Typography>
              </div>
            </Link>
          </li>
        )
      })}
    </ul>
  )
}
