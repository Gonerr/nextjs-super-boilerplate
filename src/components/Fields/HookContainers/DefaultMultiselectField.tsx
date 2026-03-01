'use client'

import get from 'lodash/get'
import { forwardRef } from 'react'
import { Controller, useFormContext } from 'react-hook-form'

import { Label, Option } from '~/components/ui'
import { MultipleSelectorRef } from '~/components/ui/multiselect'
import { Spinner } from '~/components/ui/spinner-1'
import { cn } from '~/utils/cn'

import { MultiselectField } from '../Input'

type Props = {
  options: Option[]
  label?: string
  name: string
  placeholder?: string
  required?: boolean
  disabled?: boolean
  isLoading?: boolean
  maxSelected?: number
  className?: string
  error?: React.ReactNode
  updateBySelected?: boolean
  emptyIndicator?: React.ReactNode
}

export const DefaultMultiselectField = forwardRef<MultipleSelectorRef, Props>(
  (
    { options, label, className, name, maxSelected = 1, updateBySelected, placeholder, required, error: defaultError, isLoading, disabled, emptyIndicator },
    _,
  ) => {
    const {
      formState: { errors },
      watch,
    } = useFormContext()
    const error = get(errors, name)?.message
    const value = watch(name)

    const finalError = error || defaultError

    return (
      <div className={cn('flex flex-col gap-2', className)}>
        <Label isError={!!finalError} className="flex flex-row items-start gap-2">
          <span>
            {label} {required && <span className="text-destructive">*</span>}
          </span>
          {isLoading && <Spinner size={16} />}
        </Label>
        <Controller
          name={name}
          render={({ field: { onChange: defaultOnChange } }) => (
            <MultiselectField
              options={options}
              onChange={defaultOnChange}
              value={value}
              label={label}
              maxSelected={maxSelected}
              updateBySelected={updateBySelected}
              placeholder={placeholder}
              required={required}
              error={finalError as React.ReactNode}
              isLoading={isLoading}
              disabled={disabled}
              emptyIndicator={emptyIndicator}
            />
          )}
        />

        {finalError && (
          <p className="mt-2 text-xs text-destructive" role="alert" aria-live="polite">
            {finalError as string}
          </p>
        )}
      </div>
    )
  },
)

DefaultMultiselectField.displayName = 'MultiselectField'
