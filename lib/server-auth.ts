import { APP_INTERNAL_ORIGIN } from '@config/env'
import { AxiosError } from 'axios'
import { headers } from 'next/headers'

import { ClientAuthApi } from '~/api/auth'
import { UserModel } from '~/api/user'
import { logger } from '~/utils/logger'

export async function getServerProfile(): Promise<Pick<UserModel, 'id' | 'email' | 'role' | 'status'> | null> {
  try {
    const headersStore = await headers()
    const host = headersStore.get('host') || ''
    const protocol = headersStore.get('x-forwarded-proto') || 'http'
    const origin = `${protocol}://${host}`
    const apiOrigin = APP_INTERNAL_ORIGIN || origin
    const cookie = headersStore.get('cookie') || ''
    const api = new ClientAuthApi(apiOrigin, { headers: { Cookie: cookie } })
    const profile = await api.profile()

    return profile
  } catch (error) {
    if (error instanceof AxiosError) {
      logger.error('getServerProfile', error.response?.data, error.response?.status)
    } else {
      logger.error('getServerProfile', error)
    }

    return null
  }
}
