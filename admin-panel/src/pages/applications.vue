<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const tableRef = ref()
const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'user_name', name: 'KULLANICI', sortable: true },
  { key: 'user_email', name: 'E-POSTA', sortable: true },
  { key: 'city', name: 'ŞEHİR', sortable: true },
  { key: 'status', name: 'DURUM', sortable: true },
  { key: 'created_at', name: 'BAŞVURU TARİHİ', sortable: true, type: 'datetime' },
]

async function action(url: string, row: any, confirmText: string) {
  const c = await WarningPopup(confirmText, 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put(`admin/applications/${row.id}${url}`, {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <Extable
    ref="tableRef"
    api-url="admin/applications"
    :columns="columns"
    :create-button="false"
    :form="form"
    :table-actions="false"
    @update:form="v => form = v"
  >
    <template #status="{ row }">
      <VChip size="small">
        {{ row.status }}
      </VChip>
    </template>
    <template #actions="{ row }">
      <VBtn
        icon
        size="small"
        variant="text"
        color="success"
        @click="action('/approve', row, 'Başvuru onaylansın mı?')"
      >
        <VIcon
          icon="tabler-check"
          size="22"
        />
      </VBtn>
      <VBtn
        icon
        size="small"
        variant="text"
        color="warning"
        @click="action('/reject', row, 'Başvuru reddedilsin mi?')"
      >
        <VIcon
          icon="tabler-x"
          size="22"
        />
      </VBtn>
    </template>
  </Extable>
</template>
