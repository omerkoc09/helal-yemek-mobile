<script setup lang="ts">
import ApiService from '@/services/ApiService'
import TurkeyCityMap from '@/components/TurkeyCityMap.vue'

definePage({ meta: { role: ['admin'] } })

interface CityCount { city: string; count: number }

const stats = ref({ venues: 0, pending: 0, users: 0, applications: 0 })
const loading = ref(true)

// Kanonik il adı → onaylı mekan sayısı (harita için).
const venueCounts = ref<Record<string, number>>({})

async function load() {
  loading.value = true
  const [[, venues], [, pending], [, users], [, apps], [, byCity]] = await Promise.all([
    ApiService.get<any[]>('admin/venues'),
    ApiService.get<any[]>('admin/venues/pending'),
    ApiService.get<any[]>('admin/users'),
    ApiService.get<any[]>('admin/applications'),
    ApiService.get<CityCount[]>('admin/venues/by-city'),
  ])
  stats.value = {
    venues: Array.isArray(venues) ? venues.length : 0,
    pending: Array.isArray(pending) ? pending.length : 0,
    users: Array.isArray(users) ? users.length : 0,
    applications: Array.isArray(apps) ? apps.length : 0,
  }
  const m: Record<string, number> = {}
  if (Array.isArray(byCity)) {
    for (const r of byCity)
      m[r.city] = r.count
  }
  venueCounts.value = m
  loading.value = false
}

onMounted(load)

const cards = computed(() => [
  { title: 'Toplam Mekan', value: stats.value.venues, icon: 'tabler-building-store', color: 'primary' },
  { title: 'Bekleyen Mekan', value: stats.value.pending, icon: 'tabler-clock-hour-4', color: 'warning' },
  { title: 'Toplam Kullanıcı', value: stats.value.users, icon: 'tabler-users', color: 'info' },
  { title: 'Rehber Başvurusu', value: stats.value.applications, icon: 'tabler-user-plus', color: 'success' },
])
</script>

<template>
  <VRow>
    <VCol v-for="c in cards" :key="c.title" cols="12" sm="6" md="3">
      <VCard>
        <VCardText class="d-flex align-center gap-4">
          <VAvatar :color="c.color" variant="tonal" size="48">
            <VIcon :icon="c.icon" size="28" />
          </VAvatar>
          <div>
            <div class="text-h5">{{ loading ? '...' : c.value }}</div>
            <div class="text-body-2 text-disabled">{{ c.title }}</div>
          </div>
        </VCardText>
      </VCard>
    </VCol>

    <VCol cols="12">
      <VCard title="Türkiye Mekan Yoğunluğu" subtitle="Şehir bazlı onaylı mekan sayısı">
        <VCardText>
          <VProgressLinear v-if="loading" indeterminate color="primary" />
          <TurkeyCityMap v-else :counts="venueCounts" unit="mekan" />
        </VCardText>
      </VCard>
    </VCol>
  </VRow>
</template>
