<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

interface FoodCategory {
  id: number
  key: string
  name: string
  image_url?: string | null
}

const tableRef = ref()
const form = ref<any>({})
const isCreate = ref(false)

const columns: ITableColumn[] = [
  { key: 'image_url', name: 'GÖRSEL' },
  { key: 'name', name: 'AD', sortable: true },
]

// ── Kategori görseli ─────────────────────────────────────────────────────────

const imageFile = ref<File | null>(null)
const imageUploading = ref(false)

// Seçilen dosyanın önizlemesi; kaydedilmiş görselden önce gösterilir.
const imagePreview = ref<string | null>(null)

watch(imageFile, file => {
  if (imagePreview.value)
    URL.revokeObjectURL(imagePreview.value)

  imagePreview.value = file ? URL.createObjectURL(file) : null
})

onBeforeUnmount(() => {
  if (imagePreview.value)
    URL.revokeObjectURL(imagePreview.value)
})

// Hata mesajını döndürür (yoksa null) — çağıran taraf nasıl göstereceğine karar verir.
async function uploadImage(): Promise<string | null> {
  if (!imageFile.value || !form.value.id)
    return null

  imageUploading.value = true

  const fd = new FormData()

  fd.append('image', imageFile.value)

  const [error, data] = await ApiService.post<{ image_url: string }>(
    `admin/food-categories/${form.value.id}/image`,
    fd,
  )

  imageUploading.value = false
  if (error)
    return error

  form.value.image_url = data?.image_url ?? form.value.image_url
  imageFile.value = null

  return null
}

// Düzenleme modalındaki "Yükle" butonu — anında yükler ve sonucu bildirir.
async function uploadImageNow() {
  const error = await uploadImage()
  if (error)
    return ErrorPopup(error)

  SuccessToast()
  tableRef.value?.refresh?.()
}

// ── Kategori CRUD ────────────────────────────────────────────────────────────

function openCreate() {
  isCreate.value = true
  form.value = { name: '' }
  imageFile.value = null
  tableRef.value?.openCreateModal?.()
}

function openEdit(row: FoodCategory) {
  isCreate.value = false
  form.value = { ...row }
  imageFile.value = null
  tableRef.value?.openEditModal?.()
}

async function onSubmit() {
  const payload = { name: form.value.name }

  if (isCreate.value) {
    const [error, data] = await ApiService.post<FoodCategory>('admin/food-categories', payload)
    if (error)
      return error

    form.value.id = data?.id

    // Görsel yalnızca kategori oluştuktan sonra yüklenebilir (endpoint id istiyor).
    // Yükleme başarısız olsa da kategori korunur; admin düzenlemeden tekrar deneyebilir.
    if (imageFile.value && form.value.id) {
      const uploadError = await uploadImage()
      if (uploadError)
        ErrorPopup(`Kategori oluşturuldu ancak görsel yüklenemedi: ${uploadError}`)
    }

    return null
  }

  const [error] = await ApiService.put(`admin/food-categories/${form.value.id}`, payload)

  return error
}

async function onDelete(row: FoodCategory) {
  const c = await WarningPopup('Kategori silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/food-categories/${row.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}
</script>

<template>
  <Extable
    ref="tableRef"
    api-url="admin/food-categories"
    :columns="columns"
    :create-button="false"
    action-bar
    :form="form"
    form-title="Yemek Kategorisi"
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
        Kategori Ekle
      </VBtn>
    </template>
    <template #image_url="{ row }">
      <VImg
        v-if="row.image_url"
        :src="row.image_url"
        width="48"
        height="48"
        cover
        class="rounded"
      />
      <VAvatar
        v-else
        size="48"
        rounded
        color="grey-lighten-2"
      >
        <VIcon
          icon="tabler-photo-off"
          size="20"
        />
      </VAvatar>
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
          color="error"
        />
      </VBtn>
    </template>
    <template #modalBody="{ iscreateform }">
      <VTextField
        v-model="form.name"
        label="Ad"
        class="mb-3"
      />

      <div class="d-flex align-center gap-3 mb-5">
        <VImg
          v-if="imagePreview || form.image_url"
          :src="imagePreview || form.image_url"
          width="64"
          height="64"
          cover
          class="rounded flex-grow-0"
        />
        <VAvatar
          v-else
          size="64"
          rounded
          color="grey-lighten-2"
        >
          <VIcon
            icon="tabler-photo-off"
            size="24"
          />
        </VAvatar>
        <VFileInput
          v-model="imageFile"
          label="Kategori Görseli"
          accept="image/*"
          prepend-icon="tabler-camera"
          density="compact"
          hide-details
          class="flex-grow-1"
        />
        <!--
          Ekleme sırasında kategori henüz oluşmadığı için görsel Kaydet ile
          birlikte yüklenir; düzenlemede anında yüklenebilir.
        -->
        <VBtn
          v-if="!iscreateform"
          :loading="imageUploading"
          :disabled="!imageFile"
          color="primary"
          variant="tonal"
          @click="uploadImageNow"
        >
          Yükle
        </VBtn>
      </div>

      <VDivider class="mb-4" />

      <VBtn
        type="submit"
        :loading="imageUploading"
        block
        color="primary"
      >
        Kaydet
      </VBtn>
    </template>
  </Extable>
</template>
