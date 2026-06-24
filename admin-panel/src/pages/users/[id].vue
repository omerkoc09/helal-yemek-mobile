<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import ApiService from '@/services/ApiService'
import { SuccessToast, WarningPopup, ErrorPopup } from '@/utils/Popup'
import tarihFormat from '@/utils/ExDate'

definePage({ meta: { role: ['admin'] } })

const route = useRoute()
const router = useRouter()
const id = route.params.id as string

// ── Kullanıcı verisi ─────────────────────────────────────────────────────────
const user = ref<any>(null)
const accountForm = ref<any>({})
const passwordForm = ref({ password: '' })

const roles = [
  { title: 'Gezgin', value: 'traveler' },
  { title: 'Rehber', value: 'guide' },
  { title: 'Admin', value: 'admin' },
]

async function fetchUser() {
  const [error, data] = await ApiService.get(`admin/users/${id}`)
  if (error) return ErrorPopup(error)
  user.value = data
  accountForm.value = { ...data }
}

async function saveAccount() {
  const [error] = await ApiService.put(`admin/users/${id}`, {
    name: accountForm.value.name,
    surname: accountForm.value.surname,
    email: accountForm.value.email,
    phone: accountForm.value.phone,
    role: accountForm.value.role,
    is_active: accountForm.value.is_active,
  })
  if (error) return ErrorPopup(error)
  SuccessToast()
  await fetchUser()
}

async function savePassword() {
  if (!passwordForm.value.password || passwordForm.value.password.length < 6) {
    return ErrorPopup('Şifre en az 6 karakter olmalıdır')
  }
  const [error] = await ApiService.put(`admin/users/${id}/password`, {
    password: passwordForm.value.password,
  })
  if (error) return ErrorPopup(error)
  SuccessToast()
  passwordForm.value.password = ''
}

// ── Mekânlar ─────────────────────────────────────────────────────────────────
const venues = ref<any[]>([])
const venuesLoaded = ref(false)

async function fetchVenues() {
  if (venuesLoaded.value) return
  const [error, data] = await ApiService.get(`admin/users/${id}/venues`)
  if (error) return ErrorPopup(error)
  venues.value = data ?? []
  venuesLoaded.value = true
}

const venueStatusColor: Record<string, string> = {
  approved: 'success',
  pending: 'warning',
  rejected: 'error',
  suspended: 'default',
}

// ── Yorumlar ─────────────────────────────────────────────────────────────────
const reviews = ref<any[]>([])
const reviewsLoaded = ref(false)

async function fetchReviews() {
  if (reviewsLoaded.value) return
  const [error, data] = await ApiService.get(`admin/users/${id}/reviews`)
  if (error) return ErrorPopup(error)
  reviews.value = data ?? []
  reviewsLoaded.value = true
}

