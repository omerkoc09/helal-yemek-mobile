import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../../guide/screens/guide_apply_screen.dart';

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
            _GuideApplicationSection(),
            const SizedBox(height: 16),
          ],

          // Guide menü öğeleri
          if (user.isGuide || user.isAdmin) ...[
            _MenuTile(
              icon: Icons.store_outlined,
              title: 'Mekanlarım',
              subtitle: 'Eklediğiniz mekanları görüntüleyin',
              onTap: () => context.push(AppRoutes.myVenues),
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
          '${user.name}${user.surname != null && user.surname!.isNotEmpty ? ' ${user.surname}' : ''}',
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

class _GuideApplicationSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GuideApplicationSection> createState() =>
      _GuideApplicationSectionState();
}

class _GuideApplicationSectionState
    extends ConsumerState<_GuideApplicationSection> {
  @override
  void initState() {
    super.initState();
    // Açılışta mevcut başvuru durumunu çek (kalıcı pending/rejected gösterimi).
    Future.microtask(
        () => ref.read(guideApplicationProvider.notifier).fetchStatus());
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(guideApplicationProvider);

    // "inceleniyor" kartı — pending başvuru veya yeni gönderim (isSuccess).
    if (appState.currentStatus == 'pending' || appState.isSuccess) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, color: AppTheme.pinPending),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rehber Başvurusu',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Başvurunuz inceleniyor.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Reddedilen başvuru bildirimi (varsa) + başvur butonu.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appState.currentStatus == 'rejected') ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appState.note != null && appState.note!.isNotEmpty
                          ? 'Önceki başvurunuz reddedildi: ${appState.note}'
                          : 'Önceki başvurunuz reddedildi. Tekrar başvurabilirsiniz.',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const GuideApplyScreen()),
              );
              if (ok == true) {
                ref.read(guideApplicationProvider.notifier).fetchStatus();
              }
            },
            child: const Text('Rehber Olmak İçin Başvur'),
          ),
        ),
      ],
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
