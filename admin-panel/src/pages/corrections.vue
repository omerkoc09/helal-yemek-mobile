<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { SuccessToast, WarningPopup, ErrorPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const tableRef = ref()
const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'venue_id', name: 'MEKAN', sortable: true },
  { key: 'field_name', name: 'ALAN', sortable: true },
  { key: 'new_value', name: 'ÖNERİ' },
  { key: 'status', name: 'DURUM', sortable: true },
]

async function review(row: any, actionType: 'approve' | 'reject', confirmText: string) {
  const c = await WarningPopup(confirmText, 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put('admin/corrections/' + row.id, { action: actionType })
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <extable
    ref="tableRef"
    api-url="admin/corrections"
    :columns="columns"
    :create-button="false"
    :form="form"
    :table-actions="false"
    @update:form="v => form = v"
  >
    <template #status="{ row }">
      <VChip size="small">{{ row.status }}</VChip>
    </template>
    <template #actions="{ row }">
      <VBtn icon size="small" variant="text" color="success" @click="review(row, 'approve', 'Düzeltme onaylansın mı?')">
        <VIcon icon="tabler-check" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" color="warning" @click="review(row, 'reject', 'Düzeltme reddedilsin mi?')">
        <VIcon icon="tabler-x" size="22" />
      </VBtn>
    </template>
  </extable>
</template>
