import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminStatsProvider.notifier).fetchStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
            onPressed: () => _showProfileSheet(context, ref),
          ),
        ],
      ),
      body: stats.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminStatsProvider.notifier).fetchStats(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // İstatistik kartları
                  _StatCard(
                    icon: Icons.store_outlined,
                    label: 'Bekleyen Mekanlar',
                    count: stats.pendingVenues,
                    color: AppTheme.pinPending,
                    onTap: () => context.push(AppRoutes.adminPendingVenues),
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.person_add_outlined,
                    label: 'Guide Başvuruları',
                    count: stats.pendingApplications,
                    color: Colors.blue,
                    onTap: () => context.push(AppRoutes.adminApplications),
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.edit_note_outlined,
                    label: 'Düzeltme Önerileri',
                    count: stats.pendingCorrections,
                    color: Colors.purple,
                    onTap: () => context.push(AppRoutes.adminCorrections),
                  ),
                  const SizedBox(height: 24),

                  // Hızlı erişim
                  const Text(
                    'Hızlı Erişim',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickAccessTile(
                    icon: Icons.store,
                    label: 'Tüm Mekanlar',
                    subtitle: 'Tüm mekanları görüntüle, düzenle, sil',
                    onTap: () => context.push(AppRoutes.adminAllVenues),
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessTile(
                    icon: Icons.people,
                    label: 'Kullanıcılar',
                    subtitle: 'Tüm kullanıcıları yönet',
                    onTap: () => context.push(AppRoutes.adminUsers),
                  ),
                  const SizedBox(height: 8),
                  _QuickAccessTile(
                    icon: Icons.history,
                    label: 'Audit Log',
                    subtitle: 'Tüm admin işlem geçmişi',
                    onTap: () => context.push(AppRoutes.adminAuditLog),
                  ),
                ],
              ),
            ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings,
                      size: 16, color: Colors.deepPurple),
                  SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              title: const Text('Bilgilerimi Düzenle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showEditProfileDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Çıkış Yap'),
                    content: const Text(
                        'Hesabınızdan çıkış yapmak istiyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  ref.read(authProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bilgilerimi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final data = <String, dynamic>{};
              if (nameCtrl.text.trim() != user.name) {
                data['name'] = nameCtrl.text.trim();
              }
              if (emailCtrl.text.trim() != user.email) {
                data['email'] = emailCtrl.text.trim();
              }
              if (data.isEmpty) return;

              final ok = await ref
                  .read(adminUsersProvider.notifier)
                  .updateUser(user.id, data);

              if (mounted) {
                if (ok) {
                  // Auth state'teki kullanıcıyı güncelle
                  final updatedUser = user.copyWith(
                    name: data['name'] as String? ?? user.name,
                    email: data['email'] as String? ?? user.email,
                  );
                  ref.read(authProvider.notifier).updateUser(updatedUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bilgileriniz güncellendi')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Güncelleme başarısız')),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count bekliyor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: count > 0 ? color : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
