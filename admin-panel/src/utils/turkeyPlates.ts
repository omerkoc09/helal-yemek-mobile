// Türkiye plaka kodu → kanonik il adı (backend cities.go TurkishCities ile birebir).
export const PLATE_TO_CITY: Record<string, string> = {
  '01': 'Adana', '02': 'Adıyaman', '03': 'Afyonkarahisar', '04': 'Ağrı', '05': 'Amasya',
  '06': 'Ankara', '07': 'Antalya', '08': 'Artvin', '09': 'Aydın', '10': 'Balıkesir',
  '11': 'Bilecik', '12': 'Bingöl', '13': 'Bitlis', '14': 'Bolu', '15': 'Burdur',
  '16': 'Bursa', '17': 'Çanakkale', '18': 'Çankırı', '19': 'Çorum', '20': 'Denizli',
  '21': 'Diyarbakır', '22': 'Edirne', '23': 'Elazığ', '24': 'Erzincan', '25': 'Erzurum',
  '26': 'Eskişehir', '27': 'Gaziantep', '28': 'Giresun', '29': 'Gümüşhane', '30': 'Hakkâri',
  '31': 'Hatay', '32': 'Isparta', '33': 'Mersin', '34': 'İstanbul', '35': 'İzmir',
  '36': 'Kars', '37': 'Kastamonu', '38': 'Kayseri', '39': 'Kırklareli', '40': 'Kırşehir',
  '41': 'Kocaeli', '42': 'Konya', '43': 'Kütahya', '44': 'Malatya', '45': 'Manisa',
  '46': 'Kahramanmaraş', '47': 'Mardin', '48': 'Muğla', '49': 'Muş', '50': 'Nevşehir',
  '51': 'Niğde', '52': 'Ordu', '53': 'Rize', '54': 'Sakarya', '55': 'Samsun',
  '56': 'Siirt', '57': 'Sinop', '58': 'Sivas', '59': 'Tekirdağ', '60': 'Tokat',
  '61': 'Trabzon', '62': 'Tunceli', '63': 'Şanlıurfa', '64': 'Uşak', '65': 'Van',
  '66': 'Yozgat', '67': 'Zonguldak', '68': 'Aksaray', '69': 'Bayburt', '70': 'Karaman',
  '71': 'Kırıkkale', '72': 'Batman', '73': 'Şırnak', '74': 'Bartın', '75': 'Ardahan',
  '76': 'Iğdır', '77': 'Yalova', '78': 'Karabük', '79': 'Kilis', '80': 'Osmaniye', '81': 'Düzce',
}

