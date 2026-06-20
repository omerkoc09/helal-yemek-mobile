<script setup lang="ts">
import ApiService from '@/services/ApiService'

definePage({ meta: { role: ['admin'] } })

interface CityCount { city: string; count: number }
const rows = ref<CityCount[]>([])
const loading = ref(true)

onMounted(async () => {
  const [error, data] = await ApiService.get<CityCount[]>('admin/guides/by-city')
  if (!error)
    rows.value = data
  loading.value = false
})
</script>

<template>
  <VCard title="Şehir Bazlı Rehber Sayısı">
    <VProgressLinear v-if="loading" indeterminate color="primary" />
    <VTable v-else>
      <thead>
        <tr>
          <th>Şehir</th>
          <th>Rehber Sayısı</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in rows" :key="r.city">
          <td>{{ r.city }}</td>
          <td>{{ r.count }}</td>
        </tr>
      </tbody>
    </VTable>
  </VCard>
</template>
