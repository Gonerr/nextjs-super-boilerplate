import { AxiosError, AxiosResponse } from 'axios'
import { NextRequest, NextResponse } from 'next/server'

/**
 * Метод - обертка, для сокращения кода использования catch и проброса ошибок
 */
export const apiErrorHandlerContainer =
  (req: NextRequest) =>
  async <T>(handler: (res: typeof NextResponse, req: NextRequest) => Promise<T>) => {
    const res = NextResponse

    try {
      return await handler(res, req)
    } catch (error: unknown) {
      if (error instanceof AxiosError) {
        return res.json(
          {
            message: error.response?.data?.message,
            error: error.response?.data?.error,
          },
          {
            status: error.response?.status,
          },
        )
      }

      const response = error && typeof error === 'object' && 'response' in error ? (error.response as AxiosResponse) : null

      if (response) {
        return res.json(
          {
            message: response.data,
          },
          {
            status: response.status,
          },
        )
      }

      return res.json(
        {
          message: 'Something goes wrong...',
        },
        {
          status: 500,
        },
      )
    }
  }
