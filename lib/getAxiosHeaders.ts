import { AxiosHeaders } from 'axios'

/**
 * Метод нужен для максимального проксирования 1 в 1 запросов от клиента на бэкенд
 * Если трубется сделать отличный от клиентского запроса в BFF, то лучше не использовать этот метод
 * @param values - объект с заголовками
 * @returns объект с заголовками
 */
export const getAxiosHeaders = (values: Record<string, unknown>) => {
  const parsedHeaders = Object.entries(values)
    .filter(([, value]) => !!value)
    .reduce((all, [key, value]) => ({ ...all, [key]: value }), {})

  const headers: AxiosHeaders = new AxiosHeaders(parsedHeaders)

  /**
   * Добавлено приведение типа из-за внезапный проблем со строгим стравнением типов данных
   * Ранее такого не возникало, видимо что-то обновилось в axios
   */
  return headers
}
