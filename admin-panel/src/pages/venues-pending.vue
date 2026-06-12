<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { SuccessToast, WarningPopup, ErrorPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const tableRef = ref()
const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'name', name: 'AD', sortable: true },
  { key: 'city', name: 'ŞEHİR', sortable: true },
]

async function action(url: string, row: any, confirmText: string) {
  const c = await WarningPopup(confirmText, 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put('admin/venues/' + row.id + url, {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <extable
    ref="tableRef"
    api-url="admin/venues/pending"
    :columns="columns"
    :create-button="false"
    :form="form"
    :table-actions="false"
    @update:form="v => form = v"
  >
    <template #actions="{ row }">
      <VBtn icon size="small" variant="text" color="success" @click="action('/approve', row, 'Onaylansın mı?')">
        <VIcon icon="tabler-check" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" color="warning" @click="action('/reject', row, 'Reddedilsin mi?')">
        <VIcon icon="tabler-x" size="22" />
      </VBtn>
    </template>
  </extable>
</template>
