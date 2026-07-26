<script setup lang="ts">
import { useRouter } from 'vue-router'
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import type { ITableColumn } from '@/model/table'

definePage({ meta: { role: ['admin'] } })

const router = useRouter()
const tableRef = ref()
const form = ref<any>({})
const isCreate = ref(false)

const columns: ITableColumn[] = [
  { key: 'name', name: 'AD', sortable: true },
  { key: 'city', name: 'ŞEHİR', sortable: true },
  { key: 'district', name: 'İLÇE', sortable: true },
  { key: 'status', name: 'DURUM', sortable: true },
  { key: 'average_rating', name: 'PUAN', sortable: true },
  { key: 'review_count', name: 'YORUM', sortable: true },
  { key: 'added_by_name', name: 'EKLEYEN', sortable: true },
  { key: 'photos', name: 'FOTO' },
  { key: 'location', name: 'KONUM' },
  { key: 'created_at', name: 'EKLENME', sortable: true },
]

// Mekanın Google Maps konum bağlantısını üretir.
// google_place_id varsa doğrudan mekan sayfasına, yoksa koordinata gider.
function mapsUrl(row: any): string | null {
  if (row.google_place_id)
    return `https://www.google.com/maps/place/?q=place_id:${row.google_place_id}`
  if (row.latitude && row.longitude)
    return `https://www.google.com/maps/search/?api=1&query=${row.latitude},${row.longitude}`

  return null
}

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

// Düzenleme modalı seçenekleri
const editStatusOptions = [
  { title: 'Bekleyen', value: 'pending' },
  { title: 'Onaylı', value: 'approved' },
  { title: 'Reddedilen', value: 'rejected' },
]

const halalModeOptions = [
  { title: 'Tüm mutfaklar tavsiye edilir', value: 'all' },
  { title: 'Belirli ürünler hariç caiz', value: 'except' },
]

interface CriteriaOption { id: number; name: string }
interface FoodCategory { id: number; name: string }

// Konum önizleme akışı (mobildeki link-parse mantığının web karşılığı)
interface LocationPreview {
  latitude: number
  longitude: number
  place_id: string
  name?: string
  city?: string
  district?: string
  photo_urls?: string[]
}

const locationPreview = ref<LocationPreview | null>(null)
const previewLoading = ref(false)

const criteriaOptions = ref<CriteriaOption[]>([])
const foodCategories = ref<FoodCategory[]>([])

async function loadLookups() {
  if (!criteriaOptions.value.length) {
    const [, data] = await ApiService.get<CriteriaOption[]>('criteria')

    criteriaOptions.value = data ?? []
  }
  if (!foodCategories.value.length) {
    const [, data] = await ApiService.get<FoodCategory[]>('food-categories')

    foodCategories.value = data ?? []
  }
}

function isCategorySelected(id: number): boolean {
  return (form.value.category_ids ?? []).includes(id)
}

function toggleCategory(id: number) {
  const ids: number[] = form.value.category_ids ?? []

  form.value.category_ids = ids.includes(id)
    ? ids.filter(x => x !== id)
    : [...ids, id]
}

function applyStatusFilter() {
  if (statusFilter.value)
    tableRef.value?.refresh?.({ query: [statusFilter.value], columns: ['status'], columnTypes: [] })
  else
    tableRef.value?.refresh?.({ query: [], columns: [], columnTypes: [] })
}

// Aksiyon butonlarının görünürlüğü backend ön-koşullarıyla birebir eşleşir
// (venue_status_repo.go): Approve → pending|rejected, Reject → pending,
// ReactivateVenue → suspended. Aksi durumda backend "bulunamadı" döndüğünden
// kullanıcıya işe yaramayacak buton gösterilmez.
function canApprove(row: any): boolean {
  return row.status === 'pending' || row.status === 'rejected'
}

function canReject(row: any): boolean {
  return row.status === 'pending'
}

function canReactivate(row: any): boolean {
  return row.status === 'suspended'
}

