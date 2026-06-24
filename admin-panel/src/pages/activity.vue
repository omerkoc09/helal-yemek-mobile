<script setup lang="ts">
import BarChart from '@core/libs/chartjs/components/BarChart'
import ApiService from '@/services/ApiService'
import { ErrorPopup } from '@/utils/Popup'

definePage({ meta: { role: ['admin'] } })

const days = ref(7)
const loading = ref(true)
const today = ref({ new_users: 0, new_venues: 0, logins: 0 })
const trend = ref({ labels: [] as string[], new_users: [] as number[], new_venues: [] as number[], logins: [] as number[] })

let loadSeq = 0
async function load() {
  const seq = ++loadSeq
  loading.value = true
  const [error, data] = await ApiService.get(`admin/stats/activity?days=${days.value}`)
  if (seq !== loadSeq) return
  if (error) {
    ErrorPopup(error)
    loading.value = false
    return
  }
  today.value = data.today
  trend.value = data.trend
  loading.value = false
}

watch(days, load)
onMounted(load)

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } },
}

const userChartData = computed(() => ({
  labels: trend.value.labels,
  datasets: [{
    label: 'Yeni Kullanıcı',
    data: trend.value.new_users,
    backgroundColor: 'rgba(115, 103, 240, 0.7)',
  }],
}))

const venueChartData = computed(() => ({
  labels: trend.value.labels,
  datasets: [{
    label: 'Yeni Mekan',
    data: trend.value.new_venues,
    backgroundColor: 'rgba(40, 199, 111, 0.7)',
  }],
}))

const loginChartData = computed(() => ({
  labels: trend.value.labels,
  datasets: [{
    label: 'Giriş Sayısı',
    data: trend.value.logins,
    backgroundColor: 'rgba(0, 207, 232, 0.7)',
  }],
}))

const cards = computed(() => [
  { title: 'Yeni Kullanıcı', value: today.value.new_users, icon: 'tabler-user-plus', color: 'info' },
  { title: 'Yeni Mekan', value: today.value.new_venues, icon: 'tabler-building-store', color: 'primary' },
  { title: 'Giriş Sayısı', value: today.value.logins, icon: 'tabler-login', color: 'success' },
])
</script>

<template>
  <div>
    <!-- Filtre -->
    <div class="d-flex justify-end mb-6">
      <VBtnToggle v-model="days" mandatory divided variant="outlined" density="compact">
        <VBtn :value="7">7 Gün</VBtn>
        <VBtn :value="30">30 Gün</VBtn>
        <VBtn :value="90">90 Gün</VBtn>
      </VBtnToggle>
    </div>

    <!-- Bugünün Özeti -->
    <VRow class="mb-6">
      <VCol v-for="c in cards" :key="c.title" cols="12" sm="4">
        <VCard>
          <VCardText class="d-flex align-center gap-4">
            <VAvatar :color="c.color" variant="tonal" size="48">
              <VIcon :icon="c.icon" size="28" />
            </VAvatar>
            <div>
              <div class="text-h5">{{ loading ? '...' : c.value }}</div>
              <div class="text-body-2 text-disabled">{{ c.title }} (bugün)</div>
            </div>
          </VCardText>
        </VCard>
      </VCol>
    </VRow>

    <!-- Trend Grafikleri -->
    <VRow>
      <VCol cols="12" md="4">
        <VCard title="Günlük Yeni Kullanıcı">
          <VCardText>
            <BarChart
              chart-id="user-chart"
              :chart-data="userChartData"
              :chart-options="chartOptions"
              :height="220"
            />
          </VCardText>
        </VCard>
      </VCol>

      <VCol cols="12" md="4">
        <VCard title="Günlük Yeni Mekan">
          <VCardText>
            <BarChart
              chart-id="venue-chart"
              :chart-data="venueChartData"
              :chart-options="chartOptions"
              :height="220"
            />
          </VCardText>
        </VCard>
      </VCol>

      <VCol cols="12" md="4">
        <VCard title="Günlük Giriş Sayısı">
          <VCardText>
            <BarChart
              chart-id="login-chart"
              :chart-data="loginChartData"
              :chart-options="chartOptions"
              :height="220"
            />
          </VCardText>
        </VCard>
      </VCol>
    </VRow>
  </div>
</template>
