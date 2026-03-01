import { setAuthCookies } from '@lib/cookies'
import { apiErrorHandlerContainer } from '@lib/error/api-error-handler'
import { authService } from '@lib/services/auth.service'
import { NextRequest } from 'next/server'

import { LoginEmailDto } from '~/api/auth/types'

export async function POST(request: NextRequest) {
  return apiErrorHandlerContainer(request)(async (res, req) => {
    const body: LoginEmailDto = await req.json()

    const authResponse = await authService.login(body)

    const response = res.json(
      {
        success: true,
        user: authResponse.user,
      },
      { status: 200 },
    )

    setAuthCookies(response, authResponse.accessToken, authResponse.refreshToken, authResponse.expiresIn)

    return response
  })
}
