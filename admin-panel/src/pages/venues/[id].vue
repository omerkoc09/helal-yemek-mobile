<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import tarihFormat from '@/utils/ExDate'

definePage({ meta: { role: ['admin'] } })

const route = useRoute()
const router = useRouter()
const id = route.params.id as string

// ── Mekan verisi ─────────────────────────────────────────────────────────────
const venue = ref<any>(null)
const form = ref<any>({})

const editStatusOptions = [
  { title: 'Bekleyen', value: 'pending' },
  { title: 'Onaylı', value: 'approved' },
  { title: 'Reddedilen', value: 'rejected' },
]

const halalModeOptions = [
  { title: 'Tüm mutfaklar tavsiye edilir', value: 'all' },
  { title: 'Belirli ürünler hariç caiz', value: 'except' },
]

const venueStatusColor: Record<string, string> = {
  approved: 'success',
  pending: 'warning',
  rejected: 'error',
  suspended: 'default',
}

interface CriteriaOption { id: number; name: string }
interface FoodCategory { id: number; name: string }

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

function mapsUrl(v: any): string | null {
  if (!v)
    return null
  if (v.google_place_id)
    return `https://www.google.com/maps/place/?q=place_id:${v.google_place_id}`
  if (v.latitude && v.longitude)
    return `https://www.google.com/maps/search/?api=1&query=${v.latitude},${v.longitude}`

  return null
}

async function fetchVenue() {
  const [error, data] = await ApiService.get<any>(`venues/${id}`)
  if (error)
    return ErrorPopup(error)
  venue.value = data
  form.value = {
    ...data,
    criteria_ids: (data.criteria ?? []).map((c: any) => c.id),
    category_ids: (data.categories ?? []).map((c: any) => c.id),
    excluded_products_text: (data.excluded_products ?? []).join(', '),
    maps_link: '',
  }
  loadLookups()
  fetchConfirmingGuides()
}

// ── Bu dönemde doğrulayan rehberler ─────────────────────────────────────────
const confirmingGuides = ref<any[]>([])

async function fetchConfirmingGuides() {
  const [error, data] = await ApiService.get(`admin/venues/${id}/confirming-guides`)
  if (error)
    return ErrorPopup(error)
  confirmingGuides.value = data ?? []
}

function parseExcludedProducts(): string[] {
  if (form.value.food_halal_mode !== 'except')
    return []

  return (form.value.excluded_products_text ?? '')
    .split(',')
    .map((s: string) => s.trim())
    .filter(Boolean)
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

  form.value.photos = data?.url ? [{ url: data.url }] : []
  venue.value.photos = form.value.photos
  photoFile.value = null
  SuccessToast()
}

async function saveVenue() {
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

  const [error] = await ApiService.put(`admin/venues/${id}`, payload)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  await fetchVenue()
}

// ── Yorumlar ─────────────────────────────────────────────────────────────────
const reviews = ref<any[]>([])
const reviewsLoaded = ref(false)

async function fetchReviews() {
  if (reviewsLoaded.value)
    return
  const [error, data] = await ApiService.get(`venues/${id}/reviews`)
  if (error)
    return ErrorPopup(error)
  reviews.value = data ?? []
  reviewsLoaded.value = true
}

