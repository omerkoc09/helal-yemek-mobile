<script setup lang="ts">
import { useRouter } from 'vue-router'
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'
import { CITY_CENTROID } from '@/utils/turkeyPlates'

definePage({ meta: { role: ['admin'] } })

const router = useRouter()
const tableRef = ref()
const form = ref<any>({})
const isCreate = ref(false)

// Kanonik 81 il (backend cities.go TurkishCities ile birebir) — rehber şehri seçimi için.
const cities = Object.keys(CITY_CENTROID).sort((a, b) => a.localeCompare(b, 'tr'))

const columns: ITableColumn[] = [
  { key: 'email', name: 'E-POSTA', sortable: true },
  { key: 'name', name: 'AD', sortable: true },
  { key: 'surname', name: 'SOYAD', sortable: true },
  { key: 'phone', name: 'TELEFON' },
  { key: 'role', name: 'ROL', sortable: true },
  { key: 'is_active', name: 'AKTİF' },
  { key: 'created_at', name: 'KAYIT TARİHİ', sortable: true, type: 'date' },
]

const roles = [
  { title: 'Gezgin', value: 'traveler' },
  { title: 'Rehber', value: 'guide' },
  { title: 'Admin', value: 'admin' },
]

async function onSubmit() {
  if (isCreate.value) {
    const createPayload: Record<string, any> = {
      name: form.value.name,
      surname: form.value.surname,
      phone: form.value.phone,
      email: form.value.email,
      password: form.value.password,
      role: form.value.role || 'traveler',
    }

    // Rehber şehri yalnızca rol "guide" iken gönderilir.
    if (form.value.role === 'guide' && form.value.guide_city)
      createPayload.guide_city = form.value.guide_city

    const [error] = await ApiService.post('admin/users', createPayload)

    return error
  }

  const [error] = await ApiService.put(`admin/users/${form.value.id}`, {
    name: form.value.name,
    surname: form.value.surname,
    phone: form.value.phone,
    email: form.value.email,
    role: form.value.role,
    is_active: form.value.is_active,
  })

  return error
}

function openCreate() {
  isCreate.value = true
  form.value = { role: 'traveler', is_active: true }
  tableRef.value?.openCreateModal?.()
}

function openEdit(row: any) {
  isCreate.value = false
  form.value = { ...row }
  tableRef.value?.openEditModal?.()
}

async function onDelete(row: any) {
  const c = await WarningPopup('Kullanıcı silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/users/${row.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <Extable
    ref="tableRef"
    api-url="admin/users"
    :columns="columns"
    :create-button="false"
    action-bar
    :form="form"
    form-title="Kullanıcı"
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
        Kullanıcı Ekle
      </VBtn>
    </template>
    <template #role="{ row }">
      <VChip
        size="small"
        :color="row.role === 'admin' ? 'error' : row.role === 'guide' ? 'warning' : 'default'"
      >
        {{ row.role }}
      </VChip>
    </template>
    <template #is_active="{ row }">
      <VIcon
        :icon="row.is_active ? 'tabler-circle-check' : 'tabler-circle-x'"
        :color="row.is_active ? 'success' : 'error'"
      />
    </template>
    <template #actions="{ row }">
      <VBtn
        icon
        size="small"
        variant="text"
        @click="router.push(`/users/${row.id}`)"
      >
        <VIcon
          icon="tabler-eye"
          size="22"
        />
      </VBtn>
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
          color="error"
        />
      </VBtn>
    </template>
    <template #modalBody="{ iscreateform }">
      <VTextField
        v-model="form.email"
        label="E-posta"
        class="mb-3"
      />
      <VTextField
        v-if="iscreateform"
        v-model="form.password"
        label="Şifre"
        type="password"
        class="mb-3"
      />
      <VTextField
        v-model="form.name"
        label="Ad"
        class="mb-3"
      />
      <VTextField
        v-model="form.surname"
        label="Soyad"
        class="mb-3"
      />
      <VTextField
        v-model="form.phone"
        label="Telefon"
        class="mb-3"
      />
      <VSelect
        v-model="form.role"
        :items="roles"
        label="Rol"
        class="mb-3"
      />
      <VAutocomplete
        v-if="iscreateform && form.role === 'guide'"
        v-model="form.guide_city"
        :items="cities"
        label="Rehber Şehri"
        clearable
        class="mb-3"
      />
      <VSwitch
        v-if="!iscreateform"
        v-model="form.is_active"
        label="Aktif"
        class="mb-3"
      />
      <VBtn
        type="submit"
        block
        color="primary"
      >
        Kaydet
      </VBtn>
    </template>
  </extable>
</template>
