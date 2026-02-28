/**
 * Метод для получения обрезанного значения без округления
 * @param {number | string} value Значение для обрезания хвоста, с плавающей запятой
 * @param {number} decimals Сколько символов оставить после точки
 * @return {number} итоговое значение в числовом представлении
 */
export const truncate = (value: string | number, decimals = 2) => {
  const s = value.toString()
  const d = s.split('.')

  if (d[1]) {
    d[1] = d[1].substring(0, decimals)
  }

  return parseFloat(d.join('.'))
}
