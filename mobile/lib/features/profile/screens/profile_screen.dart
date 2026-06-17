import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar ve kullanıcı bilgileri
          _ProfileHeader(user: user),
          const SizedBox(height: 12),

          // Profili düzenle butonu
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Profili Düzenle'),
          ),
          const SizedBox(height: 12),

          // Rol bilgisi
          _RoleBadge(role: user.role),
          const SizedBox(height: 24),

          // Guide başvurusu (sadece Traveler için)
          if (user.isTraveler) ...[
            _GuideApplicationCard(),
            const SizedBox(height: 16),
          ],

          // Guide menü öğeleri
          if (user.isGuide || user.isAdmin) ...[
            _ReferralCodeCard(),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.store_outlined,
              title: 'Mekanlarım',
              subtitle: 'Eklediğiniz mekanları görüntüleyin',
              onTap: () => context.push(AppRoutes.myVenues),
            ),
            const SizedBox(height: 8),
          ],

          // Admin menü öğeleri
          if (user.isAdmin) ...[
            _MenuTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Paneli',
              subtitle: 'Yönetim işlemlerini gerçekleştirin',
              onTap: () => context.push(AppRoutes.adminDashboard),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Çıkış butonu
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content:
                      const Text('Hesabınızdan çıkış yapmak istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text(
              'Çıkış Yap',
              style: TextStyle(color: AppTheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          backgroundImage:
              user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(
                  user.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
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
            fontSize: 22,
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
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (role) {
      'admin' => ('Admin', Icons.admin_panel_settings, Colors.deepPurple),
      'guide' => ('Rehber', Icons.tour, AppTheme.primary),
      _ => ('Gezgin', Icons.explore, Colors.blue),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideApplicationCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GuideApplicationCard> createState() =>
      _GuideApplicationCardState();
}

class _GuideApplicationCardState extends ConsumerState<_GuideApplicationCard> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(guideApplicationProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tour_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Rehber Ol',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Rehber olarak helal mekanlar ekleyebilir ve topluluğa katkıda bulunabilirsiniz. Başvurmak için bir rehberden aldığınız referans kodunu girin.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
              decoration: const InputDecoration(
                labelText: 'Referans Kodu',
                hintText: 'Örn: A7X3K',
                prefixIcon: Icon(Icons.vpn_key_outlined),
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (appState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                appState.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: appState.isLoading ||
                        _codeController.text.trim().length < 5
                    ? null
                    : () => ref
                        .read(guideApplicationProvider.notifier)
                        .apply(_codeController.text.trim()),
                child: appState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Başvur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCodeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rcState = ref.watch(referralCodeProvider);

    // İlk yüklemede kodu çek
    if (rcState.code == null && !rcState.isLoading && rcState.error == null) {
      Future.microtask(
          () => ref.read(referralCodeProvider.notifier).fetch());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Referans Kodunuz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu kodu paylaşarak yeni rehberlerin başvurmasını sağlayabilirsiniz.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            if (rcState.isLoading)
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (rcState.error != null)
              Text(
                rcState.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
              )
            else if (rcState.code != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rcState.code!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppTheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppTheme.primary),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: rcState.code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referans kodu kopyalandı'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
