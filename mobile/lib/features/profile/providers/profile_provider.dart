import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';

class GuideApplicationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? currentStatus; // pending | approved | rejected | null
  final String? note; // ret notu (rejected durumunda)

  const GuideApplicationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.currentStatus,
    this.note,
  });

  GuideApplicationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? currentStatus,
    String? note,
  }) {
    return GuideApplicationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      currentStatus: currentStatus ?? this.currentStatus,
      note: note ?? this.note,
    );
  }
}

class GuideApplicationNotifier extends Notifier<GuideApplicationState> {
  @override
  GuideApplicationState build() => const GuideApplicationState();

  Future<void> apply(String referralCode) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.guideApply,
        data: {'referral_code': referralCode},
      );

      // Otomatik onay: kullanıcı artık guide. Auth state'i tazele ki UI güncellensin.
      try {
        final me = await apiClient.get(ApiEndpoints.me);
        final user = User.fromJson(me.data as Map<String, dynamic>);
        ref.read(authProvider.notifier).updateUser(user);
      } catch (_) {
        // Rol tazelenemese bile başvuru başarılı; kullanıcı tekrar girince güncellenir.
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        currentStatus: 'approved',
      );
    } catch (e) {
      String errorMsg = 'İşlem başarısız. Lütfen tekrar deneyin.';
      if (e.toString().contains('400')) {
        errorMsg = 'Geçersiz referans kodu.';
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
    }
  }

  Future<void> applyWithoutCode() async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.guideApply,
        data: {'terms_accepted': true},
      );
      // Kodsuz başvuru pending'e düşer; rol değişmez, auth tazelenmez.
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        currentStatus: 'pending',
      );
    } catch (e) {
      String errorMsg = 'Başvuru gönderilemedi. Lütfen tekrar deneyin.';
      if (e.toString().contains('409')) {
        errorMsg = 'Bekleyen bir başvurunuz zaten var.';
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
    }
  }

  // Açılışta mevcut başvuru durumunu backend'den çeker (kalıcı pending/rejected gösterimi için).
  Future<void> fetchStatus() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get(ApiEndpoints.guideMyApplication);
      final data = res.data as Map<String, dynamic>;
      state = state.copyWith(
        currentStatus: data['status'] as String?,
        note: data['note'] as String?,
      );
    } catch (_) {
      // 404 = başvuru yok; sessizce geç (normal form gösterilir).
    }
  }
}

final guideApplicationProvider =
    NotifierProvider<GuideApplicationNotifier, GuideApplicationState>(
  GuideApplicationNotifier.new,
);

// Guide referans kodu
class ReferralCodeState {
  final bool isLoading;
  final String? code;
  final String? error;

  const ReferralCodeState({this.isLoading = false, this.code, this.error});

  ReferralCodeState copyWith({bool? isLoading, String? code, String? error}) {
    return ReferralCodeState(
      isLoading: isLoading ?? this.isLoading,
      code: code ?? this.code,
      error: error,
    );
  }
}

class ReferralCodeNotifier extends Notifier<ReferralCodeState> {
  @override
  ReferralCodeState build() => const ReferralCodeState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.guideMyReferralCode);
      final code = response.data['referral_code'] as String;
      state = ReferralCodeState(code: code);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Referans kodu alınamadı.',
      );
    }
  }
}

final referralCodeProvider =
    NotifierProvider<ReferralCodeNotifier, ReferralCodeState>(
  ReferralCodeNotifier.new,
);

// Profil düzenleme
class EditProfileState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const EditProfileState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  EditProfileState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class EditProfileNotifier extends Notifier<EditProfileState> {
  @override
  EditProfileState build() => const EditProfileState();

  Future<void> updateProfile({required String name}) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        ApiEndpoints.updateProfile,
        data: {'name': name},
      );
      final user =
          User.fromJson(response.data as Map<String, dynamic>);
      ref.read(authProvider.notifier).updateUser(user);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profil güncellenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  void reset() {
    state = const EditProfileState();
  }
}

final editProfileProvider =
    NotifierProvider<EditProfileNotifier, EditProfileState>(
  EditProfileNotifier.new,
);
