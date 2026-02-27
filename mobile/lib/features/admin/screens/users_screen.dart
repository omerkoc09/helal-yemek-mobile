import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../providers/admin_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUsersProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcılar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminUsersProvider.notifier).fetch(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.error != null
              ? Center(child: Text(state.error!))
              : state.users.isEmpty
                  ? const Center(child: Text('Henüz kullanıcı yok.'))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(adminUsersProvider.notifier).fetch(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.users.length,
                        itemBuilder: (context, index) {
                          final user = state.users[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _roleColor(user.role).withValues(alpha: 0.15),
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: _roleColor(user.role),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(user.name),
                              subtitle: Text(
                                '${user.email}\n${_roleLabel(user.role)} — ${user.isActive ? "Aktif" : "Pasif"}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _onAction(action, user.id, user.name),
                                itemBuilder: (context) => [
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
                                      leading: Icon(Icons.delete,
                                          color: Colors.red),
                                      title: Text('Sil',
                                          style:
                                              TextStyle(color: Colors.red)),
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'guide':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'guide':
        return 'Rehber';
      default:
        return 'Gezgin';
    }
  }

  void _onAction(String action, String userId, String userName) {
    switch (action) {
      case 'edit':
        _showEditDialog(userId);
        break;
      case 'delete':
        _showDeleteConfirmation(userId, userName);
        break;
    }
  }

  void _showEditDialog(String userId) {
    final user = ref
        .read(adminUsersProvider)
        .users
        .firstWhere((u) => u.id == userId);

    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    String selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kullanıcıyı Düzenle'),
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
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(
                        value: 'traveler', child: Text('Gezgin')),
                    DropdownMenuItem(
                        value: 'guide', child: Text('Rehber')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (val) {
                    setDialogState(() => isActive = val);
                  },
                  contentPadding: EdgeInsets.zero,
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
                if (nameCtrl.text != user.name) data['name'] = nameCtrl.text;
                if (emailCtrl.text != user.email) {
                  data['email'] = emailCtrl.text;
                }
                if (selectedRole != user.role) data['role'] = selectedRole;
                if (isActive != user.isActive) data['is_active'] = isActive;
                if (data.isNotEmpty) {
                  final ok = await ref
                      .read(adminUsersProvider.notifier)
                      .updateUser(userId, data);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Kullanıcı güncellendi'
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

  void _showDeleteConfirmation(String userId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content:
            Text('"$userName" kullanıcısını silmek istediğinize emin misiniz?'),
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
                  .read(adminUsersProvider.notifier)
                  .deleteUser(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        ok ? 'Kullanıcı silindi' : 'Silme başarısız'),
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
