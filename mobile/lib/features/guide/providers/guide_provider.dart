import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/google_maps_parser.dart';

// ─── Add Venue State ───

class AddVenueState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  // Wizard adımları
  final int currentStep;
  final String name;
  final String address;
  final String city; // İl
  final String district; // İlçe
  final String mapsLink; // Google Maps linki
  final bool isParsingLink; // Link parse ediliyor mu
  final double? latitude;
  final double? longitude;
  final List<int> selectedCriteriaIds;
  final String? notes;
  final List<String> photoPaths; // Yerel dosya yolları

  // Yemek kategorileri
  final Map<int, List<int>> selectedFoodItemIds; // kategori ID → seçili item ID listesi
  final bool allFoodSelected; // "Tüm Yemekler Caiz" flag

  const AddVenueState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.currentStep = 0,
    this.name = '',
    this.address = '',
    this.city = '',
    this.district = '',
    this.mapsLink = '',
    this.isParsingLink = false,
    this.latitude,
    this.longitude,
    this.selectedCriteriaIds = const [],
    this.notes,
    this.photoPaths = const [],
    this.selectedFoodItemIds = const {},
    this.allFoodSelected = false,
  });

  AddVenueState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    int? currentStep,
    String? name,
    String? address,
    String? city,
    String? district,
    String? mapsLink,
    bool? isParsingLink,
    double? latitude,
    double? longitude,
    List<int>? selectedCriteriaIds,
    String? notes,
    List<String>? photoPaths,
    Map<int, List<int>>? selectedFoodItemIds,
    bool? allFoodSelected,
  }) {
    return AddVenueState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      currentStep: currentStep ?? this.currentStep,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      mapsLink: mapsLink ?? this.mapsLink,
      isParsingLink: isParsingLink ?? this.isParsingLink,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      selectedCriteriaIds: selectedCriteriaIds ?? this.selectedCriteriaIds,
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      selectedFoodItemIds: selectedFoodItemIds ?? this.selectedFoodItemIds,
      allFoodSelected: allFoodSelected ?? this.allFoodSelected,
    );
  }

  bool get canProceedStep0 => name.trim().isNotEmpty;
  bool get canProceedStep1 =>
      latitude != null &&
      longitude != null &&
      city.isNotEmpty &&
      district.isNotEmpty;
  bool get canProceedStep2 => selectedCriteriaIds.isNotEmpty;
  // Step 3 (not + fotoğraf) opsiyonel, her zaman geçilebilir
  bool get canProceedStep3 => true;
  // Step 4 (yemek kategorileri) — en az 1 seçim yapılmalı veya "Tüm Yemekler Caiz" seçili olmalı
  bool get canProceedStep4 =>
      allFoodSelected ||
      selectedFoodItemIds.values.any((items) => items.isNotEmpty);
}

class AddVenueNotifier extends Notifier<AddVenueState> {
  @override
  AddVenueState build() => const AddVenueState();

  void setName(String name) => state = state.copyWith(name: name);

  void setCity(String city) {
    state = state.copyWith(city: city, district: '');
  }

  void setDistrict(String district) {
    state = state.copyWith(district: district);
  }

  void setAddress(String address) {
    state = state.copyWith(address: address);
  }