async function action(url: string, row: any, confirmText: string) {
  const c = await WarningPopup(confirmText, 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put(`admin/venues/${row.id}${url}`, {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}

async function onDelete(row: any) {
  const c = await WarningPopup('Mekan silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`admin/venues/${row.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  tableRef.value?.refresh?.()
}

async function openCreate() {
  await loadLookups()
  isCreate.value = true
  locationPreview.value = null
  form.value = {
    name: '',
    city: '',
    district: '',
    notes: '',
    status: 'pending',
    food_halal_mode: 'all',
    criteria_ids: [],
    category_ids: [],
    excluded_products_text: '',
    maps_link: '',
  }
  tableRef.value?.openCreateModal?.()
}

async function openEdit(row: any) {
  isCreate.value = false
  loadLookups()
  locationPreview.value = null

  // Liste sorgusu (FindAll) criteria/categories/food_halal_mode getirmiyor;
  // tam veriyi tekil detay endpoint'inden çekip işaretli gösteriyoruz.
  const [, detail] = await ApiService.get<any>(`venues/${row.id}`)
  const venue = detail ?? row

  form.value = {
    ...venue,
    criteria_ids: (venue.criteria ?? []).map((c: any) => c.id),
    category_ids: (venue.categories ?? []).map((c: any) => c.id),
    excluded_products_text: (venue.excluded_products ?? []).join(', '),
    maps_link: '',
  }
  tableRef.value?.openEditModal?.()
}

const photoFile = ref<File | null>(null)
const photoUploading = ref(false)

async function uploadPhoto() {
  if (!photoFile.value || !form.value.id)
    return

  photoUploading.value = true

  const fd = new FormData()

  fd.append('photo', photoFile.value)

  const [error, data] = await ApiService.post<{ url: string }>(
    `venues/${form.value.id}/photos`,
    fd,
  )

  photoUploading.value = false
  if (error)
    return ErrorPopup(error)

  // Modaldaki önizlemeyi ve tablodaki satırı güncel tut
  form.value.photos = data?.url ? [{ url: data.url }] : []
  photoFile.value = null
  SuccessToast()
  tableRef.value?.refresh?.()
}

async function previewLocation() {
  const link = (form.value.maps_link ?? '').trim()
  if (!link)
    return

  previewLoading.value = true
  locationPreview.value = null

  const [error, data] = await ApiService.post<LocationPreview>(
    'venues/preview-location',
    { maps_link: link },
  )

  previewLoading.value = false
  if (error)
    return ErrorPopup(error)

  locationPreview.value = data ?? null
}

// Önizlemeyi onayla: çıkan bilgileri forma uygula (boş gelenler korunur).
// maps_link temizlenir; kaydederken doğrudan parse edilmiş değerler gönderilir
// (backend'in linki ikinci kez parse etmesine gerek kalmaz).
function applyPreview() {
  const p = locationPreview.value
  if (!p)
    return

  form.value.latitude = p.latitude
  form.value.longitude = p.longitude
  form.value.google_place_id = p.place_id || null
  if (p.name)
    form.value.name = p.name
  if (p.city)
    form.value.city = p.city
  if (p.district)
    form.value.district = p.district

  form.value.maps_link = ''
  form.value._locationApplied = true
  locationPreview.value = null
  SuccessToast()
}

// Sakıncalı ürünler yalnızca 'except' modunda anlamlı; virgülle ayrılmış metni
// temizlenmiş bir diziye çevirir.
function parseExcludedProducts(): string[] {
  if (form.value.food_halal_mode !== 'except')
    return []

  return (form.value.excluded_products_text ?? '')
    .split(',')
    .map((s: string) => s.trim())
    .filter(Boolean)
}

async function onSubmit() {
  const payload: Record<string, any> = {
    name: form.value.name,
    city: form.value.city,
    district: form.value.district,
    notes: form.value.notes,
    status: form.value.status,
    food_halal_mode: form.value.food_halal_mode,
    criteria_ids: form.value.criteria_ids ?? [],
    category_ids: form.value.category_ids ?? [],
    excluded_products: parseExcludedProducts(),
  }

  const mapsLink = (form.value.maps_link ?? '').trim()
  if (form.value._locationApplied) {
    payload.latitude = form.value.latitude
    payload.longitude = form.value.longitude
    payload.google_place_id = form.value.google_place_id ?? null
  }
  else if (mapsLink) {
    payload.maps_link = mapsLink
  }

  if (isCreate.value) {
    const [error] = await ApiService.post('venues', payload)

    return error
  }

  const [error] = await ApiService.put(`admin/venues/${form.value.id}`, payload)

  return error
}
</script>

<template>
  <Extable
    ref="tableRef"
    api-url="admin/venues"
    :columns="columns"
    :create-button="false"
    action-bar
    :form="form"
    form-title="Mekan"
    :table-actions="false"
    :on-submit="onSubmit"
    @update:form="(v: any) => form = v"
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
      <VBtn
        color="primary"
        prepend-icon="tabler-plus"
        class="ms-3"
        @click="openCreate"
      >
        Mekan Ekle
      </VBtn>
    </template>
    <template #status="{ row }">
      <VChip
        size="small"
        :color="row.status === 'approved' ? 'success' : row.status === 'pending' ? 'warning' : 'default'"
      >
        {{ row.status }}
      </VChip>
    </template>
    <template #district="{ row }">
      {{ row.district || '-' }}
    </template>
    <template #average_rating="{ row }">
      <span v-if="row.review_count > 0">
        <VIcon
          icon="tabler-star-filled"
          size="16"
          color="warning"
          class="me-1"
        />{{ row.average_rating?.toFixed(1) }}
      </span>
      <span
        v-else
        class="text-disabled"
      >-</span>
    </template>
    <template #review_count="{ row }">
      {{ row.review_count ?? 0 }}
    </template>
    <template #added_by_name="{ row }">
      <div>
        <div>{{ [row.added_by_name, row.added_by_surname].filter(Boolean).join(' ') || '-' }}</div>
        <div
          v-if="row.added_by_email"
          class="text-caption text-disabled"
        >
          {{ row.added_by_email }}
        </div>
      </div>
    </template>
    <template #photos="{ row }">
      <VImg
        v-if="row.photos?.length"
        :src="row.photos[0].url"
        :alt="row.name"
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
    <template #location="{ row }">
      <VBtn
        v-if="mapsUrl(row)"
        :href="mapsUrl(row)!"
        target="_blank"
        rel="noopener noreferrer"
        size="small"
        variant="tonal"
        color="primary"
        prepend-icon="tabler-map-pin"
      >
        Haritada Aç
      </VBtn>
      <span
        v-else
        class="text-disabled"
      >-</span>
    </template>
    <template #created_at="{ row }">
      {{ formatDate(row.created_at) }}
    </template>
    <template #actions="{ row }">
      <VBtn
        icon
        size="small"
        variant="text"
        @click="router.push(`/venues/${row.id}`)"
      >
        <VIcon
          icon="tabler-eye"
          size="22"
        />
      </VBtn>
      <VBtn
        v-if="canApprove(row)"
        icon
        size="small"
        variant="text"
        color="success"
        @click="action('/approve', row, 'Onaylansın mı?')"
      >
        <VIcon
          icon="tabler-check"
          size="22"
        />
        <VTooltip
          activator="parent"
          location="top"
        >
          Onayla
        </VTooltip>
      </VBtn>
      <VBtn
        v-if="canReject(row)"
        icon
        size="small"
        variant="text"
        color="warning"
        @click="action('/reject', row, 'Reddedilsin mi?')"
      >
        <VIcon
          icon="tabler-x"
          size="22"
        />
        <VTooltip
          activator="parent"
          location="top"
        >
          Reddet
        </VTooltip>
      </VBtn>
      <VBtn
        v-if="canReactivate(row)"
        icon
        size="small"
        variant="text"
        @click="action('/reactivate', row, 'Yeniden aktive edilsin mi?')"
      >
        <VIcon
          icon="tabler-refresh"
          size="22"
        />
        <VTooltip
          activator="parent"
          location="top"
        >
          Yeniden Aktive Et
        </VTooltip>
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
    <template #modalBody>
      <VRow>
        <VCol
          cols="12"
          md="6"
        >
          <VTextField
            v-model="form.name"
            label="Ad"
            class="mb-3"
          />
        </VCol>
        <VCol
          cols="12"
          md="6"
        >
          <VTextField
            v-model="form.city"
            label="Şehir"
            class="mb-3"
          />
        </VCol>
        <VCol
          cols="12"
          md="6"
        >
          <VTextField
            v-model="form.district"
            label="İlçe"
            class="mb-3"
          />
        </VCol>
        <VCol
          cols="12"
          md="6"
        >
          <VSelect
            v-model="form.status"
            :items="editStatusOptions"
            label="Durum"
            class="mb-3"
          />
        </VCol>
        <VCol cols="12">
          <VTextarea
            v-model="form.notes"
            label="Notlar"
            rows="2"
            auto-grow
            class="mb-3"
          />
        </VCol>
        <VCol cols="12">
          <div class="d-flex align-center gap-2 mb-1">
            <span class="text-body-2 text-medium-emphasis">Konum</span>
            <VBtn
              v-if="mapsUrl(form)"
              :href="mapsUrl(form)!"
              target="_blank"
              rel="noopener noreferrer"
              size="x-small"
              variant="tonal"
              color="primary"
              prepend-icon="tabler-map-pin"
            >
              Mevcut konumu aç
            </VBtn>
            <span
              v-else
              class="text-caption text-disabled"
            >Konum bilgisi yok</span>
          </div>
          <div class="d-flex gap-2 align-start">
            <VTextField
              v-model="form.maps_link"
              label="Google Maps Linki (konumu güncellemek için)"
              placeholder="https://maps.app.goo.gl/... veya tam Google Maps linki"
              prepend-inner-icon="tabler-link"
              clearable
              hint="Linki yapıştırıp Önizle'ye basın; mekan bilgileri Google'dan çekilir."
              persistent-hint
              class="flex-grow-1"
            />
            <VBtn
              :loading="previewLoading"
              :disabled="!form.maps_link"
              color="primary"
              variant="tonal"
              class="mt-1"
              prepend-icon="tabler-eye"
              @click="previewLocation"
            >
              Önizle
            </VBtn>
          </div>

          <!-- Önizleme kartı: linkten çözülen mekan bilgileri -->
          <VCard
            v-if="locationPreview"
            variant="tonal"
            color="primary"
            class="mt-3"
          >
            <VCardText class="d-flex align-center gap-3">
              <VImg
                v-if="locationPreview.photo_urls?.length"
                :src="locationPreview.photo_urls[0]"
                width="64"
                height="64"
                cover
                class="rounded flex-grow-0"
              />
              <VIcon
                v-else
                icon="tabler-map-pin"
                size="40"
              />
              <div class="flex-grow-1">
                <div class="text-subtitle-2">
                  {{ locationPreview.name || 'İsim bulunamadı' }}
                </div>
                <div class="text-caption">
                  {{ [locationPreview.district, locationPreview.city].filter(Boolean).join(', ') || 'Konum bilgisi Google\'dan çekilemedi' }}
                </div>
                <div class="text-caption text-disabled">
                  {{ locationPreview.latitude.toFixed(6) }}, {{ locationPreview.longitude.toFixed(6) }}
                  <span v-if="locationPreview.place_id"> · Google kaydı bulundu ✓</span>
                </div>
              </div>
              <VBtn
                color="primary"
                variant="flat"
                prepend-icon="tabler-check"
                @click="applyPreview"
              >
                Uygula
              </VBtn>
            </VCardText>
          </VCard>
        </VCol>
        <VCol cols="12">
          <VSelect
            v-model="form.food_halal_mode"
            :items="halalModeOptions"
            label="Helal Modu"
            class="mb-3"
          />
        </VCol>
        <VCol
          v-if="form.food_halal_mode === 'except'"
          cols="12"
        >
          <VTextField
            v-model="form.excluded_products_text"
            label="Sakıncalı Ürünler (virgülle ayırın)"
            placeholder="alkol, jelatin"
            class="mb-3"
          />
        </VCol>
        <VCol cols="12">
          <div class="d-flex align-center gap-3 mb-3">
            <VImg
              v-if="form.photos?.length"
              :src="form.photos[0].url"
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
              v-model="photoFile"
              label="Kapak Fotoğrafı"
              accept="image/*"
              prepend-icon="tabler-camera"
              density="compact"
              hide-details
              class="flex-grow-1"
            />
            <VBtn
              :loading="photoUploading"
              :disabled="!photoFile"
              color="primary"
              variant="tonal"
              @click="uploadPhoto"
            >
              Yükle
            </VBtn>
          </div>
        </VCol>
        <VCol cols="12">
          <VSelect
            v-model="form.criteria_ids"
            :items="criteriaOptions"
            item-title="name"
            item-value="id"
            label="Helal Kriterleri"
            multiple
            chips
            closable-chips
            class="mb-3"
          />
        </VCol>
        <VCol cols="12">
          <label class="text-body-2 text-medium-emphasis d-block mb-1">Mutfak Kategorileri</label>
          <VCard
            variant="outlined"
            class="mb-3 pa-3"
          >
            <div class="d-flex flex-wrap gap-2">
              <VChip
                v-for="cat in foodCategories"
                :key="cat.id"
                :color="isCategorySelected(cat.id) ? 'primary' : undefined"
                :variant="isCategorySelected(cat.id) ? 'flat' : 'outlined'"
                filter
                :model-value="isCategorySelected(cat.id)"
                @click="toggleCategory(cat.id)"
              >
                {{ cat.name }}
              </VChip>
            </div>
          </VCard>
        </VCol>
      </VRow>
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
