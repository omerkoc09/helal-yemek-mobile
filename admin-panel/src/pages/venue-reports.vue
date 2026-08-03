<script setup lang="ts">
import { useRouter } from 'vue-router'
import ApiService from '@/services/ApiService'
import { ErrorPopup, SuccessToast, WarningPopup } from '@/utils/Popup'
import tarihFormat, { tarihSaatFormat } from '@/utils/ExDate'

definePage({ meta: { role: ['admin'] } })

const router = useRouter()

const reports = ref<any[]>([])
const selectedId = ref<string | null>(null)
const loading = ref(true)

const selected = computed(() => reports.value.find(r => r.id === selectedId.value) ?? null)

// Mobildeki report_venue_sheet.dart ile birebir aynı etiketler.
const reasonLabels: Record<string, string> = {
  closed: 'Mekan artık hizmet vermiyor',
  trust_criteria: 'Güven kriterlerini karşılamıyor',
  wrong_address: 'Mekanın adresi yanlış',
  wrong_food: 'Servis edilen yemekler yanlış',
  other: 'Diğer',
}

const roleLabels: Record<string, string> = {
  traveler: 'Gezgin',
  guide: 'Rehber',
  admin: 'Admin',
}

function reasonLabel(reason: string) {
  return reasonLabels[reason] ?? reason
}

function statusColor(status: string) {
  return status === 'resolved' ? 'success' : 'warning'
}

function statusLabel(status: string) {
  return status === 'resolved' ? 'Çözümlendi' : 'Bekliyor'
}

// Boş/null alanlar için tire göster.
function orDash(value: unknown) {
  const s = typeof value === 'string' ? value.trim() : value

  return s ? String(s) : '—'
}

const reporterFullName = computed(() => {
  if (!selected.value)
    return '—'

  return orDash([selected.value.reporter_name, selected.value.reporter_surname].filter(Boolean).join(' '))
})

async function fetchReports() {
  loading.value = true

  const [error, data] = await ApiService.get<any[]>('admin/venue-reports')

  loading.value = false
  if (error)
    return ErrorPopup(error)

  reports.value = data ?? []

  // Seçili rapor listede duruyorsa korunur, yoksa ilk (en yeni) kayda düşer.
  if (!reports.value.some(r => r.id === selectedId.value))
    selectedId.value = reports.value[0]?.id ?? null
}

