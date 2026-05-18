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
  final bool isLoadingPlaceDetails; // Place Details API çağrısı devam ediyor
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId; // Linkten parse edilen place_id
  final List<String> googlePhotoUrls; // Google Places API'den gelen fotoğraf seçenekleri
  final String? selectedPhotoUrl; // Rehberin seçtiği fotoğraf URL'si
  final List<int> selectedCriteriaIds;
  final String? notes;

  // Yemek kategorileri
  final Map<int, List<int>> selectedFoodItemIds; // kategori ID → seçili item ID listesi
  final String foodHalalMode; // 'all', 'except', 'selected'
  final List<String> excludedProducts; // sakıncalı ürünler (except modunda)
  final bool isManualMode; // Link yok, bilgiler elle girilecek

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
    this.isLoadingPlaceDetails = false,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.googlePhotoUrls = const [],
    this.selectedPhotoUrl,
    this.selectedCriteriaIds = const [],
    this.notes,
    this.selectedFoodItemIds = const {},
    this.foodHalalMode = 'selected',
    this.excludedProducts = const [],
    this.isManualMode = false,
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
    bool? isLoadingPlaceDetails,
    double? latitude,
    double? longitude,
    String? googlePlaceId,
    List<String>? googlePhotoUrls,
    String? selectedPhotoUrl,
    List<int>? selectedCriteriaIds,
    String? notes,
    Map<int, List<int>>? selectedFoodItemIds,
    String? foodHalalMode,
    List<String>? excludedProducts,
    bool? isManualMode,
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
      isLoadingPlaceDetails: isLoadingPlaceDetails ?? this.isLoadingPlaceDetails,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      googlePhotoUrls: googlePhotoUrls ?? this.googlePhotoUrls,
      selectedPhotoUrl: selectedPhotoUrl ?? this.selectedPhotoUrl,
      selectedCriteriaIds: selectedCriteriaIds ?? this.selectedCriteriaIds,
      notes: notes ?? this.notes,
      selectedFoodItemIds: selectedFoodItemIds ?? this.selectedFoodItemIds,
      foodHalalMode: foodHalalMode ?? this.foodHalalMode,
      excludedProducts: excludedProducts ?? this.excludedProducts,
      isManualMode: isManualMode ?? this.isManualMode,
    );
  }

  // Adım 0 = Link adımı: ya koordinat parse edildi ya da manuel mod seçildi
  bool get canProceedStep0 =>
      (latitude != null && longitude != null) || isManualMode;
  // Adım 1 = Detay doğrulama: ad + il + ilçe + koordinat zorunlu
  bool get canProceedStep1 =>
      name.trim().isNotEmpty &&
      city.isNotEmpty &&
      district.isNotEmpty &&
      latitude != null &&
      longitude != null;
  // Step 2 (helal kriterleri + not) — kriter seçimi zorunlu, not opsiyonel
  bool get canProceedStep2 => selectedCriteriaIds.isNotEmpty;
  // Step 3 (yemek kategorileri) — tüm modlarda yemek seçimi zorunlu
  bool get canProceedStep3 {
    final hasFoodItems =
        selectedFoodItemIds.values.any((items) => items.isNotEmpty);
    switch (foodHalalMode) {
      case 'all':
        return hasFoodItems;
      case 'except':
        return hasFoodItems &&
            excludedProducts.any((p) => p.trim().isNotEmpty);
      case 'selected':
        return hasFoodItems;
      default:
        return false;
    }
  }
}

class AddVenueNotifier extends Notifier<AddVenueState> {
  @override
  AddVenueState build() => const AddVenueState();

