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
      ]);
      setState(() {
        _verified  = (results[0].data?['data'] as List?) ?? [];
        _suspended = (results[1].data?['data'] as List?) ?? [];
        _upcoming  = (results[2].data?['data'] as List?) ?? [];
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
                _LogList(items: _upcoming, actionLabel: null, onAction: null),
              ],
            ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<dynamic> items;
  final String? actionLabel;
  final void Function(String venueId)? onAction;

  const _LogList({required this.items, this.actionLabel, this.onAction});

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

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(item['venue_name'] as String? ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
