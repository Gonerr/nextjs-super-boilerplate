import { clsx } from 'clsx'
import { type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/**
 * @param {...any} inputs - The inputs classnames to merge.
 * @return {String} merged classnames
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
