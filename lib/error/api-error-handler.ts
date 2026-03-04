import { AxiosError, AxiosResponse } from 'axios'
import { NextRequest, NextResponse } from 'next/server'

import { getUniqueId } from '~/utils/getUniqueId'
import { logger } from '~/utils/logger'
import { time } from '~/utils/time'

/**
 * Method - wrapper, to reduce the code using catch and passing errors
 */
export const apiErrorHandlerContainer =
  (req: NextRequest) =>
  async <T>(handler: (res: typeof NextResponse, req: NextRequest) => Promise<T>) => {
    const res = NextResponse

    const traceId = getUniqueId()

    try {
      const start = time()

      logger.info('apiErrorHandlerContainer start', {
        traceId,
        url: req.nextUrl.toString(),
        method: req.method,
        headers: Object.fromEntries(req.headers.entries()),
        startHandler: start.toISOString(),
      })

      const result = await handler(res, req)

      logger.info('apiErrorHandlerContainer end', {
        traceId,
        url: req.nextUrl.toString(),
        method: req.method,
        endHandler: time().toISOString(),
        durationMs: time().diff(start, 'milliseconds'),
      })

      return result
    } catch (error: unknown) {
      if (error instanceof AxiosError) {
        logger.error(`apiErrorHandlerContainer AxiosError traceId: ${traceId}`, error.response?.data, error.response?.status)

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

      logger.error(`apiErrorHandlerContainer traceId: ${traceId}`, (error as Error)?.message)

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