// İl sayı etiketinin yerleşeceği nokta (SVG viewBox 0 0 1871.824 952.756 uzayında,
// her <g data-plate> grubunun bounding-box merkezi).
export const PLATE_CENTROID: Record<string, { cx: number; cy: number }> = {
  '01': { cx: 970.3, cy: 583.7 }, '02': { cx: 1240.6, cy: 543.5 }, '03': { cx: 492.8, cy: 453.3 },
  '04': { cx: 1730.9, cy: 334.4 }, '05': { cx: 983.0, cy: 184.7 }, '06': { cx: 654.6, cy: 301.0 },
  '07': { cx: 515.7, cy: 673.6 }, '08': { cx: 1582.5, cy: 136.4 }, '09': { cx: 223.9, cy: 551.2 },
  '10': { cx: 210.1, cy: 293.2 }, '11': { cx: 445.0, cy: 253.2 }, '12': { cx: 1459.6, cy: 391.5 },
  '13': { cx: 1629.8, cy: 455.9 }, '14': { cx: 581.4, cy: 191.0 }, '15': { cx: 436.5, cy: 601.3 },
  '16': { cx: 328.0, cy: 253.9 }, '17': { cx: 95.1, cy: 252.7 }, '18': { cx: 753.8, cy: 180.8 },
  '19': { cx: 887.5, cy: 186.0 }, '20': { cx: 360.3, cy: 557.2 }, '21': { cx: 1423.2, cy: 504.1 },
  '22': { cx: 85.0, cy: 103.2 }, '23': { cx: 1338.3, cy: 429.8 }, '24': { cx: 1354.8, cy: 323.4 },
  '25': { cx: 1541.0, cy: 259.0 }, '26': { cx: 522.9, cy: 316.9 }, '27': { cx: 1133.7, cy: 627.5 },
  '28': { cx: 1261.0, cy: 198.5 }, '29': { cx: 1344.4, cy: 226.5 }, '30': { cx: 1797.3, cy: 594.2 },
  '31': { cx: 1034.5, cy: 715.7 }, '32': { cx: 512.6, cy: 527.1 }, '33': { cx: 799.7, cy: 676.3 },
  '34': { cx: 321.7, cy: 115.4 }, '35': { cx: 166.7, cy: 442.1 }, '36': { cx: 1686.5, cy: 203.2 },
  '37': { cx: 784.8, cy: 88.3 }, '38': { cx: 998.8, cy: 461.3 }, '39': { cx: 179.4, cy: 56.5 },
  '40': { cx: 818.2, cy: 353.9 }, '41': { cx: 411.1, cy: 156.4 }, '42': { cx: 702.1, cy: 514.7 },
  '43': { cx: 378.2, cy: 350.5 }, '44': { cx: 1224.9, cy: 454.2 }, '45': { cx: 240.2, cy: 424.6 },
  '46': { cx: 1105.7, cy: 533.0 }, '47': { cx: 1486.9, cy: 602.9 }, '48': { cx: 278.1, cy: 648.3 },
  '49': { cx: 1587.4, cy: 393.0 }, '50': { cx: 882.5, cy: 414.0 }, '51': { cx: 874.7, cy: 536.3 },
  '52': { cx: 1147.2, cy: 175.8 }, '53': { cx: 1484.0, cy: 151.6 }, '54': { cx: 475.1, cy: 173.5 },
  '55': { cx: 1014.6, cy: 106.6 }, '56': { cx: 1608.2, cy: 528.7 }, '57': { cx: 898.1, cy: 61.3 },
  '58': { cx: 1138.4, cy: 326.4 }, '59': { cx: 171.2, cy: 130.0 }, '60': { cx: 1063.2, cy: 215.9 },
  '61': { cx: 1382.9, cy: 165.8 }, '62': { cx: 1355.1, cy: 371.3 }, '63': { cx: 1306.5, cy: 601.5 },
  '64': { cx: 363.9, cy: 449.9 }, '65': { cx: 1749.5, cy: 450.6 }, '66': { cx: 923.9, cy: 315.6 },
  '67': { cx: 602.4, cy: 103.5 }, '68': { cx: 797.2, cy: 447.9 }, '69': { cx: 1418.8, cy: 234.0 },
  '70': { cx: 753.1, cy: 641.9 }, '71': { cx: 785.5, cy: 284.4 }, '72': { cx: 1534.0, cy: 516.0 },
  '73': { cx: 1646.9, cy: 588.0 }, '74': { cx: 672.7, cy: 69.4 }, '75': { cx: 1684.3, cy: 127.4 },
  '76': { cx: 1797.1, cy: 283.4 }, '77': { cx: 344.0, cy: 190.2 }, '78': { cx: 674.7, cy: 115.1 },
  '79': { cx: 1123.0, cy: 664.8 }, '80': { cx: 1039.7, cy: 600.4 }, '81': { cx: 557.7, cy: 156.7 },
}

// Rehber sayısına göre dolgu opaklığı (sabit 5 kademe). Renk koyuluğu primary token +
// bu opaklıkla elde edilir. 0 → gri zemin tam opak; 1..10 arası açıktan koyuya; 11+ doygun.
export function opacityForCount(count: number): number {
  if (count <= 0) return 1
  if (count === 1) return 0.30
  if (count <= 3) return 0.50
  if (count <= 6) return 0.70
  if (count <= 10) return 0.85
  return 1
}