  void setCoordinates({required double latitude, required double longitude}) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
  }

  /// Google Maps linkini parse edip koordinatları çıkarır.
  Future<bool> parseMapsLink(String link) async {
    state = state.copyWith(mapsLink: link, isParsingLink: true, error: null);

    if (link.trim().isEmpty) {
      state = state.copyWith(isParsingLink: false);
      return false;
    }

    if (!GoogleMapsParser.isValidMapsLink(link)) {
      state = state.copyWith(
        isParsingLink: false,
        error: 'Geçerli bir Google Maps linki girin.',
      );
      return false;
    }

    final coords = await GoogleMapsParser.parseLink(link);
    if (coords != null) {
      state = state.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
        isParsingLink: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isParsingLink: false,
        error: 'Linkten koordinat çıkarılamadı. Haritada manuel seçim yapabilirsiniz.',
      );
      return false;
    }
  }

  void toggleCriteria(int criteriaId) {
    final ids = List<int>.from(state.selectedCriteriaIds);
    if (ids.contains(criteriaId)) {
      ids.remove(criteriaId);
    } else {
      ids.add(criteriaId);
    }
    state = state.copyWith(selectedCriteriaIds: ids);
  }

  void setNotes(String? notes) => state = state.copyWith(notes: notes);

  void addPhoto(String path) {
    state = state.copyWith(photoPaths: [...state.photoPaths, path]);
  }

  void removePhoto(String path) {
    state = state.copyWith(
      photoPaths: state.photoPaths.where((p) => p != path).toList(),
    );
  }

  // ─── Food Methods ───

  void toggleAllFood() {
    state = state.copyWith(
      allFoodSelected: !state.allFoodSelected,
      selectedFoodItemIds: !state.allFoodSelected ? {} : state.selectedFoodItemIds,
    );
  }

  void toggleFoodItem(int categoryId, int itemId) {
    final map = Map<int, List<int>>.from(state.selectedFoodItemIds);
    final items = List<int>.from(map[categoryId] ?? []);
    if (items.contains(itemId)) {
      items.remove(itemId);
    } else {
      items.add(itemId);
    }
    map[categoryId] = items;
    state = state.copyWith(selectedFoodItemIds: map, allFoodSelected: false);
  }

  void selectAllInCategory(int categoryId, List<int> allItemIds) {
    final map = Map<int, List<int>>.from(state.selectedFoodItemIds);
    map[categoryId] = List<int>.from(allItemIds);
    state = state.copyWith(selectedFoodItemIds: map, allFoodSelected: false);
  }

  void deselectAllInCategory(int categoryId) {
    final map = Map<int, List<int>>.from(state.selectedFoodItemIds);
    map[categoryId] = [];
    state = state.copyWith(selectedFoodItemIds: map);
  }

  /// Kullanıcının eklediği özel çeşidi backend'e kaydeder ve seçili olarak ekler.
  Future<void> addCustomFoodItem(int categoryId, String label) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiEndpoints.foodCategoryItems(categoryId.toString()),
        data: {'label_tr': label},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data['data'] as Map<String, dynamic>);
      final itemId = data['id'] as int;

      // Yeni eklenen çeşidi seçili olarak işaretle
      final map = Map<int, List<int>>.from(state.selectedFoodItemIds);
      final items = List<int>.from(map[categoryId] ?? []);
      if (!items.contains(itemId)) {
        items.add(itemId);
      }
      map[categoryId] = items;
      state = state.copyWith(selectedFoodItemIds: map);

      // Kategori listesini yenilemek için provider'ı invalidate et
      ref.invalidate(foodCategoriesProvider);
    } catch (e) {
      state = state.copyWith(
        error: 'Yemek çeşidi eklenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Seçili yemeklerin tüm food_item_id listesini döndürür (tek düz liste).
  List<int> get allSelectedFoodItemIds {
    final ids = <int>[];
    for (final items in state.selectedFoodItemIds.values) {
      ids.addAll(items);
    }
    return ids;
  }

  // Bir kategorideki tüm çeşitler seçili mi?
  // (Çiğ Köfte gibi alt çeşidi olmayan kategoriler için kullanılmaz.)
  bool isCategoryFullySelected(int categoryId, int totalItemCount) {
    if (totalItemCount == 0) return false;
    final selected = state.selectedFoodItemIds[categoryId] ?? [];
    return selected.length >= totalItemCount;
  }

  void nextStep() {
    if (state.currentStep < 5) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 5) {
      state = state.copyWith(currentStep: step);
    }
  }

  Future<void> submit() async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);

      // 1. Mekan oluştur
      final response = await apiClient.post(
        ApiEndpoints.venues,
        data: {
          'name': state.name.trim(),
          'address': state.district,
          'city': state.city,
          'country': 'Türkiye',
          'latitude': state.latitude,
          'longitude': state.longitude,
          'criteria_ids': state.selectedCriteriaIds,
          'notes': state.notes?.trim(),
          'all_food_halal': state.allFoodSelected,
          'food_item_ids': allSelectedFoodItemIds,
        },
      );

      final venueData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data['data'] as Map<String, dynamic>);
      final venueId = venueData['id'] as String;

      // 2. Fotoğrafları yükle
      for (final path in state.photoPaths) {
        final formData = FormData.fromMap({
          'photo': await MultipartFile.fromFile(path),
        });
        await apiClient.upload(
          ApiEndpoints.venuePhotos(venueId),
          formData: formData,
        );
      }

      state = state.copyWith(isLoading: false, isSuccess: true, currentStep: 5);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekan eklenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  void reset() => state = const AddVenueState();
}

