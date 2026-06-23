<script setup lang="ts">
// ?skipsvgo: svgo'yu atla. Varsayılan svgo, il <g data-city-name> gruplarını birleştirip
// (collapseGroups) attribute'leri kaldırıyor → boyama/eşleşme bozuluyordu. skipsvgo ile
// SVG'nin grup yapısı ve viewBox aynen korunur (yalnızca bu SVG; global config etkilenmez).
import TurkeyMap from '@/assets/turkey-map.svg?skipsvgo'
import { CITY_CENTROID, colorForCount } from '@/utils/turkeyPlates'

// unit: tooltip ve lejantta gösterilen birim (ör. 'rehber', 'mekan').
const props = withDefaults(
  defineProps<{ counts: Record<string, number>; unit?: string }>(),
  { unit: 'rehber' },
)

const svgWrap = ref<HTMLElement | null>(null)

// İmleci takip eden HTML tooltip durumu.
const tooltip = reactive({ show: false, text: '', x: 0, y: 0 })


function paint() {
  const root = svgWrap.value?.querySelector('svg')
  if (!root)
    return

  // SVG'yi konteyner içinde duyarlı kıl: sabit boyutu kaldır, viewBox oranını koru.
  root.removeAttribute('width')
  root.removeAttribute('height')
  root.setAttribute('preserveAspectRatio', 'xMidYMid meet')
  root.style.maxHeight = '560px'
  root.style.display = 'block'

  // İller SVG'de <g data-city-name="..."> ile işaretli; kanonik ad ile birebir eşleşir.
  for (const city of Object.keys(CITY_CENTROID)) {
    const count = props.counts[city] ?? 0
    const group = root.querySelector<SVGGElement>(`g[data-city-name="${city}"]`)
    if (!group)
      continue

    const fill = colorForCount(count)

    // Tüm il path'lerini boya + ince beyaz kenarlık. SVG path'lerinde inline
    // style="fill: rgb(175,175,175)" var; presentation attribute bunu ezemez,
    // bu yüzden boyamayı yine inline style ile yapıyoruz (aynı özgüllük, sonradan kazanır).
    group.querySelectorAll<SVGPathElement>('path').forEach(p => {
      p.style.fill = fill
      p.style.opacity = '1'
      p.style.stroke = '#ffffff'
      p.style.strokeWidth = '0.5'
    })

    // Hover tooltip için veriyi grup üzerine işaretle (listener delegasyonu paint dışında).
    group.dataset.tooltip = `${city} — ${count} ${props.unit}`

    // Sayısı olan illerde centroid'e sadece sayı yaz (şehir adı yok).
    const c = CITY_CENTROID[city]
    const label = group.querySelector<SVGTextElement>('text[data-label="1"]')
    if (count > 0) {
      // Yuvarlak arka plan + sayı: mevcut <g data-badge> varsa güncelle, yoksa oluştur.
      let badge = group.querySelector<SVGGElement>('g[data-badge="1"]')
      if (!badge) {
        badge = document.createElementNS('http://www.w3.org/2000/svg', 'g')
        badge.setAttribute('data-badge', '1')
        badge.setAttribute('pointer-events', 'none')
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
        circle.setAttribute('r', '9')
        circle.setAttribute('fill', 'rgba(255,0, 0, 1)')
        circle.setAttribute('stroke', 'rgba(0,0,0,0.15)')
        circle.setAttribute('stroke-width', '0.5')
        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text')
        text.setAttribute('text-anchor', 'middle')
        text.setAttribute('dominant-baseline', 'central')
        text.setAttribute('font-size', '9')
        text.setAttribute('font-weight', '700')
        badge.append(circle, text)
        group.appendChild(badge)
      }
      badge.setAttribute('transform', `translate(${c.cx},${c.cy})`)
      const badgeText = badge.querySelector('text')!
      badgeText.setAttribute('fill', '#ffffff')
      badgeText.textContent = String(count)
    }
    else {
      group.querySelector('g[data-badge="1"]')?.remove()
    }
    // eski düz label varsa temizle
    label?.remove()
  }
}

// Hover popup — olay delegasyonu ile (her ile ayrı listener bağlamadan).
function onMove(e: MouseEvent) {
  const wrap = svgWrap.value
  if (!wrap)
    return
  const group = (e.target as Element).closest<SVGGElement>('g[data-city-name]')
  if (!group || !group.dataset.tooltip) {
    tooltip.show = false

    return
  }
  const rect = wrap.getBoundingClientRect()
  tooltip.text = group.dataset.tooltip
  tooltip.x = e.clientX - rect.left
  tooltip.y = e.clientY - rect.top
  tooltip.show = true
}
function onLeave() {
  tooltip.show = false
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
  return { backgroundColor: colorForCount(count) }
}

// Lejant başlığı için birimi büyük harfle başlat ('rehber' → 'Rehber').
const unitLabel = computed(() => props.unit.charAt(0).toLocaleUpperCase('tr-TR') + props.unit.slice(1))
</script>

<template>
  <div>
    <div
      ref="svgWrap"
      class="turkey-map-wrap"
      @mousemove="onMove"
      @mouseleave="onLeave"
    >
      <TurkeyMap />
      <div
        v-show="tooltip.show"
        class="map-tooltip"
        :style="{ left: `${tooltip.x}px`, top: `${tooltip.y}px` }"
      >
        {{ tooltip.text }}
      </div>
    </div>
    <div class="d-flex align-center flex-wrap gap-3 mt-4 px-2">
      <span class="text-caption text-medium-emphasis me-2">{{ unitLabel }} sayısı:</span>
      <div v-for="item in legend" :key="item.label" class="d-flex align-center gap-1">
        <span class="legend-swatch" :style="legendStyle(item.count)" />
        <span class="text-caption">{{ item.label }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.turkey-map-wrap {
  position: relative;
}
.turkey-map-wrap :deep(svg) {
  width: 100%;
  height: auto;
}
.turkey-map-wrap :deep(g[data-city-name]) {
  cursor: pointer;
  transition: filter 0.15s ease;
}
/* Hover'da rengi gri'ye kaydırmadan hafifçe vurgula (mavi mavi kalır). */
.turkey-map-wrap :deep(g[data-city-name]:hover) {
  filter: brightness(0.92);
}
.map-tooltip {
  position: absolute;
  z-index: 10;
  padding: 4px 10px;
  border-radius: 6px;
  background: rgba(30, 30, 46, 0.92);
  color: #fff;
  font-size: 0.8rem;
  font-weight: 600;
  white-space: nowrap;
  pointer-events: none;
  transform: translate(12px, -50%);
}
.legend-swatch {
  display: inline-block;
  inline-size: 18px;
  block-size: 18px;
  border-radius: 3px;
  border: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
