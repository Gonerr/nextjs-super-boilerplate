import { isDevelop } from '@config/env'
import { apiErrorHandlerContainer } from '@lib/error'
import { NextRequest, NextResponse } from 'next/server'

const handler = (request: NextRequest) =>
  apiErrorHandlerContainer(request)(async (response: typeof NextResponse) => {
    return response.json({ isDevelop })
  })

export const GET = handler
