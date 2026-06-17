<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { SuccessToast, WarningPopup, ErrorPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const tableRef = ref()
const form = ref<any>({})

const columns: ITableColumn[] = [
  { key: 'email', name: 'E-POSTA', sortable: true },
  { key: 'name', name: 'AD', sortable: true },
  { key: 'surname', name: 'SOYAD', sortable: true },
  { key: 'phone', name: 'TELEFON' },
  { key: 'role', name: 'ROL', sortable: true },
  { key: 'referred_by_name', name: 'GETİREN' },
  { key: 'referral_count', name: 'GETİRDİĞİ', sortable: true },
  { key: 'is_active', name: 'AKTİF' },
  { key: 'created_at', name: 'KAYIT TARİHİ', sortable: true, type: 'date' },
]

const roles = [
  { title: 'Gezgin', value: 'traveler' },
  { title: 'Rehber', value: 'guide' },
  { title: 'Admin', value: 'admin' },
]

async function onSubmit() {
  const [error] = await ApiService.put('admin/users/' + form.value.id, {
    name: form.value.name,
    surname: form.value.surname,
    phone: form.value.phone,
    email: form.value.email,
    role: form.value.role,
    is_active: form.value.is_active,
  })

  return error
}

function openEdit(row: any) {
  form.value = { ...row }
  tableRef.value?.openEditModal?.()
}

async function onDelete(row: any) {
  const c = await WarningPopup('Kullanıcı silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete('admin/users/' + row.id)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <extable
    ref="tableRef"
    api-url="admin/users"
    :columns="columns"
    :create-button="false"
    :form="form"
    form-title="Kullanıcı"
    :table-actions="false"
    :actions-column="true"
    :on-submit="onSubmit"
    @update:form="v => form = v"
  >
    <template #role="{ row }">
      <VChip size="small" :color="row.role === 'admin' ? 'error' : row.role === 'guide' ? 'warning' : 'default'">
        {{ row.role }}
      </VChip>
    </template>
    <template #is_active="{ row }">
      <VIcon :icon="row.is_active ? 'tabler-circle-check' : 'tabler-circle-x'" :color="row.is_active ? 'success' : 'error'" />
    </template>
    <template #actions="{ row }">
      <VBtn icon size="small" variant="text" @click="openEdit(row)">
        <VIcon icon="tabler-edit" size="22" />
      </VBtn>
      <VBtn icon size="small" variant="text" @click="onDelete(row)">
        <VIcon icon="tabler-trash" size="22" color="error" />
      </VBtn>
    </template>
    <template #modalBody>
      <VTextField v-model="form.email" label="E-posta" class="mb-3" />
      <VTextField v-model="form.name" label="Ad" class="mb-3" />
      <VTextField v-model="form.surname" label="Soyad" class="mb-3" />
      <VTextField v-model="form.phone" label="Telefon" class="mb-3" />
      <VSelect v-model="form.role" :items="roles" label="Rol" class="mb-3" />
      <VSwitch v-model="form.is_active" label="Aktif" class="mb-3" />
      <VBtn type="submit" block color="primary">Kaydet</VBtn>
    </template>
  </extable>
</template>
