export type LoginEmailDto = {
  email: string
  password: string
}

/**
 * Базовая регистрация пользователя
 * Может использоваться для регистрации сотрудника овнером
 * Для админа отдельная DTO и endpoint
 */
export type RegisterDto = {
  email: string
  password: string
}
