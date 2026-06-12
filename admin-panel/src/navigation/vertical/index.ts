export default [
  { title: 'Dashboard', to: { name: 'index' }, icon: { icon: 'tabler-smart-home' }, role: ['admin'] },
  { title: 'Mekanlar', to: { name: 'venues' }, icon: { icon: 'tabler-building-store' }, role: ['admin'] },
  { title: 'Bekleyen Mekanlar', to: { name: 'venues-pending' }, icon: { icon: 'tabler-clock-hour-4' }, role: ['admin'] },
  { title: 'Kullanıcılar', to: { name: 'users' }, icon: { icon: 'tabler-users' }, role: ['admin'] },
  { title: 'Guide Başvuruları', to: { name: 'applications' }, icon: { icon: 'tabler-user-plus' }, role: ['admin'] },
  { title: 'Düzeltmeler', to: { name: 'corrections' }, icon: { icon: 'tabler-edit' }, role: ['admin'] },
  { title: 'Mekan Raporları', to: { name: 'venue-reports' }, icon: { icon: 'tabler-flag' }, role: ['admin'] },
  { title: 'Audit Log', to: { name: 'audit-logs' }, icon: { icon: 'tabler-history' }, role: ['admin'] },
  { title: 'Doğrulama Logları', to: { name: 'verification-logs' }, icon: { icon: 'tabler-checks' }, role: ['admin'] },
]
