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
  { key: 'district', name: 'İLÇE', sortable: true },
  { key: 'status', name: 'DURUM', sortable: true },
  { key: 'average_rating', name: 'PUAN', sortable: true },
  { key: 'review_count', name: 'YORUM', sortable: true },
  { key: 'added_by_name', name: 'EKLEYEN', sortable: true },
  { key: 'photos', name: 'FOTO' },
  { key: 'created_at', name: 'EKLENME', sortable: true },
]

function formatDate(v?: string) {
  if (!v)
    return '-'

  return new Date(v).toLocaleDateString('tr-TR', { year: 'numeric', month: '2-digit', day: '2-digit' })
}

const statusFilter = ref<string | null>(null)
const statusOptions = [
  { title: 'Tümü', value: null },
  { title: 'Bekleyen', value: 'pending' },
  { title: 'Onaylı', value: 'approved' },
  { title: 'Reddedilen', value: 'rejected' },
  { title: 'Askıda', value: 'suspended' },
]

function applyStatusFilter() {
  if (statusFilter.value)
    tableRef.value?.refresh?.({ query: [statusFilter.value], columns: ['status'], columnTypes: [] })
  else
    tableRef.value?.refresh?.({ query: [], columns: [], columnTypes: [] })
}

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
    :action-bar="true"
    :form="form"
    form-title="Mekan"
    :table-actions="false"
    :on-submit="onSubmit"
    @update:form="v => form = v"
  >
    <template #actionBar>
      <VSelect
        v-model="statusFilter"
        :items="statusOptions"
        label="Durum"
        density="compact"
        variant="outlined"
        style="max-inline-size: 200px;"
        @update:model-value="applyStatusFilter"
      />
    </template>
    <template #status="{ row }">
      <VChip size="small" :color="row.status === 'approved' ? 'success' : row.status === 'pending' ? 'warning' : 'default'">
        {{ row.status }}
      </VChip>
    </template>
    <template #district="{ row }">
      {{ row.district || '-' }}
    </template>
    <template #average_rating="{ row }">
      <span v-if="row.review_count > 0">
        <VIcon icon="tabler-star-filled" size="16" color="warning" class="me-1" />{{ row.average_rating?.toFixed(1) }}
      </span>
      <span v-else class="text-disabled">-</span>
    </template>
    <template #review_count="{ row }">
      {{ row.review_count ?? 0 }}
    </template>
    <template #added_by_name="{ row }">
      <div>
        <div>{{ row.added_by_name || '-' }}</div>
        <div v-if="row.added_by_email" class="text-caption text-disabled">{{ row.added_by_email }}</div>
      </div>
    </template>
    <template #photos="{ row }">
      <VChip size="x-small" variant="tonal">
        <VIcon icon="tabler-photo" size="14" class="me-1" />{{ row.photos?.length ?? 0 }}
      </VChip>
    </template>
    <template #created_at="{ row }">
      {{ formatDate(row.created_at) }}
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
      <VBtn type="submit" block color="primary">Kaydet</VBtn>
    </template>
  </extable>
</template>
