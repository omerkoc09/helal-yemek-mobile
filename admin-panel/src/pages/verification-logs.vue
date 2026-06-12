<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { SuccessToast, ErrorPopup, WarningPopup } from '@/utils/Popup'

definePage({ meta: { role: ['admin'] } })

const tab = ref<'verified' | 'suspended' | 'upcoming' | 'warnings'>('verified')
const rows = ref<any[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  const params = new URLSearchParams({ tab: tab.value })
  const [error, data] = await ApiService.get<{ data: any[] }>('admin/verification-logs', undefined, params)
  loading.value = false
  if (error)
    return ErrorPopup(error)
  rows.value = Array.isArray(data?.data) ? data.data : []
}

watch(tab, load)
onMounted(load)

async function runScheduler() {
  const c = await WarningPopup('Scheduler şimdi çalıştırılsın mı?', 'Evet', 'Hayır')
  if (!c.isConfirmed)
    return
  const [error] = await ApiService.post('admin/scheduler/run', {})
  if (error)
    return ErrorPopup(error)
  SuccessToast()
  load()
}

const headers = [
  { title: 'Mekan', key: 'venue_name' },
  { title: 'Rehber', key: 'guide_name' },
  { title: 'Şehir', key: 'city' },
  { title: 'İşlem', key: 'action' },
  { title: 'Tarih', key: 'created_at' },
]
</script>

<template>
  <VCard>
    <VCardText class="d-flex justify-space-between align-center">
      <VTabs v-model="tab">
        <VTab value="verified">Doğrulanmış</VTab>
        <VTab value="suspended">Askıda</VTab>
        <VTab value="upcoming">Yaklaşan</VTab>
        <VTab value="warnings">Uyarılan</VTab>
      </VTabs>
      <VBtn color="primary" prepend-icon="tabler-player-play" @click="runScheduler">Scheduler Çalıştır</VBtn>
    </VCardText>
    <VCardText>
      <VDataTable :headers="headers" :items="rows" :loading="loading" />
    </VCardText>
  </VCard>
</template>
