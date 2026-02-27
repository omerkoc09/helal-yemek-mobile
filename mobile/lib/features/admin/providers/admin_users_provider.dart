import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';
import 'admin_provider_utils.dart';

class AdminUsersState {
  final List<User> users;
  final bool isLoading;
  final String? error;

  const AdminUsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  AdminUsersState copyWith({
    List<User>? users,
    bool? isLoading,
    String? error,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() => const AdminUsersState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminUsers);
      final users = parseList<User>(response.data, User.fromJson);
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      debugPrint('AdminUsers fetch error: $e');
      state = state.copyWith(
        isLoading: false,
        error: extractErrorMessage(e, 'Kullanıcılar yüklenemedi.'),
      );
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(ApiEndpoints.adminUser(userId), data: data);
    } catch (e) {
      debugPrint('UpdateUser error: $e');
      return false;
    }
    // Listeyi arka planda yenile, başarısız olsa bile güncelleme başarılı sayılır
    try {
      await fetch();
    } catch (_) {}
    return true;
  }

  Future<bool> deleteUser(String userId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(ApiEndpoints.adminUser(userId));
      state = state.copyWith(
        users: state.users.where((u) => u.id != userId).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('DeleteUser error: $e');
      return false;
    }
  }
}

final adminUsersProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
  AdminUsersNotifier.new,
);
