import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class AllVenuesScreen extends ConsumerStatefulWidget {
  const AllVenuesScreen({super.key});

  @override
  ConsumerState<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends ConsumerState<AllVenuesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allVenuesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Mekanlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(allVenuesProvider.notifier).fetch(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.error != null
              ? Center(child: Text(state.error!))
              : state.venues.isEmpty
                  ? const Center(child: Text('Henüz mekan yok.'))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(allVenuesProvider.notifier).fetch(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.venues.length,
                        itemBuilder: (context, index) {
                          final venue = state.venues[index];
                          return Card(
                            child: ListTile(
                              leading: _statusIcon(venue.status),
                              title: Text(venue.name),
                              subtitle: Text(
                                '${venue.city} — ${_statusLabel(venue.status)}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _onAction(action, venue.id, venue.name),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'detail',
                                    child: ListTile(
                                      leading: Icon(Icons.visibility),
                                      title: Text('Detay'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('Düzenle'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.delete, color: Colors.red),
                                      title: Text('Sil',
                                          style:
                                              TextStyle(color: Colors.red)),
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  context.push('/admin/venue/${venue.id}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'rejected':
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylı';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

  void _onAction(String action, String venueId, String venueName) {
    switch (action) {
      case 'detail':
        context.push('/admin/venue/$venueId');
        break;
      case 'edit':
        _showEditDialog(venueId);
        break;
      case 'delete':
        _showDeleteConfirmation(venueId, venueName);
        break;
    }
  }

  void _showEditDialog(String venueId) {
    final venue = ref
        .read(allVenuesProvider)
        .venues
        .firstWhere((v) => v.id == venueId);

    final nameCtrl = TextEditingController(text: venue.name);
    final addressCtrl = TextEditingController(text: venue.address);
    final cityCtrl = TextEditingController(text: venue.city);
    String selectedStatus = venue.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mekanı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Adres'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Durum'),
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('Beklemede')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Onaylı')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Reddedildi')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
              ],
            ),
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
                if (nameCtrl.text != venue.name) data['name'] = nameCtrl.text;
                if (addressCtrl.text != venue.address) {
                  data['address'] = addressCtrl.text;
                }
                if (cityCtrl.text != venue.city) data['city'] = cityCtrl.text;
                if (selectedStatus != venue.status) {
                  data['status'] = selectedStatus;
                }
                if (data.isNotEmpty) {
                  final ok = await ref
                      .read(allVenuesProvider.notifier)
                      .updateVenue(venueId, data);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Mekan güncellendi'
                            : 'Güncelleme başarısız'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String venueId, String venueName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mekanı Sil'),
        content: Text('"$venueName" mekanını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(allVenuesProvider.notifier)
                  .deleteVenue(venueId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Mekan silindi' : 'Silme başarısız'),
                  ),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
