import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/venue_reports_provider.dart';

class VenueReportsScreen extends ConsumerStatefulWidget {
  const VenueReportsScreen({super.key});

  @override
  ConsumerState<VenueReportsScreen> createState() => _VenueReportsScreenState();
}

class _VenueReportsScreenState extends ConsumerState<VenueReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(venueReportsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(venueReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mekan Şikayetleri')),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(VenueReportsState state) {
    if (state.isLoading && state.reports.isEmpty) return const LoadingIndicator();

    if (state.error != null && state.reports.isEmpty) {
      return ErrorRetryWidget(
        message: state.error!,
        onRetry: () => ref.read(venueReportsProvider.notifier).fetch(),
      );
    }

    if (state.reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_off_outlined, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Henüz şikayet yok',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(venueReportsProvider.notifier).fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.reports.length,
        itemBuilder: (context, index) {
          final report = state.reports[index];
          return _ReportCard(
            report: report,
            onTap: () => _showDetail(context, report),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, VenueReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDetailSheet(report: report),
    );
  }
}

// ─── Liste kartı ─────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final VenueReport report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _reasonVisuals(report.reason);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${report.venueName} · ${report.venueCity}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(status: report.status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtDate(report.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detay modal ─────────────────────────────────────────────────────────────

class _ReportDetailSheet extends ConsumerStatefulWidget {
  final VenueReport report;

  const _ReportDetailSheet({required this.report});

  @override
  ConsumerState<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<_ReportDetailSheet> {
  bool _resolving = false;

  // Listedeki güncel state'i takip et (resolve sonrası güncellenir)
  VenueReport get _current {
    final list = ref.read(venueReportsProvider).reports;
    return list.firstWhere((r) => r.id == widget.report.id,
        orElse: () => widget.report);
  }

  @override
  Widget build(BuildContext context) {
    // Listedeki değişikliği yansıt
    ref.watch(venueReportsProvider);
    final report = _current;
    final (_, color, reasonLabel) = _reasonVisuals(report.reason);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Başlık
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reasonLabel,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _StatusChip(status: report.status),
                  ],
                ),
                const SizedBox(height: 20),

                // Mekan bilgileri
                _SectionTitle('Mekan Bilgileri'),
                const SizedBox(height: 8),
                _DetailRow(Icons.store_outlined, 'Mekan',
                    '${report.venueName} · ${report.venueCity}'),
                const SizedBox(height: 6),
                _DetailRow(Icons.person_outline, 'Ekleyen',
                    report.addedByName ?? '—'),
                const SizedBox(height: 6),
                _DetailRow(Icons.email_outlined, 'E-posta',
                    report.addedByEmail ?? '—'),
                const SizedBox(height: 6),
                _DetailRow(Icons.calendar_today_outlined, 'Eklenme tarihi',
                    _fmtDateTime(report.venueAddedAt)),
                const SizedBox(height: 20),

                // Şikayet bilgileri
                _SectionTitle('Şikayet Bilgileri'),
                const SizedBox(height: 8),
                _DetailRow(Icons.flag_outlined, 'Sebep', reasonLabel,
                    valueColor: color),
                if (report.description != null &&
                    report.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _DetailRow(Icons.notes_outlined, 'Açıklama',
                      report.description!),
                ],
                const SizedBox(height: 6),
                _DetailRow(Icons.person_outline, 'Şikayetçi',
                    report.reporterName),
                const SizedBox(height: 6),
                _DetailRow(Icons.email_outlined, 'E-posta',
                    report.reporterEmail),
                const SizedBox(height: 6),
                _DetailRow(Icons.access_time_outlined, 'Şikayet tarihi',
                    _fmtDateTime(report.createdAt)),
                const SizedBox(height: 28),

                // Mekan inceleme sayfasına git
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/admin/venue/${report.venueId}');
                  },
                  icon: const Icon(Icons.store_outlined, size: 18),
                  label: const Text('Mekanı İncele'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),

                // Çözüldü butonu
                if (!report.isResolved)
                  FilledButton.icon(
                    onPressed: _resolving ? null : _resolve,
                    icon: _resolving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Çözüldü olarak işaretle'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                else
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Bu şikayet çözüldü olarak işaretlendi',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final ok =
        await ref.read(venueReportsProvider.notifier).resolve(widget.report.id);
    if (mounted) {
      setState(() => _resolving = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarısız, tekrar deneyin.')),
        );
      }
    }
  }
}

// ─── Yardımcı widget'lar ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor),
            ),
          ),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'resolved' => ('Çözüldü', AppTheme.primary),
      _ => ('Bekliyor', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Ortak yardımcılar ────────────────────────────────────────────────────────

(IconData, Color, String) _reasonVisuals(String reason) => switch (reason) {
      'closed' => (Icons.do_not_disturb_outlined, Colors.red, 'Mekan hizmet vermiyor'),
      'halal_criteria' => (Icons.warning_amber_outlined, Colors.orange, 'Helallik kriteri sorunu'),
      'wrong_address' => (Icons.location_off_outlined, Colors.blue, 'Adres yanlış'),
      'wrong_food' => (Icons.restaurant_outlined, Colors.purple, 'Yemekler yanlış'),
      _ => (Icons.help_outline, AppTheme.textSecondary, 'Diğer'),
    };

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}\n'
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _fmtDateTime(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
