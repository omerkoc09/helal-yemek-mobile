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
  { key: 'status', name: 'DURUM', sortable: true },
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

async function onDelete(row: any) {
  const c = await WarningPopup('Mekan silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete('admin/venues/' + row.id)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}

function openEdit(row: any) {
  form.value = { ...row }
  tableRef.value?.openEditModal?.()
}

async function onSubmit() {
  const [error] = await ApiService.put('admin/venues/' + form.value.id, form.value)

  return error
}
</script>

<template>
  <extable
    ref="tableRef"
    api-url="admin/venues"
    :columns="columns"
    :create-button="false"
    :form="form"
    form-title="Mekan"
    :table-actions="false"
    :on-submit="onSubmit"
    @update:form="v => form = v"
  >
    <template #status="{ row }">
      <VChip size="small" :color="row.status === 'approved' ? 'success' : row.status === 'pending' ? 'warning' : 'default'">
        {{ row.status }}
      </VChip>
    </template>
    <template #actions="{ row }">
      <VBtn icon size="small" variant="text" color="success" @click="action('/approve', row, 'Onaylansın mı?')">
        <VIcon icon="tabler-check" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" color="warning" @click="action('/reject', row, 'Reddedilsin mi?')">
        <VIcon icon="tabler-x" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" @click="action('/reactivate', row, 'Yeniden aktive edilsin mi?')">
        <VIcon icon="tabler-refresh" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" @click="openEdit(row)">
        <VIcon icon="tabler-edit" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" @click="onDelete(row)">
        <VIcon icon="tabler-trash" size="22" color="error" />
      </VBtn>
    </template>
    <template #modalBody>
      <VTextField v-model="form.name" label="Ad" class="mb-3" />
      <VTextField v-model="form.city" label="Şehir" class="mb-3" />
      <VTextField v-model="form.address" label="Adres" class="mb-3" />
      <VBtn type="submit" block color="primary">Kaydet</VBtn>
    </template>
  </extable>
</template>
