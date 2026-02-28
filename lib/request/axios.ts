import axios, { AxiosInstance, CreateAxiosDefaults } from 'axios'

export class Request {
  private readonly client: AxiosInstance
  private readonly isServerRequest: boolean

  // Общий флаг и промис для "single-flight" рефреша токена
  private static isRefreshing = false
  private static refreshPromise: Promise<unknown> | null = null

  constructor(config?: CreateAxiosDefaults) {
    const { headers, baseURL, ...props } = config || {}

    // Определяем, это серверный запрос или клиентский
    // Серверные запросы имеют baseURL (к бэкенду), клиентские - нет (к /api)
    this.isServerRequest = !!baseURL

    this.client = axios.create({
      baseURL,
      headers: {
        Accept: '*/*',
        ...(headers as any),
      },
      withCredentials: true,
      ...props,
    })

    this.client.interceptors.response.use(
      (response) => {
        return response
      },
      async (error) => {
        console.error('error', error)

        const originalRequest = error.config

        let nextPath = ''

        if (!this.isServerRequest && typeof window !== 'undefined') {
          nextPath = window.location.pathname
        }

        if (error?.response?.status === 400 && error?.response?.data?.message === 'No refresh token') {
          if (!this.isServerRequest) {
            window.location.href = `/logout?nextPath=${nextPath ?? '/'}`
          } else {
            return Promise.reject(error)
          }

          return Promise.reject(error)
        }

        /**
         * При 401 ошибке обрабатываем logout по-разному для клиента и сервера
         */
        if (error?.status === 401 || error?.response?.status === 401) {
          if (this.isServerRequest) {
            // ВАЖНО: Возвращаем 401 ошибку, чтобы API route мог её обработать
            return Promise.reject({
              ...error,
              status: 401,
              message: 'Authentication required',
              cookiesCleared: true,
            })
          } else {
            // Для клиентских запросов - пытаемся один раз обновить токен и повторить запрос
            if (!originalRequest || originalRequest._retry) {
              // Уже пробовали рефреш для этого запроса — выходим, чтобы не зациклиться
              return Promise.reject(error)
            }

            originalRequest._retry = true

            try {
              console.log('Try to refresh token...')

              if (!Request.isRefreshing) {
                Request.isRefreshing = true
                Request.refreshPromise = this.client
                  .post('/api/v1/auth/refresh')
                  .catch((refreshError) => {
                    console.error('Failed to refresh token:', refreshError)
                    throw refreshError
                  })
                  .finally(() => {
                    Request.isRefreshing = false
                    Request.refreshPromise = null
                  })
              }

              // Ждем общего рефреша (single-flight для всех 401)
              if (Request.refreshPromise) {
                await Request.refreshPromise
              }

              // После успешного рефреша повторяем оригинальный запрос
              return this.client(originalRequest)
            } catch (refreshError) {
              // Если рефреш не удался — отдаём оригинальную ошибку, дальше её обработает верхний уровень
              return Promise.reject(refreshError)
            }
          }
        }

        return Promise.reject(error)
      },
    )

    return this
  }

  get apiClient() {
    return this.client
  }
}
