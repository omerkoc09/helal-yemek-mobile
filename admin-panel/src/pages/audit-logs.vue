<script setup lang="ts">
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'action', name: 'İŞLEM', sortable: true },
  { key: 'target_type', name: 'HEDEF TİP', sortable: true },
  { key: 'target_id', name: 'HEDEF ID' },
  { key: 'created_at', name: 'TARİH', sortable: true },
]
</script>

<template>
  <extable
    api-url="admin/audit-logs"
    :columns="columns"
    :create-button="false"
    :form="form"
    :table-actions="false"
    :actions-column="false"
    @update:form="v => form = v"
  />
</template>