final addVenueProvider = NotifierProvider<AddVenueNotifier, AddVenueState>(
  AddVenueNotifier.new,
);

// ─── My Venues State ───

class MyVenuesState {
  final List<Venue> venues;
  final bool isLoading;
  final String? error;

  const MyVenuesState({
    this.venues = const [],
    this.isLoading = false,
    this.error,
  });

  MyVenuesState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? error,
  }) {
    return MyVenuesState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MyVenuesNotifier extends Notifier<MyVenuesState> {
  @override
  MyVenuesState build() => const MyVenuesState();

  Future<void> fetchMyVenues() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.guideMyVenues);

      final data = response.data;
      final List<dynamic> venueList = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(venues: venues, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekanlar yüklenemedi.',
      );
    }
  }
}

final myVenuesProvider = NotifierProvider<MyVenuesNotifier, MyVenuesState>(
  MyVenuesNotifier.new,
);

// ─── Edit Venue State ───

class EditVenueState {
  final bool isLoading;
  final bool isLoadingVenue;
  final String? error;
  final bool isSuccess;

  final String venueId;
  final String name;
  final String address;
  final String city;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final List<int> selectedCriteriaIds;
  final List<int> selectedFoodItemIds;
  final bool allFoodHalal;

  // Google Maps link parse
  final String mapsLink;
  final bool isParsingLink;

  const EditVenueState({
    this.isLoading = false,
    this.isLoadingVenue = false,
    this.error,
    this.isSuccess = false,
    this.venueId = '',
    this.name = '',
    this.address = '',
    this.city = '',
    this.notes,
    this.latitude,
    this.longitude,
    this.selectedCriteriaIds = const [],
    this.selectedFoodItemIds = const [],
    this.allFoodHalal = false,
    this.mapsLink = '',
    this.isParsingLink = false,
  });

  EditVenueState copyWith({
    bool? isLoading,
    bool? isLoadingVenue,
    String? error,
    bool? isSuccess,
    String? venueId,
    String? name,
    String? address,
    String? city,
    String? notes,
    double? latitude,
    double? longitude,
    List<int>? selectedCriteriaIds,
    List<int>? selectedFoodItemIds,
    bool? allFoodHalal,
    String? mapsLink,
    bool? isParsingLink,
  }) {
    return EditVenueState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingVenue: isLoadingVenue ?? this.isLoadingVenue,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      venueId: venueId ?? this.venueId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      selectedCriteriaIds: selectedCriteriaIds ?? this.selectedCriteriaIds,
      selectedFoodItemIds: selectedFoodItemIds ?? this.selectedFoodItemIds,
      allFoodHalal: allFoodHalal ?? this.allFoodHalal,
      mapsLink: mapsLink ?? this.mapsLink,
      isParsingLink: isParsingLink ?? this.isParsingLink,
    );
  }
}

class EditVenueNotifier extends Notifier<EditVenueState> {
  @override
  EditVenueState build() => const EditVenueState();

