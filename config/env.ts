const { APP_ENV = 'development', NEXT_PUBLIC_APP_ENV = 'development' } = process.env

const isDevelop = APP_ENV === 'development'
const isStage = APP_ENV === 'stage'
const isProd = APP_ENV === 'production'

export { APP_ENV, isDevelop, isProd, isStage, NEXT_PUBLIC_APP_ENV }
