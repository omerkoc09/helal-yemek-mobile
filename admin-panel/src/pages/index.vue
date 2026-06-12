<script setup lang="ts">
import ApiService from '@/services/ApiService'

definePage({ meta: { role: ['admin'] } })

const stats = ref({ venues: 0, pending: 0, users: 0, applications: 0 })
const loading = ref(true)

async function load() {
  loading.value = true
  const [, venues] = await ApiService.get<any[]>('admin/venues')
  const [, pending] = await ApiService.get<any[]>('admin/venues/pending')
  const [, users] = await ApiService.get<any[]>('admin/users')
  const [, apps] = await ApiService.get<any[]>('admin/applications')
  stats.value = {
    venues: Array.isArray(venues) ? venues.length : 0,
    pending: Array.isArray(pending) ? pending.length : 0,
    users: Array.isArray(users) ? users.length : 0,
    applications: Array.isArray(apps) ? apps.length : 0,
  }
  loading.value = false
}

onMounted(load)

const cards = computed(() => [
  { title: 'Toplam Mekan', value: stats.value.venues, icon: 'tabler-building-store', color: 'primary' },
  { title: 'Bekleyen Mekan', value: stats.value.pending, icon: 'tabler-clock-hour-4', color: 'warning' },
  { title: 'Toplam Kullanıcı', value: stats.value.users, icon: 'tabler-users', color: 'info' },
  { title: 'Guide Başvurusu', value: stats.value.applications, icon: 'tabler-user-plus', color: 'success' },
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
  </VRow>
</template>
