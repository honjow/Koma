/** Shared declarative form contract. Persistence and validation ownership stay with each consumer. */
export type SettingsFieldValue = string | boolean | number | string[]
export type SettingsFieldValues = Record<string, SettingsFieldValue>
export interface SettingsFieldOption { id: string; label: string }
export interface SettingsFieldValidation { kind: string; message: string }
export interface SettingsFieldDescriptor {
  id: string
  label: string
  kind: string
  description?: string
  validation?: SettingsFieldValidation
  defaultValue?: SettingsFieldValue
  minValue?: number
  maxValue?: number
  step?: number
  options?: SettingsFieldOption[]
  children?: string[]
  loginRefKey?: string
  supported: boolean
  sensitive: boolean
}