  void setManualMode(bool value) =>
      state = state.copyWith(isManualMode: value);

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
    // Koordinat manuel değişince place_id geçersiz olur
    state = state.copyWith(latitude: latitude, longitude: longitude, googlePlaceId: null);
  }

  /// Google Maps linkini parse edip koordinat ve place_id'yi çıkarır.
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
      // URL'den gelen adı pre-populate et (kullanıcı sonraki adımda düzeltebilir)
      final nameFromUrl = coords.placeName ?? '';
      state = state.copyWith(
        latitude: coords.latitude,
        longitude: coords.longitude,
        googlePlaceId: coords.placeId,
        name: nameFromUrl.isNotEmpty ? nameFromUrl : state.name,
        isParsingLink: false,
      );
      // Koordinatlarla arka planda şehir/ilçe bilgilerini çek
      fetchPlaceDetails(
        placeId: coords.placeId,
        latitude: coords.latitude,
        longitude: coords.longitude,
        name: nameFromUrl,
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

  /// Koordinat ve opsiyonel place_id ile mekan detaylarını çeker.
  /// city/district backend'den gelir; name URL'den gelmişse korunur.
  /// Hata durumunda sessizce fail eder — kullanıcı bilgileri elle düzeltir.
  Future<void> fetchPlaceDetails({
    String? placeId,
    required double latitude,
    required double longitude,
    String name = '',
  }) async {
    state = state.copyWith(isLoadingPlaceDetails: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
      };
      if (placeId != null && placeId.startsWith('ChIJ')) {
        queryParams['place_id'] = placeId;
      } else if (name.isNotEmpty) {
        queryParams['name'] = name;
      }

      final response = await apiClient.get(
        ApiEndpoints.placePreview,
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final fetchedName = (data['name'] as String? ?? '').trim();
      final fetchedCity = (data['city'] as String? ?? '').trim();
      final fetchedDistrict = (data['district'] as String? ?? '').trim();
      final fetchedPhotoUrls = (data['photo_urls'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .where((url) => url.isNotEmpty)
          .toList();

      state = state.copyWith(
        // Eğer state'te zaten bir isim varsa (URL'den geldiyse) koru,
        // yoksa backend'den gelen ismi kullan
        name: state.name.isNotEmpty
            ? state.name
            : (fetchedName.isNotEmpty ? fetchedName : state.name),
        city: fetchedCity.isNotEmpty ? fetchedCity : state.city,
        district: fetchedDistrict.isNotEmpty ? fetchedDistrict : state.district,
        googlePhotoUrls: fetchedPhotoUrls,
        selectedPhotoUrl: fetchedPhotoUrls.isNotEmpty ? fetchedPhotoUrls.first : null,
        isLoadingPlaceDetails: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingPlaceDetails: false);
    }
  }

  void selectPhoto(String url) => state = state.copyWith(selectedPhotoUrl: url);

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

  // ─── Food Methods ───

  void setFoodHalalMode(String mode) {
    state = state.copyWith(
      foodHalalMode: mode,
      // Yemek seçimleri tüm modlarda korunur
      excludedProducts: mode == 'except'
          ? (state.excludedProducts.isEmpty ? [''] : state.excludedProducts)
          : [],
    );
  }

  void addExcludedProduct(String name) {
    state = state.copyWith(
      excludedProducts: [...state.excludedProducts, name],
    );
  }

  void removeExcludedProduct(int index) {
    final list = List<String>.from(state.excludedProducts);
    list.removeAt(index);
    state = state.copyWith(excludedProducts: list);
  }

  void updateExcludedProduct(int index, String value) {
    final list = List<String>.from(state.excludedProducts);
    list[index] = value;
    state = state.copyWith(excludedProducts: list);
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
    state = state.copyWith(selectedFoodItemIds: map);
  }

  void selectAllInCategory(int categoryId, List<int> allItemIds) {
    final map = Map<int, List<int>>.from(state.selectedFoodItemIds);
    map[categoryId] = List<int>.from(allItemIds);
    state = state.copyWith(selectedFoodItemIds: map);
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
    if (state.currentStep < 4) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 4) {
      state = state.copyWith(currentStep: step);
    }
  }

  Future<void> submit() async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);

      // 1. Mekan oluştur
      await apiClient.post(
        ApiEndpoints.venues,
        data: {
          'name': state.name.trim(),
          'address': state.district.isNotEmpty ? state.district : state.city,
          'city': state.city,
          'district': state.district.isNotEmpty ? state.district : null,
          'latitude': state.latitude,
          'longitude': state.longitude,
          if (state.googlePlaceId != null) 'google_place_id': state.googlePlaceId,
          if (state.selectedPhotoUrl != null) 'google_photo_url': state.selectedPhotoUrl,
          'criteria_ids': state.selectedCriteriaIds,
          'notes': state.notes?.trim(),
          'food_halal_mode': state.foodHalalMode,
          'excluded_products': state.excludedProducts
              .where((p) => p.trim().isNotEmpty)
              .toList(),
          'food_item_ids': allSelectedFoodItemIds,
        },
      );

      state = state.copyWith(isLoading: false, isSuccess: true, currentStep: 4);
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
  final String? googlePlaceId;
  final List<int> selectedCriteriaIds;
  final List<int> selectedFoodItemIds;
  final String foodHalalMode;
  final List<String> excludedProducts;

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
    this.googlePlaceId,
    this.selectedCriteriaIds = const [],
    this.selectedFoodItemIds = const [],
    this.foodHalalMode = 'selected',
    this.excludedProducts = const [],
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
    String? googlePlaceId,
    List<int>? selectedCriteriaIds,
    List<int>? selectedFoodItemIds,
    String? foodHalalMode,
    List<String>? excludedProducts,
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
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      selectedCriteriaIds: selectedCriteriaIds ?? this.selectedCriteriaIds,
      selectedFoodItemIds: selectedFoodItemIds ?? this.selectedFoodItemIds,
      foodHalalMode: foodHalalMode ?? this.foodHalalMode,
      excludedProducts: excludedProducts ?? this.excludedProducts,
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
        foodHalalMode: venue.foodHalalMode,
        excludedProducts: venue.excludedProducts,
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
    // Koordinat manuel değişince place_id geçersiz olur
    state = state.copyWith(latitude: latitude, longitude: longitude, googlePlaceId: null);
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
        googlePlaceId: coords.placeId,
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
    state = state.copyWith(selectedFoodItemIds: ids);
  }

  void setFoodHalalMode(String mode) {
    state = state.copyWith(
      foodHalalMode: mode,
      // Yemek seçimleri tüm modlarda korunur
      excludedProducts: mode == 'except'
          ? (state.excludedProducts.isEmpty ? [''] : state.excludedProducts)
          : [],
    );
  }

  void addExcludedProduct(String name) {
    state = state.copyWith(
      excludedProducts: [...state.excludedProducts, name],
    );
  }

  void removeExcludedProduct(int index) {
    final list = List<String>.from(state.excludedProducts);
    list.removeAt(index);
    state = state.copyWith(excludedProducts: list);
  }

  void updateExcludedProduct(int index, String value) {
    final list = List<String>.from(state.excludedProducts);
    list[index] = value;
    state = state.copyWith(excludedProducts: list);
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
          if (state.googlePlaceId != null) 'google_place_id': state.googlePlaceId,
          'notes': state.notes?.trim(),
          'criteria_ids': state.selectedCriteriaIds,
          'food_item_ids': state.selectedFoodItemIds,
          'food_halal_mode': state.foodHalalMode,
          'excluded_products': state.excludedProducts
              .where((p) => p.trim().isNotEmpty)
              .toList(),
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
