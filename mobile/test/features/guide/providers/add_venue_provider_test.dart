import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/guide/providers/guide_provider.dart';

// AddVenueNotifier'ın saf state/wizard mantığı — konum ya da API gerektirmeyen
// tüm yollar burada test edilir. Mekan ekleme sihirbazının ilerleme kapıları ve
// seçim mantığı, hatanın kolayca sızabileceği yerler.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  AddVenueNotifier notifier() => container.read(addVenueProvider.notifier);
  AddVenueState state() => container.read(addVenueProvider);

  group('Wizard kapısı — canProceedStep0 (link zorunlu)', () {
    // Manuel ("Linksiz Devam Et") akışı kaldırıldı: ilerlemek için mutlaka
    // linkten koordinat çıkarılmış olmalı.
    test('koordinat yoksa geçilemez', () {
      expect(state().canProceedStep0, isFalse);
    });

    test('koordinat gelince geçilebilir', () {
      notifier().setCoordinates(latitude: 41.0, longitude: 29.0);
      expect(state().canProceedStep0, isTrue);
    });
  });

  group('Wizard kapısı — canProceedStep1 (detay + şehir kısıtı)', () {
    void fillValidStep1() {
      notifier().setName('Kafe');
      notifier().setCity('İstanbul');
      notifier().setDistrict('Kadıköy');
      notifier().setCoordinates(latitude: 41.0, longitude: 29.0);
    }

    test('tüm zorunlu alanlar dolu ve şehir uygunsa geçilebilir', () {
      fillValidStep1();
      expect(state().cityAllowed, isTrue); // varsayılan
      expect(state().canProceedStep1, isTrue);
    });

    test('ad boşsa geçilemez', () {
      fillValidStep1();
      notifier().setName('   ');
      expect(state().canProceedStep1, isFalse);
    });

    test('ilçe boşsa geçilemez', () {
      fillValidStep1();
      notifier().setDistrict('');
      expect(state().canProceedStep1, isFalse);
    });

    test('şehir kısıtı: cityAllowed=false ise diğer her şey dolu olsa da geçilemez', () {
      fillValidStep1();
      // Backend preview şehir uyumsuzluğu bildirdiğinde bu bayrak düşer.
      container.read(addVenueProvider.notifier).state =
          state().copyWith(cityAllowed: false);
      expect(state().canProceedStep1, isFalse);
    });
  });

  group('Wizard kapısı — canProceedStep2 (kriter)', () {
    test('hiç kriter seçilmemişse geçilemez', () {
      expect(state().canProceedStep2, isFalse);
    });

    test('en az bir kriter seçiliyse geçilebilir', () {
      notifier().toggleCriteria(1);
      expect(state().canProceedStep2, isTrue);
    });
  });

  group('Wizard kapısı — canProceedStep3 (mutfak + halalMode dallanması)', () {
    test('mutfak seçilmemişse hiçbir modda geçilemez', () {
      notifier().setFoodHalalMode('all');
      expect(state().canProceedStep3, isFalse);
    });

    test('all modu: mutfak seçiliyse yeterli', () {
      notifier().setFoodHalalMode('all');
      notifier().toggleCategory(1);
      expect(state().canProceedStep3, isTrue);
    });

    test('except modu: mutfak VAR ama sakıncalı ürün boşsa geçilemez', () {
      notifier().setFoodHalalMode('except'); // excluded'a [''] koyar
      notifier().toggleCategory(1);
      // [''] içinde trim edilince boş → yeterli değil
      expect(state().canProceedStep3, isFalse);
    });

    test('except modu: mutfak + en az bir dolu sakıncalı ürün varsa geçilebilir', () {
      notifier().setFoodHalalMode('except');
      notifier().toggleCategory(1);
      notifier().updateExcludedProduct(0, 'Jelatin');
      expect(state().canProceedStep3, isTrue);
    });
  });

  group('setCoordinates', () {
    test('koordinat elle değişince googlePlaceId geçersizleşir (null olur)', () {
      // place_id'li bir başlangıç durumu kur (parseMapsLink ağa/binding'e
      // dokunacağı için doğrudan copyWith ile — sentinel düzeltmesi sayesinde
      // bu atama da düzgün çalışır).
      notifier().state = state().copyWith(googlePlaceId: 'ChIJabc');
      expect(state().googlePlaceId, 'ChIJabc');

      // Konum haritadan elle taşınınca place_id o mekana ait olmaktan çıkar.
      notifier().setCoordinates(latitude: 40.0, longitude: 28.0);

      expect(state().latitude, 40.0);
      expect(state().longitude, 28.0);
      expect(state().googlePlaceId, isNull);
    });

    test('copyWith argüman verilmeyince mevcut place_id korunur', () {
      // Sentinel'in diğer yönü: googlePlaceId geçilmezse eski değer kalmalı.
      notifier().state = state().copyWith(googlePlaceId: 'ChIJkeep');
      notifier().setName('Kafe'); // googlePlaceId'ye dokunmaz
      expect(state().googlePlaceId, 'ChIJkeep');
    });
  });

  group('toggleCriteria', () {
    test('ekler ve tekrar çağırınca çıkarır', () {
      notifier().toggleCriteria(5);
      expect(state().selectedCriteriaIds, contains(5));
      notifier().toggleCriteria(5);
      expect(state().selectedCriteriaIds, isNot(contains(5)));
    });
  });

  group('Mutfak seçimi', () {
    test('toggleCategory ekler/çıkarır', () {
      notifier().toggleCategory(1);
      notifier().toggleCategory(2);
      expect(state().selectedCategoryIds, [1, 2]);
      notifier().toggleCategory(1);
      expect(state().selectedCategoryIds, [2]);
    });
  });

  group('setFoodHalalMode geçişi', () {
    test('except moduna geçince boş excluded listesi [""] ile başlatılır', () {
      notifier().setFoodHalalMode('except');
      expect(state().excludedProducts, ['']);
    });

    test('except dışına çıkınca excluded temizlenir', () {
      notifier().setFoodHalalMode('except');
      notifier().updateExcludedProduct(0, 'Jelatin');
      notifier().setFoodHalalMode('all');
      expect(state().excludedProducts, isEmpty);
    });

    test('mevcut dolu excluded except\'e tekrar girişte korunur', () {
      notifier().setFoodHalalMode('except');
      notifier().addExcludedProduct('Alkol');
      // artık ['', 'Alkol']
      notifier().setFoodHalalMode('except');
      expect(state().excludedProducts, contains('Alkol'));
    });
  });

  group('Sakıncalı ürünler add/remove/update', () {
    test('add sona ekler, update değiştirir, remove siler', () {
      notifier().addExcludedProduct('A');
      notifier().addExcludedProduct('B');
      expect(state().excludedProducts, ['A', 'B']);

      notifier().updateExcludedProduct(1, 'B2');
      expect(state().excludedProducts, ['A', 'B2']);

      notifier().removeExcludedProduct(0);
      expect(state().excludedProducts, ['B2']);
    });
  });

  group('Adım navigasyonu', () {
    test('nextStep artırır ama 4\'te durur', () {
      for (var i = 0; i < 10; i++) {
        notifier().nextStep();
      }
      expect(state().currentStep, 4);
    });

    test('previousStep azaltır ama 0\'ın altına inmez', () {
      notifier().goToStep(2);
      notifier().previousStep();
      expect(state().currentStep, 1);
      notifier().previousStep();
      notifier().previousStep();
      expect(state().currentStep, 0);
    });

    test('goToStep yalnızca 0..4 aralığını kabul eder', () {
      notifier().goToStep(3);
      expect(state().currentStep, 3);
      notifier().goToStep(5); // aralık dışı → değişmez
      expect(state().currentStep, 3);
      notifier().goToStep(-1); // aralık dışı → değişmez
      expect(state().currentStep, 3);
    });
  });

  group('Duplicate kapısı — aynı mekan ikinci kez eklenemez', () {
    // Rehber, zaten kayıtlı bir mekanın linkini yapıştırdığında akış LİNK
    // ADIMINDA durmalı. Aksi halde hata ancak son adımda, gönderim sırasında
    // backend'in 409'uyla görünüyor ve tüm sihirbaz boşa dolduruluyor.
    const dup = Venue(
      id: 'venue-1',
      name: 'Mantıcım Hacer',
      city: 'Aydın',
      latitude: 37.85,
      longitude: 27.81,
      status: 'approved',
      addedBy: 'user-1',
    );

    test('duplicate varken ilerlenemez', () {
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);
      expect(state().canProceedStep0, isTrue, reason: 'ön koşul');

      notifier().setDuplicate(dup);

      expect(state().canProceedStep0, isFalse);
    });

    test('duplicate kontrolü sürerken ilerlenemez', () {
      // Cevap gelmeden "Devam"a basılabilseydi engel atlanırdı.
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);
      notifier().setCheckingDuplicate(true);

      expect(state().canProceedStep0, isFalse);
    });

    test('duplicate temizlenince yeniden ilerlenebilir', () {
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);
      notifier().setDuplicate(dup);

      notifier().clearDuplicate();

      expect(state().canProceedStep0, isTrue);
    });

    test('reset duplicate durumunu da temizler', () {
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);
      notifier().setDuplicate(dup);

      notifier().reset();

      expect(state().duplicateVenue, isNull);
      expect(state().isCheckingDuplicate, isFalse);
    });
  });

  group('clearLinkResult — link temizlenince mekan verisi de gitmeli', () {
    const dup2 = Venue(
      id: 'venue-1',
      name: 'Mantıcım Hacer',
      city: 'Aydın',
      latitude: 37.85,
      longitude: 27.81,
      status: 'approved',
      addedBy: 'user-1',
    );

    test('koordinat ve mekan bilgisi silinir, ilerlenemez', () {
      // Rehber duplicate uyarısı aldıktan sonra linki siliyor. Önceden yalnızca
      // uyarı kalkıyor, koordinat state'te kalıyordu; canProceedStep0 sadece
      // koordinata baktığı için "Devam" yeniden açılıyor ve ESKİ mekanla
      // ilerlenebiliyordu.
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);
      notifier().setName('Mantıcım Hacer');
      notifier().setCity('Aydın');
      notifier().setDuplicate(dup2);

      notifier().clearLinkResult();

      expect(state().latitude, isNull);
      expect(state().longitude, isNull);
      expect(state().name, '');
      expect(state().city, '');
      expect(state().duplicateVenue, isNull);
      expect(state().canProceedStep0, isFalse);
    });

    test('linke bağlı olmayan seçimler korunur', () {
      // Kriter/mutfak/not kullanıcının elle girdiği veriler; link değişti diye
      // silinmeleri gereksiz veri kaybı olur.
      notifier().toggleCriteria(7);
      notifier().toggleCategory(3);
      notifier().setNotes('kapalı mekan');
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);

      notifier().clearLinkResult();

      expect(state().selectedCriteriaIds, contains(7));
      expect(state().selectedCategoryIds, contains(3));
      expect(state().notes, 'kapalı mekan');
    });

    test('bulunulan adım korunur', () {
      notifier().goToStep(0);
      notifier().setCoordinates(latitude: 37.85, longitude: 27.81);

      notifier().clearLinkResult();

      expect(state().currentStep, 0);
    });
  });

  group('reset', () {
    test('tüm state\'i başlangıca döndürür', () {
      notifier().setName('Kafe');
      notifier().toggleCriteria(1);
      notifier().toggleCategory(1);
      notifier().goToStep(3);

      notifier().reset();

      expect(state().name, '');
      expect(state().selectedCriteriaIds, isEmpty);
      expect(state().selectedCategoryIds, isEmpty);
      expect(state().currentStep, 0);
    });
  });
}