async function deleteReview(review: any) {
  const c = await WarningPopup('Yorum silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.delete(`venues/${id}/reviews/${review.id}`)
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  reviewsLoaded.value = false
  await fetchReviews()
}

// ── Doğrulama Geçmişi ────────────────────────────────────────────────────────
const verificationLogs = ref<any[]>([])
const verificationLogsLoaded = ref(false)

const verificationActionColor: Record<string, string> = {
  verified: 'success',
  warning_sent: 'warning',
}

const verificationActionLabel: Record<string, string> = {
  verified: 'Doğrulandı',
  warning_sent: 'Uyarı Gönderildi',
}

async function fetchVerificationLogs() {
  if (verificationLogsLoaded.value)
    return
  const [error, data] = await ApiService.get(`admin/venues/${id}/verification-logs`)
  if (error)
    return ErrorPopup(error)
  verificationLogs.value = data ?? []
  verificationLogsLoaded.value = true
}

// ── Tab yönetimi ─────────────────────────────────────────────────────────────
const activeTab = ref('info')

function onTabChange(tab: string) {
  activeTab.value = tab
  if (tab === 'reviews')
    fetchReviews()
  if (tab === 'verification')
    fetchVerificationLogs()
}

onMounted(fetchVenue)
</script>

<template>
  <div v-if="venue">
    <!-- Header -->
    <VCard
      class="mb-6"
      flat
    >
      <VCardText class="d-flex align-center gap-4">
        <div>
          <h5 class="text-h5">
            {{ venue.name }}
          </h5>
          <VChip
            size="small"
            :color="venueStatusColor[venue.status] ?? 'default'"
            class="mt-1"
          >
            {{ venue.status }}
          </VChip>
          <VChip
            v-if="venue.badge"
            size="small"
            color="info"
            class="mt-1 ms-1"
            prepend-icon="tabler-award"
          >
            {{ venue.badge.level }}
          </VChip>
          <div class="text-body-2 text-medium-emphasis mt-1">
            {{ [venue.district, venue.city].filter(Boolean).join(', ') }}
          </div>
        </div>
        <VSpacer />
        <VBtn
          variant="text"
          prepend-icon="tabler-arrow-left"
          @click="router.push('/venues')"
        >
          Geri
        </VBtn>
      </VCardText>
    </VCard>

    <!-- Tabs -->
    <VTabs
      :model-value="activeTab"
      @update:model-value="onTabChange"
    >
      <VTab value="info">
        Mekan Bilgileri
      </VTab>
      <VTab value="reviews">
        Yorumlar
      </VTab>
      <VTab value="verification">
        Doğrulama Geçmişi
      </VTab>
    </VTabs>

    <VDivider />

    <VWindow
      :model-value="activeTab"
      class="mt-6"
    >
      <!-- ── Mekan Bilgileri Tab ─────────────────────────────────────────── -->
      <VWindowItem value="info">
        <VRow>
          <VCol
            cols="12"
            md="4"
          >
            <VCard title="Ekleyen Rehber">
              <VCardText>
                <div class="text-body-1">
                  {{ [venue.added_by_name, venue.added_by_surname].filter(Boolean).join(' ') || '—' }}
                </div>
                <div class="text-body-2 text-medium-emphasis">
                  {{ venue.added_by_email || '—' }}
                </div>
                <div class="text-caption text-disabled mt-2">
                  Eklenme: {{ tarihFormat(venue.created_at) }}
                </div>
              </VCardText>
            </VCard>

            <VCard
              title="Bu Dönemde Doğrulayanlar"
              class="mt-4"
            >
              <VCardText>
                <div
                  v-if="confirmingGuides.length === 0"
                  class="text-caption text-disabled"
                >
                  Bu dönemde başka rehber doğrulamamış.
                </div>
                <VList
                  v-else
                  density="compact"
                  class="pa-0"
                >
                  <VListItem
                    v-for="g in confirmingGuides"
                    :key="g.guide_id"
                    class="px-0"
                  >
                    <VListItemTitle>{{ [g.guide_name, g.guide_surname].filter(Boolean).join(' ') }}</VListItemTitle>
                    <VListItemSubtitle>{{ g.guide_email }}</VListItemSubtitle>
                    <VListItemSubtitle>{{ tarihFormat(g.created_at) }}</VListItemSubtitle>
                  </VListItem>
                </VList>
              </VCardText>
            </VCard>
          </VCol>

          <VCol
            cols="12"
            md="8"
          >
            <VCard title="Mekan Bilgileri">
              <VCardText>
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
                          @click="toggleCategory(cat.id)"
                        >
                          {{ cat.name }}
                        </VChip>
                      </div>
                    </VCard>
                  </VCol>
                </VRow>
                <VBtn
                  color="primary"
                  @click="saveVenue"
                >
                  Kaydet
                </VBtn>
              </VCardText>
            </VCard>
          </VCol>
        </VRow>
      </VWindowItem>

      <!-- ── Reviews Tab ─────────────────────────────────────────────────── -->
      <VWindowItem value="reviews">
        <VCard>
          <VCardText>
            <VTable>
              <thead>
                <tr>
                  <th>Yazan</th>
                  <th>Puan</th>
                  <th>Yorum</th>
                  <th>Tarih</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                <tr v-if="reviews.length === 0">
                  <td
                    colspan="5"
                    class="text-center text-medium-emphasis py-6"
                  >
                    Henüz yorum yapılmamış.
                  </td>
                </tr>
                <tr
                  v-for="r in reviews"
                  :key="r.id"
                >
                  <td>{{ r.user_name || '—' }}</td>
                  <td>
                    <VChip
                      size="small"
                      color="warning"
                    >
                      {{ r.rating }} ★
                    </VChip>
                  </td>
                  <td style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    {{ r.comment ?? '—' }}
                  </td>
                  <td>{{ tarihFormat(r.created_at) }}</td>
                  <td>
                    <VBtn
                      icon
                      size="small"
                      variant="text"
                      @click="deleteReview(r)"
                    >
                      <VIcon
                        icon="tabler-trash"
                        size="20"
                        color="error"
                      />
                    </VBtn>
                  </td>
                </tr>
              </tbody>
            </VTable>
          </VCardText>
        </VCard>
      </VWindowItem>

      <!-- ── Verification Logs Tab ───────────────────────────────────────── -->
      <VWindowItem value="verification">
        <VCard>
          <VCardText>
            <VTable>
              <thead>
                <tr>
                  <th>Rehber</th>
                  <th>Şehir</th>
                  <th>Aksiyon</th>
                  <th>Tarih</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="verificationLogs.length === 0">
                  <td
                    colspan="4"
                    class="text-center text-medium-emphasis py-6"
                  >
                    Henüz doğrulama kaydı yok.
                  </td>
                </tr>
                <tr
                  v-for="l in verificationLogs"
                  :key="l.id"
                >
                  <td>{{ l.guide_name }}</td>
                  <td>{{ l.city }}</td>
                  <td>
                    <VChip
                      size="small"
                      :color="verificationActionColor[l.action] ?? 'default'"
                    >
                      {{ verificationActionLabel[l.action] ?? l.action }}
                    </VChip>
                  </td>
                  <td>{{ tarihFormat(l.created_at) }}</td>
                </tr>
              </tbody>
            </VTable>
          </VCardText>
        </VCard>
      </VWindowItem>
    </VWindow>
  </div>

  <div
    v-else
    class="d-flex justify-center align-center"
    style="min-height: 200px;"
  >
    <VProgressCircular
      indeterminate
      color="primary"
    />
  </div>
</template>
