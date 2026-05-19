import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

class VerificationLogsScreen extends ConsumerStatefulWidget {
  const VerificationLogsScreen({super.key});

  @override
  ConsumerState<VerificationLogsScreen> createState() => _VerificationLogsScreenState();
}

class _VerificationLogsScreenState extends ConsumerState<VerificationLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<dynamic> _verified = [];
  List<dynamic> _suspended = [];
  List<dynamic> _upcoming = [];
  Set<String> _warnedVenueIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get<Map<String, dynamic>>('${ApiEndpoints.adminVerificationLogs}?tab=verified'),
        api.get<Map<String, dynamic>>('${ApiEndpoints.adminVerificationLogs}?tab=suspended'),
        api.get<Map<String, dynamic>>('${ApiEndpoints.adminVerificationLogs}?tab=upcoming'),
        api.get<Map<String, dynamic>>('${ApiEndpoints.adminVerificationLogs}?tab=warnings'),
      ]);
      final warnings = (results[3].data?['data'] as List?) ?? [];
      setState(() {
        _verified  = (results[0].data?['data'] as List?) ?? [];
        _suspended = (results[1].data?['data'] as List?) ?? [];
        _upcoming  = (results[2].data?['data'] as List?) ?? [];
        _warnedVenueIds = {
          for (final w in warnings)
            if (w['venue_id'] != null) w['venue_id'] as String,
        };
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reactivate(String venueId) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.put(ApiEndpoints.adminReactivateVenue(venueId), data: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mekan yeniden aktive edildi'), backgroundColor: Colors.green));
      _fetchAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarısız')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doğrulama Logları'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Son Doğrulamalar'),
            Tab(text: 'Askıdakiler'),
            Tab(text: 'Yaklaşanlar'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : TabBarView(
              controller: _tabController,
              children: [
                _LogList(items: _verified, actionLabel: null, onAction: null),
                _LogList(items: _suspended, actionLabel: 'Aktive Et', onAction: _reactivate),
                _LogList(items: _upcoming, actionLabel: null, onAction: null, warnedVenueIds: _warnedVenueIds),
              ],
            ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<dynamic> items;
  final String? actionLabel;
  final void Function(String venueId)? onAction;
  final Set<String> warnedVenueIds;

  const _LogList({
    required this.items,
    this.actionLabel,
    this.onAction,
    this.warnedVenueIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Kayıt yok'));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index] as Map<String, dynamic>;
          final venueId = item['venue_id'] as String? ?? '';
          final dt = item['created_at'] != null
              ? DateTime.tryParse(item['created_at'] as String)
              : null;

          final isWarned = warnedVenueIds.contains(venueId);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(item['venue_name'] as String? ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (isWarned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active, size: 11, color: Colors.orange.shade700),
                          const SizedBox(width: 3),
                          Text('Bildirim gönderildi',
                            style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['guide_name'] as String? ?? '-'),
                  Text(item['city'] as String? ?? '-',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dt != null)
                    Text(DateFormat('dd MMM yy', 'tr').format(dt),
                      style: const TextStyle(fontSize: 11)),
                  if (actionLabel != null && onAction != null)
                    GestureDetector(
                      onTap: () => onAction!(venueId),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(actionLabel!,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
