import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';

class GuideApplicationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? currentStatus; // pending | approved | rejected | null

  const GuideApplicationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.currentStatus,
  });

  GuideApplicationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? currentStatus,
  }) {
    return GuideApplicationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      currentStatus: currentStatus ?? this.currentStatus,
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
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        currentStatus: 'pending',
      );
    } catch (e) {
      String errorMsg = 'Başvuru gönderilemedi. Lütfen tekrar deneyin.';
      if (e.toString().contains('400')) {
        errorMsg = 'Geçersiz veya kullanılmış referans kodu.';
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
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
