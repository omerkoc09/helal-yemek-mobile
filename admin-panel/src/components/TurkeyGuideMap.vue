<script setup lang="ts">
import { useTheme } from 'vuetify'
import TurkeyMap from '@/assets/turkey-map.svg?component'
import { PLATE_TO_CITY, PLATE_CENTROID, opacityForCount } from '@/utils/turkeyPlates'

const props = defineProps<{ counts: Record<string, number> }>()

const svgWrap = ref<HTMLElement | null>(null)
const theme = useTheme()

// Vuetify tema rengini ('primary', 'grey-lighten-2' ...) hex'e çevirir; yoksa gri döner.
function tokenToHex(token: string): string {
  const colors = theme.current.value.colors as Record<string, string>
  return colors[token] ?? '#cccccc'
}

function paint() {
  const root = svgWrap.value?.querySelector('svg')
  if (!root)
    return

  // SVG'yi konteyner içinde duyarlı kıl.
  root.setAttribute('width', '100%')
  root.setAttribute('height', 'auto')
  root.style.maxHeight = '560px'
  root.style.display = 'block'

  for (const plate of Object.keys(PLATE_TO_CITY)) {
    const city = PLATE_TO_CITY[plate]
    const count = props.counts[city] ?? 0
    const group = root.querySelector<SVGGElement>(`g[data-plate="${plate}"]`)
    if (!group)
      continue

    const fill = count > 0 ? tokenToHex('primary') : tokenToHex('grey-lighten-2')
    const op = opacityForCount(count)

    // Tüm il path'lerini boya + ince beyaz kenarlık.
    group.querySelectorAll<SVGPathElement>('path').forEach(p => {
      p.setAttribute('fill', fill)
      p.setAttribute('fill-opacity', String(op))
      p.setAttribute('stroke', '#ffffff')
      p.setAttribute('stroke-width', '1')
    })

    // Tooltip (native): "İstanbul: 5 rehber".
    let title = group.querySelector('title')
    if (!title) {
      title = document.createElementNS('http://www.w3.org/2000/svg', 'title')
      group.insertBefore(title, group.firstChild)
    }
    title.textContent = `${city}: ${count} rehber`

    // Sayı etiketi (yalnızca count > 0). Centroid'e <text> ekle/güncelle.
    const c = PLATE_CENTROID[plate]
    let label = group.querySelector<SVGTextElement>('text[data-label="1"]')
    if (count > 0 && c) {
      if (!label) {
        label = document.createElementNS('http://www.w3.org/2000/svg', 'text')
        label.setAttribute('data-label', '1')
        label.setAttribute('text-anchor', 'middle')
        label.setAttribute('dominant-baseline', 'central')
        label.setAttribute('pointer-events', 'none')
        label.setAttribute('font-size', '22')
        label.setAttribute('font-weight', '700')
        group.appendChild(label)
      }
      label.setAttribute('x', String(c.cx))
      label.setAttribute('y', String(c.cy))
      // Koyu illerde beyaz, açık illerde koyu yazı.
      label.setAttribute('fill', op >= 0.7 ? '#ffffff' : '#1a1a2e')
      label.textContent = String(count)
    }
    else if (label) {
      label.remove()
    }
  }
}

onMounted(paint)
watch(() => props.counts, paint, { deep: true })

// Lejant kademeleri (görsel açıklama için).
const legend = [
  { label: '0', count: 0 },
  { label: '1', count: 1 },
  { label: '2–3', count: 2 },
  { label: '4–6', count: 4 },
  { label: '7–10', count: 7 },
  { label: '11+', count: 11 },
]
function legendStyle(count: number) {
  const fill = count > 0 ? tokenToHex('primary') : tokenToHex('grey-lighten-2')

  return { backgroundColor: fill, opacity: opacityForCount(count) }
}
</script>

<template>
  <div>
    <div ref="svgWrap" class="turkey-map-wrap">
      <TurkeyMap />
    </div>
    <div class="d-flex align-center flex-wrap gap-3 mt-4 px-2">
      <span class="text-caption text-medium-emphasis me-2">Rehber sayısı:</span>
      <div v-for="item in legend" :key="item.label" class="d-flex align-center gap-1">
        <span class="legend-swatch" :style="legendStyle(item.count)" />
        <span class="text-caption">{{ item.label }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.turkey-map-wrap :deep(svg) {
  width: 100%;
  height: auto;
}
.turkey-map-wrap :deep(g[data-plate]) {
  cursor: pointer;
  transition: fill-opacity 0.15s ease;
}
.turkey-map-wrap :deep(g[data-plate]:hover path) {
  fill-opacity: 1 !important;
}
.legend-swatch {
  display: inline-block;
  inline-size: 18px;
  block-size: 18px;
  border-radius: 3px;
  border: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
