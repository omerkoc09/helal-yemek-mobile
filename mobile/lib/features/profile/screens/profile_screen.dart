import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/config/legal_links.dart';
import '../../../core/models/user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
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
        padding: const EdgeInsets.fromLTRB(
          16, 16, 16, 16 + AppTheme.bottomNavClearance,
        ),
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
          _RoleBadge(role: user.role, guideCity: user.guideCity),
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

          // Hakkında ve Yasal — gizlilik politikası URL'si mağaza listesinde
          // zorunlu alan; uygulama içinden de erişilebilir olması bekleniyor.
          const _LegalSection(),

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

          const SizedBox(height: 24),
          // Hesap silme — App Store Guideline 5.1.1(v) ve Google Play zorunluluğu.
          // Çıkıştan görsel olarak ayrılıyor: yıkıcı ve geri alınamaz bir işlem,
          // yanlışlıkla basılmaması için düz metin buton olarak veriliyor.
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref),
              child: Text(
                'Hesabımı Sil',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// İki aşamalı onay: silme geri alınamıyor, tek dokunuşla tetiklenmemeli.
  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabınızı silmek istiyor musunuz?'),
        content: const Text(
          'Bu işlem geri alınamaz.\n\n'
          '• Adınız, e-postanız ve telefonunuz kalıcı olarak silinir\n'
          '• Favorileriniz ve bildirimleriniz silinir\n'
          '• Eklediğiniz mekanlar ve yorumlarınız toplulukta kalır, '
          'ancak adınız görünmez',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Devam',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // İkinci aşama: son uyarı.
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Son onay'),
        content: const Text(
          'Hesabınız kalıcı olarak silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hesabımı Sil',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !context.mounted) return;

    final error = await ref.read(authProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    if (error != null) {
      AppToast.error(context, error);
      return;
    }
    // Başarılı: authProvider oturumu kapattı, router girişe yönlendirir.
    AppToast.success(context, 'Hesabınız silindi.');
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
  final String? guideCity;

  const _RoleBadge({required this.role, this.guideCity});

  @override
  Widget build(BuildContext context) {
    // Rehber için şehir atanmışsa "<Şehir> Rehberi", yoksa sade "Rehber".
    final guideLabel = (guideCity != null && guideCity!.trim().isNotEmpty)
        ? '${guideCity!.trim()} Rehberi'
        : 'Rehber';

    final (label, icon, color) = switch (role) {
      'admin' => ('Admin', Icons.admin_panel_settings, Colors.deepPurple),
      'guide' => (guideLabel, Icons.tour, AppTheme.primary),
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

/// Hakkında ve Yasal bölümü.
///
/// Metinler uygulamaya gömülmüyor, web'de barındırılıyor: mağaza listesi zaten
/// bir gizlilik politikası URL'si istiyor ve metin değişince uygulama
/// güncellemesi beklemek gerekmesin.
class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Hakkında ve Yasal',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        _LegalTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Gizlilik Politikası',
          url: LegalLinks.privacyPolicy,
        ),
        _LegalTile(
          icon: Icons.description_outlined,
          title: 'Kullanım Şartları',
          url: LegalLinks.termsOfService,
        ),
        _LegalTile(
          icon: Icons.shield_outlined,
          title: 'KVKK Aydınlatma Metni',
          url: LegalLinks.kvkkNotice,
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Sürüm $appVersion',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String url;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.open_in_new, size: 16, color: AppTheme.textSecondary),
      onTap: () => _openLegalUrl(context, url),
    );
  }

  /// Adres açılamazsa sessiz kalmıyoruz: kullanıcı yasal metne ulaşamadığını
  /// bilmeli (ör. cihazda tarayıcı yok ya da adres henüz yayında değil).
  Future<void> _openLegalUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppToast.error(context, 'Sayfa açılamadı: $url');
    }
  }
}
