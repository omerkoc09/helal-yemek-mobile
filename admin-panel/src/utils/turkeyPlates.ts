// İl sayı etiketinin yerleşeceği nokta — SVG (ali-han/Turkey-SVG-Map) viewBox
// "0 0 1005 490" uzayında her ilin (data-city-name) bounding-box merkezi.
// Çok parçalı iller (ör. İstanbul) tek merkeze indirgenir. İsimler backend
// cities.go TurkishCities ve SVG data-city-name ile birebir aynı.
export const CITY_CENTROID: Record<string, { cx: number; cy: number }> = {
  Adana: { cx: 511.5, cy: 332.4 },
  Adıyaman: { cx: 658.9, cy: 307.3 },
  Afyonkarahisar: { cx: 252.0, cy: 253.0 },
  Aksaray: { cx: 418.1, cy: 261.8 },
  Amasya: { cx: 520.9, cy: 116.9 },
  Ankara: { cx: 344.1, cy: 180.7 },
  Antalya: { cx: 257.5, cy: 375.5 },
  Ardahan: { cx: 885.3, cy: 73.5 },
  Artvin: { cx: 834.2, cy: 82.9 },
  Aydın: { cx: 102.1, cy: 294.2 },
  Ağrı: { cx: 919.2, cy: 183.3 },
  Balıkesir: { cx: 106.3, cy: 151.8 },
  Bartın: { cx: 355.2, cy: 52.4 },
  Batman: { cx: 824.5, cy: 286.3 },
  Bayburt: { cx: 751.4, cy: 140.0 },
  Bilecik: { cx: 232.1, cy: 146.2 },
  Bingöl: { cx: 778.0, cy: 224.5 },
  Bitlis: { cx: 868.4, cy: 253.6 },
  Bolu: { cx: 305.1, cy: 116.7 },
  Burdur: { cx: 217.1, cy: 329.1 },
  Bursa: { cx: 173.6, cy: 142.6 },
  Denizli: { cx: 176.0, cy: 306.3 },
  Diyarbakır: { cx: 759.1, cy: 282.9 },
  Düzce: { cx: 293.2, cy: 97.1 },
  Edirne: { cx: 52.0, cy: 49.8 },
  Elazığ: { cx: 711.7, cy: 243.0 },
  Erzincan: { cx: 719.6, cy: 188.8 },
  Erzurum: { cx: 816.1, cy: 149.2 },
  Eskişehir: { cx: 274.8, cy: 180.8 },
  Gaziantep: { cx: 601.9, cy: 354.9 },
  Giresun: { cx: 665.8, cy: 122.7 },
  Gümüşhane: { cx: 711.0, cy: 135.9 },
  Hakkâri: { cx: 967.4, cy: 316.8 },
  Hatay: { cx: 546.8, cy: 402.8 },
  Isparta: { cx: 258.3, cy: 295.5 },
  Iğdır: { cx: 950.8, cy: 149.9 },
  Kahramanmaraş: { cx: 586.8, cy: 304.4 },
  Karabük: { cx: 361.8, cy: 77.8 },
  Karaman: { cx: 384.6, cy: 360.7 },
  Kars: { cx: 891.2, cy: 112.8 },
  Kastamonu: { cx: 416.9, cy: 64.4 },
  Kayseri: { cx: 529.8, cy: 262.3 },
  Kilis: { cx: 595.0, cy: 374.1 },
  Kocaeli: { cx: 220.0, cy: 93.0 },
  Konya: { cx: 365.9, cy: 294.1 },
  Kütahya: { cx: 194.6, cy: 195.4 },
  Kırklareli: { cx: 103.5, cy: 28.7 },
  Kırıkkale: { cx: 414.9, cy: 170.6 },
  Kırşehir: { cx: 433.2, cy: 207.7 },
  Malatya: { cx: 651.4, cy: 259.9 },
  Manisa: { cx: 116.5, cy: 228.5 },
  Mardin: { cx: 795.6, cy: 336.3 },
  Mersin: { cx: 417.7, cy: 380.8 },
  Muğla: { cx: 128.6, cy: 350.8 },
  Muş: { cx: 845.4, cy: 221.4 },
  Nevşehir: { cx: 461.7, cy: 238.2 },
  Niğde: { cx: 463.1, cy: 305.3 },
  Ordu: { cx: 608.1, cy: 111.0 },
  Osmaniye: { cx: 549.0, cy: 341.7 },
  Rize: { cx: 784.1, cy: 93.2 },
  Sakarya: { cx: 250.2, cy: 103.9 },
  Samsun: { cx: 534.1, cy: 75.0 },
  Siirt: { cx: 864.5, cy: 292.3 },
  Sinop: { cx: 477.7, cy: 50.0 },
  Sivas: { cx: 603.1, cy: 192.4 },
  Tekirdağ: { cx: 96.9, cy: 70.3 },
  Tokat: { cx: 561.8, cy: 131.6 },
  Trabzon: { cx: 729.5, cy: 103.4 },
  Tunceli: { cx: 722.1, cy: 212.1 },
  Uşak: { cx: 182.6, cy: 245.8 },
  Van: { cx: 937.9, cy: 243.8 },
  Yalova: { cx: 183.3, cy: 108.6 },
  Yozgat: { cx: 487.6, cy: 188.1 },
  Zonguldak: { cx: 319.6, cy: 70.8 },
  Çanakkale: { cx: 47.7, cy: 129.0 },
  Çankırı: { cx: 398.1, cy: 115.6 },
  Çorum: { cx: 468.4, cy: 118.5 },
  İstanbul: { cx: 173.0, cy: 66.6 },
  İzmir: { cx: 75.7, cy: 232.0 },
  Şanlıurfa: { cx: 697.6, cy: 338.3 },
  Şırnak: { cx: 885.0, cy: 321.9 },
}

// Rehber sayısına göre dolgu rengi (sabit 5 kademe + gri). Opaklık değil, doğrudan
// mavi ton kademeleri kullanılır → düşük opaklıkta gri'ye kayma sorunu olmaz.
// 0 → gri; 1 → en açık mavi; 11+ → en koyu mavi.
const GREY = '#d5d8de'
const BLUE_STEPS = ['#cfe3fb', '#90c0f4', '#4a90e2', '#1f6fd0', '#0b4a9c'] // açık → koyu

export function colorForCount(count: number): string {
  if (count <= 0)
    return GREY
  if (count === 1)
    return BLUE_STEPS[0]
  if (count <= 3)
    return BLUE_STEPS[1]
  if (count <= 6)
    return BLUE_STEPS[2]
  if (count <= 10)
    return BLUE_STEPS[3]

  return BLUE_STEPS[4]
}
