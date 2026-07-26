<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

interface TrustCriteria {
  id: number
  key: string
  name: string
  description?: string | null
}

const tableRef = ref()
const form = ref<any>({})
const isCreate = ref(false)

const columns: ITableColumn[] = [
  { key: 'name', name: 'AD', sortable: true },
  { key: 'key', name: 'ANAHTAR' },
  { key: 'description', name: 'AÇIKLAMA' },
]

function openCreate() {
  isCreate.value = true
  form.value = { name: '', description: '' }
  tableRef.value?.openCreateModal?.()
}

function openEdit(row: TrustCriteria) {
  isCreate.value = false
  form.value = { ...row }
  tableRef.value?.openEditModal?.()
}

async function onSubmit() {
  const payload = {
    name: form.value.name,
    description: form.value.description || null,
  }

  if (isCreate.value) {
    const [error, data] = await ApiService.post<TrustCriteria>('admin/trust-criteria', payload)
    if (error)
      return error

    form.value.id = data?.id

    return null
  }

  const [error] = await ApiService.put(`admin/trust-criteria/${form.value.id}`, payload)

  return error
}

async function onDelete(row: TrustCriteria) {
  const c = await WarningPopup(
    `"${row.name}" kriteri silinsin mi? Bu kritere yapılmış mekan işaretlemeleri de kaldırılır.`,
    'Evet',
    'Hayır',
  )
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/trust-criteria/${row.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <Extable
    ref="tableRef"
    api-url="admin/trust-criteria"
    :columns="columns"
    :create-button="false"
    action-bar
    :form="form"
    form-title="Güven Kriteri"
    :table-actions="false"
    actions-column
    :on-submit="onSubmit"
    @update:form="(v: any) => form = v"
  >
    <template #actionBar>
      <VBtn
        color="primary"
        prepend-icon="tabler-plus"
        @click="openCreate"
      >
        Kriter Ekle
      </VBtn>
    </template>
    <template #description="{ row }">
      <span class="text-body-2 text-medium-emphasis">{{ row.description || '—' }}</span>
    </template>
    <template #actions="{ row }">
      <VBtn
        icon
        size="small"
        variant="text"
        @click="openEdit(row)"
      >
        <VIcon
          icon="tabler-edit"
          size="22"
        />
      </VBtn>
      <VBtn
        icon
        size="small"
        variant="text"
        @click="onDelete(row)"
      >
        <VIcon
          icon="tabler-trash"
          size="22"
        />
      </VBtn>
    </template>
    <template #modalBody="{ iscreateform }">
      <VTextField
        v-model="form.name"
        label="Ad"
        class="mb-3"
      />
      <VTextField
        v-if="!iscreateform"
        :model-value="form.key"
        label="Anahtar (otomatik)"
        readonly
        disabled
        class="mb-3"
      />
      <VTextarea
        v-model="form.description"
        label="Açıklama"
        rows="3"
        class="mb-3"
      />
    </template>
  </Extable>
</template>
