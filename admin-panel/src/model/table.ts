import type { SORT_COLUMN_TYPES } from '@/model/api'

export interface ITableColumn {
  name?: string
  key: string
  sortable?: boolean
  sortField?: string
  sortFieldType?: SORT_COLUMN_TYPES
  max_width?: string

  // Hücrenin nasıl render edileceğini belirler. 'date' -> DD.MM.YYYY,
  // 'datetime' -> DD/MM/YYYY HH:mm. Belirtilmezse ham değer yazılır.
  type?: 'date' | 'datetime'
}