async function resolve(row: any) {
  const c = await WarningPopup('Rapor çözümlensin mi?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.put(`admin/venue-reports/${row.id}/resolve`, {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  await fetchReports()
}

onMounted(fetchReports)
</script>

<template>
  <div class="reports-layout">
    <!-- ── Sol: rapor listesi ──────────────────────────────────────────────── -->
    <VCard class="reports-list">
      <VCardText class="pb-2">
        <div class="d-flex align-center justify-space-between">
          <h5 class="text-h5">
            Mekan Raporları
          </h5>
          <VChip
            v-if="!loading"
            size="small"
            variant="tonal"
          >
            {{ reports.length }}
          </VChip>
        </div>
      </VCardText>

      <VDivider />

      <div class="reports-list__scroll">
        <div
          v-if="loading"
          class="d-flex justify-center py-8"
        >
          <VProgressCircular
            indeterminate
            color="primary"
          />
        </div>

        <div
          v-else-if="reports.length === 0"
          class="text-center text-medium-emphasis py-8"
        >
          Henüz rapor yok.
        </div>

        <div
          v-for="r in reports"
          v-else
          :key="r.id"
          class="report-item"
          :class="{ 'report-item--active': r.id === selectedId }"
          @click="selectedId = r.id"
        >
          <div class="d-flex align-center justify-space-between gap-2">
            <span class="text-body-1 font-weight-medium text-truncate">{{ r.venue_name }}</span>
            <VChip
              size="x-small"
              :color="statusColor(r.status)"
            >
              {{ statusLabel(r.status) }}
            </VChip>
          </div>
          <div class="text-body-2 text-medium-emphasis mt-1">
            {{ reasonLabel(r.reason) }}
          </div>
          <div class="text-caption text-disabled mt-2">
            {{ tarihFormat(r.created_at) }}
          </div>
        </div>
      </div>
    </VCard>

    <!-- ── Sağ: rapor detayı ───────────────────────────────────────────────── -->
    <VCard class="reports-detail">
      <template v-if="selected">
        <VCardText class="d-flex align-center gap-3 flex-wrap">
          <div>
            <h5 class="text-h5">
              {{ selected.venue_name }}
            </h5>
            <VChip
              size="small"
              :color="statusColor(selected.status)"
              class="mt-1"
            >
              {{ statusLabel(selected.status) }}
            </VChip>
          </div>
          <VSpacer />
          <VBtn
            v-if="selected.status !== 'resolved'"
            color="success"
            prepend-icon="tabler-checkbox"
            @click="resolve(selected)"
          >
            Çözümle
          </VBtn>
          <VBtn
            variant="tonal"
            prepend-icon="tabler-building-store"
            @click="router.push(`/venues/${selected.venue_id}`)"
          >
            Mekana git
          </VBtn>
        </VCardText>

        <VDivider />

        <VCardText>
          <!-- Rapor bilgisi -->
          <div class="detail-section">
            <div class="detail-section__title">
              Rapor Bilgisi
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Sebep</span>
              <span class="detail-field__value">{{ reasonLabel(selected.reason) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Not</span>
              <span
                class="detail-field__value"
                :class="{ 'text-disabled': !selected.description }"
                style="white-space: pre-wrap;"
              >{{ selected.description || 'Not eklenmemiş' }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Tarih</span>
              <span class="detail-field__value">{{ tarihSaatFormat(selected.created_at) }}</span>
            </div>
          </div>

          <!-- Bildiren kullanıcı -->
          <div class="detail-section">
            <div class="detail-section__title">
              Bildiren Kullanıcı
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Ad Soyad</span>
              <span class="detail-field__value">{{ reporterFullName }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Rol</span>
              <span class="detail-field__value">{{ roleLabels[selected.reporter_role] ?? orDash(selected.reporter_role) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Telefon</span>
              <span class="detail-field__value">{{ orDash(selected.reporter_phone) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">E-posta</span>
              <span class="detail-field__value">{{ orDash(selected.reporter_email) }}</span>
            </div>
          </div>

          <!-- Mekan bilgisi -->
          <div class="detail-section">
            <div class="detail-section__title">
              Mekan Bilgisi
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Mekan</span>
              <span class="detail-field__value">{{ orDash(selected.venue_name) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Şehir</span>
              <span class="detail-field__value">{{ orDash(selected.venue_city) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Ekleyen</span>
              <span class="detail-field__value">{{ orDash(selected.added_by_name) }}</span>
            </div>
            <div class="detail-field">
              <span class="detail-field__label">Eklenme Tarihi</span>
              <span class="detail-field__value">{{ tarihFormat(selected.venue_added_at) }}</span>
            </div>
          </div>
        </VCardText>
      </template>

      <VCardText
        v-else-if="!loading"
        class="detail-empty"
      >
        <VIcon
          icon="tabler-flag-off"
          size="64"
          class="text-disabled"
        />
        <div class="text-body-1 text-medium-emphasis mt-3">
          Henüz rapor yok
        </div>
      </VCardText>
    </VCard>
  </div>
</template>

<style scoped lang="scss">
.reports-layout {
  display: flex;
  align-items: flex-start;
  gap: 1.5rem;

  @media (max-width: 959px) {
    flex-direction: column;
  }
}

.reports-list {
  flex: 0 0 380px;
  max-width: 380px;

  @media (max-width: 959px) {
    flex: 1 1 auto;
    max-width: 100%;
    inline-size: 100%;
  }
}

.reports-list__scroll {
  overflow-y: auto;
  max-block-size: calc(100vh - 14rem);
  padding: 0.5rem;

  @media (max-width: 959px) {
    max-block-size: 30rem;
  }
}

.report-item {
  padding: 0.75rem 1rem;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 0.375rem;
  border-inline-start: 3px solid transparent;
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease;

  & + & {
    margin-block-start: 0.5rem;
  }

  &:hover {
    background-color: rgba(var(--v-theme-on-surface), 0.04);
  }

  &--active {
    background-color: rgba(var(--v-theme-primary), 0.08);
    border-inline-start-color: rgb(var(--v-theme-primary));
  }
}

.reports-detail {
  flex: 1 1 auto;
  min-inline-size: 0;

  @media (max-width: 959px) {
    inline-size: 100%;
  }
}

.detail-section {
  & + & {
    margin-block-start: 1.5rem;
    padding-block-start: 1.5rem;
    border-block-start: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  }
}

.detail-section__title {
  font-size: 0.8125rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-block-end: 0.75rem;
}

.detail-field {
  display: flex;
  gap: 1rem;
  padding-block: 0.375rem;

  @media (max-width: 599px) {
    flex-direction: column;
    gap: 0.125rem;
  }
}

.detail-field__label {
  flex: 0 0 9rem;
  color: rgba(var(--v-theme-on-surface), 0.6);
  font-size: 0.875rem;
}

.detail-field__value {
  flex: 1 1 auto;
  min-inline-size: 0;
  overflow-wrap: anywhere;
}

.detail-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-block-size: 24rem;
}
</style>