  Future<void> loadVenue(String venueId) async {
    state = state.copyWith(isLoadingVenue: true, error: null, venueId: venueId);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.venueDetail(venueId));

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data['data'] as Map<String, dynamic>);
      final venue = Venue.fromJson(data);

      state = state.copyWith(
        isLoadingVenue: false,
        venueId: venue.id,
        name: venue.name,
        address: venue.address,
        city: venue.city,
        notes: venue.notes,
        latitude: venue.latitude,
        longitude: venue.longitude,
        selectedCriteriaIds: venue.criteria.map((c) => c.id).toList(),
        selectedFoodItemIds: venue.foodItems.map((f) => f.id).toList(),
        allFoodHalal: venue.allFoodHalal,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingVenue: false,
        error: 'Mekan bilgileri yüklenemedi.',
      );
    }
  }

  void setName(String name) => state = state.copyWith(name: name);
  void setAddress(String address) => state = state.copyWith(address: address);
  void setCity(String city) => state = state.copyWith(city: city);
  void setNotes(String? notes) => state = state.copyWith(notes: notes);

  void setCoordinates({required double latitude, required double longitude}) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
  }

  Future<bool> parseMapsLink(String link) async {
    state = state.copyWith(mapsLink: link, isParsingLink: true, error: null);

    if (link.trim().isEmpty) {
      state = state.copyWith(isParsingLink: false);
      return false;
    }

    if (!GoogleMapsParser.isValidMapsLink(link)) {
      state = state.copyWith(
        isParsingLink: false,
        error: 'Geçerli bir Google Maps linki girin.',
      );
      return false;
    }

    final coords = await GoogleMapsParser.parseLink(link);
    if (coords != null) {
      state = state.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
        isParsingLink: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isParsingLink: false,
        error: 'Linkten koordinat çıkarılamadı.',
      );
      return false;
    }
  }

  void toggleCriteria(int criteriaId) {
    final ids = List<int>.from(state.selectedCriteriaIds);
    if (ids.contains(criteriaId)) {
      ids.remove(criteriaId);
    } else {
      ids.add(criteriaId);
    }
    state = state.copyWith(selectedCriteriaIds: ids);
  }

  void toggleFoodItem(int itemId) {
    final ids = List<int>.from(state.selectedFoodItemIds);
    if (ids.contains(itemId)) {
      ids.remove(itemId);
    } else {
      ids.add(itemId);
    }
    state = state.copyWith(selectedFoodItemIds: ids, allFoodHalal: false);
  }

  void toggleAllFoodHalal() {
    state = state.copyWith(
      allFoodHalal: !state.allFoodHalal,
      selectedFoodItemIds: !state.allFoodHalal ? [] : state.selectedFoodItemIds,
    );
  }

  Future<void> submit() async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.venueDetail(state.venueId),
        data: {
          'name': state.name.trim(),
          'address': state.address.trim(),
          'city': state.city.trim(),
          'latitude': state.latitude,
          'longitude': state.longitude,
          'notes': state.notes?.trim(),
          'criteria_ids': state.selectedCriteriaIds,
          'food_item_ids': state.selectedFoodItemIds,
          'all_food_halal': state.allFoodHalal,
        },
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mekan güncellenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  void reset() => state = const EditVenueState();
}

final editVenueProvider =
    NotifierProvider<EditVenueNotifier, EditVenueState>(
  EditVenueNotifier.new,
);

// ─── Halal Criteria Provider ───

final halalCriteriaProvider = FutureProvider<List<HalalCriteria>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.criteria);

  final data = response.data;
  final List<dynamic> list = data is Map<String, dynamic>
      ? (data['data'] as List? ?? [])
      : (data as List? ?? []);

  return list
      .map((json) => HalalCriteria.fromJson(json as Map<String, dynamic>))
      .toList();
});

// ─── Food Categories Provider ───

final foodCategoriesProvider = FutureProvider<List<FoodCategory>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.foodCategories);

  final data = response.data;
  final List<dynamic> list = data is List
      ? data
      : (data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : []);

  return list
      .map((json) => FoodCategory.fromJson(json as Map<String, dynamic>))
      .toList();
});
