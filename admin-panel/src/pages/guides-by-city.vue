<script setup lang="ts">
import ApiService from '@/services/ApiService'
import { ErrorPopup } from '@/utils/Popup'
import TurkeyGuideMap from '@/components/TurkeyGuideMap.vue'

definePage({ meta: { role: ['admin'] } })

interface CityCount { city: string; count: number }
const rows = ref<CityCount[]>([])
const loading = ref(true)

// Kanonik il adı → rehber sayısı (harita için).
const counts = computed<Record<string, number>>(() => {
  const m: Record<string, number> = {}
  for (const r of rows.value)
    m[r.city] = r.count

  return m
})

onMounted(async () => {
  const [error, data] = await ApiService.get<CityCount[]>('admin/guides/by-city')
  loading.value = false
  if (error)
    return ErrorPopup(error)
  rows.value = data
})
</script>

<template>
  <VRow>
    <VCol cols="12">
      <VCard title="Türkiye Rehber Yoğunluğu">
        <VCardText>
          <VProgressLinear v-if="loading" indeterminate color="primary" />
          <TurkeyGuideMap v-else :counts="counts" />
        </VCardText>
      </VCard>
    </VCol>

    <VCol cols="12">
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
    </VCol>
  </VRow>
</template>