async function deleteReview(review: any) {
  const c = await WarningPopup('Yorum silinsin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed) return
  const [error] = await ApiService.delete(`venues/${review.venue_id}/reviews/${review.id}`)
  if (error) return ErrorPopup(error)
  SuccessToast()
  reviewsLoaded.value = false
  await fetchReviews()
}

// ── Tab yönetimi ─────────────────────────────────────────────────────────────
const activeTab = ref('account')

function onTabChange(tab: string) {
  activeTab.value = tab
  if (tab === 'venues') fetchVenues()
  if (tab === 'reviews') fetchReviews()
}

const roleChipColor: Record<string, string> = {
  admin: 'error',
  guide: 'warning',
  traveler: 'default',
}

onMounted(fetchUser)
</script>

<template>
  <div v-if="user">
    <!-- Header -->
    <VCard class="mb-6" flat>
      <VCardText class="d-flex align-center gap-4">
        <div>
          <h5 class="text-h5">{{ user.name }} {{ user.surname }}</h5>
          <VChip size="small" :color="roleChipColor[user.role] ?? 'default'" class="mt-1">
            {{ user.role }}
          </VChip>
          <div class="text-body-2 text-medium-emphasis mt-1">{{ user.email }}</div>
        </div>
        <VSpacer />
        <VBtn variant="text" prepend-icon="tabler-arrow-left" @click="router.push('/users')">
          Geri
        </VBtn>
      </VCardText>
    </VCard>

    <!-- Tabs -->
    <VTabs :model-value="activeTab" @update:model-value="onTabChange">
      <VTab value="account">Hesap</VTab>
      <VTab v-if="user.role === 'guide'" value="venues">Mekânlar</VTab>
      <VTab value="reviews">Yorumlar</VTab>
    </VTabs>

    <VDivider />

    <VWindow :model-value="activeTab" class="mt-6">
      <!-- ── Account Tab ─────────────────────────────────────────────────── -->
      <VWindowItem value="account">
        <VRow>
          <VCol cols="12" md="6">
            <VCard title="Hesap Bilgileri">
              <VCardText>
                <VTextField v-model="accountForm.name" label="Ad" class="mb-3" />
                <VTextField v-model="accountForm.surname" label="Soyad" class="mb-3" />
                <VTextField v-model="accountForm.email" label="E-posta" class="mb-3" />
                <VTextField v-model="accountForm.phone" label="Telefon" class="mb-3" />
                <VSelect v-model="accountForm.role" :items="roles" label="Rol" class="mb-3" />
                <VSwitch v-model="accountForm.is_active" label="Aktif" class="mb-3" />
                <VBtn color="primary" @click="saveAccount">Kaydet</VBtn>
              </VCardText>
            </VCard>
          </VCol>

          <VCol cols="12" md="6">
            <VCard title="Şifre Sıfırla">
              <VCardText>
                <VTextField
                  v-model="passwordForm.password"
                  label="Yeni Şifre"
                  type="password"
                  class="mb-3"
                />
                <VBtn color="warning" @click="savePassword">Şifreyi Güncelle</VBtn>
              </VCardText>
            </VCard>
          </VCol>
        </VRow>
      </VWindowItem>

      <!-- ── Venues Tab ──────────────────────────────────────────────────── -->
      <VWindowItem value="venues">
        <VCard>
          <VCardText>
            <VTable>
              <thead>
                <tr>
                  <th>Mekân Adı</th>
                  <th>Şehir</th>
                  <th>Durum</th>
                  <th>Eklenme Tarihi</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="venues.length === 0">
                  <td colspan="4" class="text-center text-medium-emphasis py-6">
                    Henüz mekan eklenmemiş.
                  </td>
                </tr>
                <tr v-for="v in venues" :key="v.id">
                  <td>
                    <RouterLink :to="`/venues?highlight=${v.id}`" class="text-primary">
                      {{ v.name }}
                    </RouterLink>
                  </td>
                  <td>{{ v.city }}</td>
                  <td>
                    <VChip size="small" :color="venueStatusColor[v.status] ?? 'default'">
                      {{ v.status }}
                    </VChip>
                  </td>
                  <td>{{ tarihFormat(v.created_at) }}</td>
                </tr>
              </tbody>
            </VTable>
          </VCardText>
        </VCard>
      </VWindowItem>

      <!-- ── Reviews Tab ─────────────────────────────────────────────────── -->
      <VWindowItem value="reviews">
        <VCard>
          <VCardText>
            <VTable>
              <thead>
                <tr>
                  <th>Mekân</th>
                  <th>Puan</th>
                  <th>Yorum</th>
                  <th>Tarih</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="reviews.length === 0">
                  <td colspan="5" class="text-center text-medium-emphasis py-6">
                    Henüz yorum yapılmamış.
                  </td>
                </tr>
                <tr v-for="r in reviews" :key="r.id">
                  <td>{{ r.venue_name }}</td>
                  <td>
                    <VChip size="small" color="warning">{{ r.rating }} ★</VChip>
                  </td>
                  <td style="max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    {{ r.comment ?? '—' }}
                  </td>
                  <td>{{ tarihFormat(r.created_at) }}</td>
                  <td>
                    <VBtn icon size="small" variant="text" @click="deleteReview(r)">
                      <VIcon icon="tabler-trash" size="20" color="error" />
                    </VBtn>
                  </td>
                </tr>
              </tbody>
            </VTable>
          </VCardText>
        </VCard>
      </VWindowItem>
    </VWindow>
  </div>

  <div v-else class="d-flex justify-center align-center" style="min-height: 200px;">
    <VProgressCircular indeterminate color="primary" />
  </div>
</template>
