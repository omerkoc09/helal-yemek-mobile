<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { SuccessToast, WarningPopup, ErrorPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const tableRef = ref()
const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'venue_name', name: 'MEKAN', sortable: true },
  { key: 'reporter_name', name: 'BİLDİREN', sortable: true },
  { key: 'reason', name: 'SEBEP' },
  { key: 'status', name: 'DURUM', sortable: true },
  { key: 'created_at', name: 'TARİH', sortable: true },
]

async function resolve(row: any) {
  const c = await WarningPopup('Rapor çözümlensin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put('admin/venue-reports/' + row.id + '/resolve', {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <extable
    ref="tableRef"
    api-url="admin/venue-reports"
    :columns="columns"
    :create-button="false"
    :form="form"
    :table-actions="false"
    @update:form="v => form = v"
  >
    <template #status="{ row }">
      <VChip size="small" :color="row.status === 'resolved' ? 'success' : 'warning'">{{ row.status }}</VChip>
    </template>
    <template #actions="{ row }">
      <VBtn icon size="small" variant="text" color="success" @click="resolve(row)">
        <VIcon icon="tabler-checkbox" size="22" />
      </VBtn>
    </template>
  </extable>
</template>
