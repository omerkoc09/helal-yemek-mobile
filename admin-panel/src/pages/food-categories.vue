<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

interface FoodItem {
  id: number
  category_id: number
  key: string
  name: string
  is_custom: boolean
}

interface FoodCategory {
  id: number
  key: string
  name: string
  image_url?: string | null
  items: FoodItem[]
}

const tableRef = ref()
const form = ref<any>({})
const isCreate = ref(false)

const columns: ITableColumn[] = [
  { key: 'image_url', name: 'GÖRSEL' },
  { key: 'name', name: 'AD', sortable: true },
  { key: 'items', name: 'ALT ÇEŞİTLER' },
]

function openCreate() {
  isCreate.value = true
  form.value = { name: '' }
  tableRef.value?.openCreateModal?.()
}

async function openEdit(row: FoodCategory) {
  isCreate.value = false
  form.value = { ...row, items: [...(row.items ?? [])] }
  tableRef.value?.openEditModal?.()
}

async function onSubmit() {
  const payload = { name: form.value.name }

  if (isCreate.value) {
    const [error, data] = await ApiService.post<FoodCategory>('admin/food-categories', payload)
    if (error)
      return error

    form.value.id = data?.id

    return null
  }

  const [error] = await ApiService.put(`admin/food-categories/${form.value.id}`, payload)

  return error
}

async function onDelete(row: FoodCategory) {
  const c = await WarningPopup('Kategori ve tüm alt çeşitleri silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/food-categories/${row.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}

// ── Kategori görseli ─────────────────────────────────────────────────────────

const imageFile = ref<File | null>(null)
const imageUploading = ref(false)

async function uploadImage() {
  if (!imageFile.value || !form.value.id)
    return

  imageUploading.value = true

  const fd = new FormData()

  fd.append('image', imageFile.value)

  const [error, data] = await ApiService.post<{ image_url: string }>(
    `admin/food-categories/${form.value.id}/image`,
    fd,
  )

  imageUploading.value = false
  if (error)
    return ErrorPopup(error)

  form.value.image_url = data?.image_url ?? form.value.image_url
  imageFile.value = null
  SuccessToast()
  tableRef.value?.refresh?.()
}

// ── Alt çeşitler (food_items) ────────────────────────────────────────────────

const newItemName = ref('')
const itemSaving = ref(false)
const editingItemId = ref<number | null>(null)
const editingItemName = ref('')

async function addItem() {
  const name = (newItemName.value ?? '').trim()
  if (!name || !form.value.id)
    return

  itemSaving.value = true

  const [error, data] = await ApiService.post<FoodItem>(
    `admin/food-categories/${form.value.id}/items`,
    { name },
  )

  itemSaving.value = false
  if (error)
    return ErrorPopup(error)

  if (data)
    form.value.items = [...(form.value.items ?? []), data]
  newItemName.value = ''
  tableRef.value?.refresh?.()
}

function startEditItem(item: FoodItem) {
  editingItemId.value = item.id
  editingItemName.value = item.name
}

function cancelEditItem() {
  editingItemId.value = null
}

async function saveEditItem(item: FoodItem) {
  const [error] = await ApiService.put(`admin/food-items/${item.id}`, {
    name: editingItemName.value,
  })

  if (error)
    return ErrorPopup(error)

  item.name = editingItemName.value
  editingItemId.value = null
  SuccessToast()
  tableRef.value?.refresh?.()
}

async function deleteItem(item: FoodItem) {
  const c = await WarningPopup('Alt çeşit silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/food-items/${item.id}`)
  if (error)
    return ErrorPopup(error)

  form.value.items = (form.value.items ?? []).filter((i: FoodItem) => i.id !== item.id)
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
    <template #items="{ row }">
      <VChip
        size="small"
        color="primary"
        variant="tonal"
      >
        {{ (row.items ?? []).length }} çeşit
      </VChip>
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

      <template v-if="!iscreateform">
        <div class="d-flex align-center gap-3 mb-5">
          <VImg
            v-if="form.image_url"
            :src="form.image_url"
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
          <VBtn
            :loading="imageUploading"
            :disabled="!imageFile"
            color="primary"
            variant="tonal"
            @click="uploadImage"
          >
            Yükle
          </VBtn>
        </div>

        <VDivider class="mb-4" />

        <label class="text-body-2 text-medium-emphasis d-block mb-2">Alt Çeşitler</label>
        <VList
          density="compact"
          class="mb-3"
        >
          <template
            v-for="item in form.items"
            :key="item.id"
          >
            <div
              v-if="editingItemId === item.id"
              class="d-flex align-center gap-2 w-100 py-1 px-4"
            >
              <VTextField
                v-model="editingItemName"
                label="Ad"
                density="compact"
                hide-details
              />
              <VBtn
                icon
                size="small"
                variant="text"
                color="success"
                @click="saveEditItem(item)"
              >
                <VIcon
                  icon="tabler-check"
                  size="20"
                />
              </VBtn>
              <VBtn
                icon
                size="small"
                variant="text"
                @click="cancelEditItem"
              >
                <VIcon
                  icon="tabler-x"
                  size="20"
                />
              </VBtn>
            </div>
            <VListItem v-else>
              <VListItemTitle>{{ item.name }}</VListItemTitle>
              <template #append>
                <VBtn
                  icon
                  size="small"
                  variant="text"
                  @click="startEditItem(item)"
                >
                  <VIcon
                    icon="tabler-edit"
                    size="18"
                  />
                </VBtn>
                <VBtn
                  icon
                  size="small"
                  variant="text"
                  @click="deleteItem(item)"
                >
                  <VIcon
                    icon="tabler-trash"
                    size="18"
                    color="error"
                  />
                </VBtn>
              </template>
            </VListItem>
          </template>
          <VListItem v-if="!form.items?.length">
            <span class="text-caption text-disabled">Henüz alt çeşit eklenmemiş</span>
          </VListItem>
        </VList>

        <div class="d-flex gap-2 mb-3">
          <VTextField
            v-model="newItemName"
            label="Yeni alt çeşit (ör. Et Döner)"
            density="compact"
            hide-details
            @keydown.enter.prevent="addItem"
          />
          <VBtn
            :loading="itemSaving"
            :disabled="!(newItemName ?? '').trim()"
            color="primary"
            variant="tonal"
            @click="addItem"
          >
            Ekle
          </VBtn>
        </div>

        <VDivider class="mb-4" />
      </template>

      <VBtn
        type="submit"
        block
        color="primary"
      >
        Kaydet
      </VBtn>
    </template>
  </Extable>
</template>
