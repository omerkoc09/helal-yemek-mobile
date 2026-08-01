import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/venue/widgets/venue_photo_gallery.dart';

/// Galeri kaydırması, detay ekranındaki katman diziliminden etkileniyor:
/// galeri bir Stack'in altında, üstünde başlık için gradyan var. Gradyan
/// dokunmaları yutarsa galeri sağa/sola kaydırılamaz — kullanıcının bildirdiği
/// hata tam olarak buydu.
void main() {
  final photos = [
    const VenuePhoto(
      id: 'p1',
      venueId: 'v1',
      url: 'https://example.com/1.jpg',
      uploadedBy: 'u1',
      isPrimary: true,
    ),
    const VenuePhoto(
      id: 'p2',
      venueId: 'v1',
      url: 'https://example.com/2.jpg',
      uploadedBy: 'u1',
    ),
    const VenuePhoto(
      id: 'p3',
      venueId: 'v1',
      url: 'https://example.com/3.jpg',
      uploadedBy: 'u1',
    ),
  ];

  /// Detay ekranındaki dizilimin sadeleştirilmiş hâli: galeri + üstünde gradyan.
  Widget buildWithOverlay({required bool ignorePointer}) {
    final overlay = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
        ),
      ),
    );

    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VenuePhotoGallery(photos: photos),
              if (ignorePointer) IgnorePointer(child: overlay) else overlay,
            ],
          ),
        ),
      ),
    );
  }

  /// Aktif sayfayı gösterge noktalarından okur: aktif olan tam beyaz ve daha
  /// geniştir (çubuğa dönüşür). PageView.builder varsayılan controller
  /// kullandığı için `controller.page` null döner; ölçüm buradan yapılmalı.
  int activePage(WidgetTester tester) {
    final dots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    for (var i = 0; i < dots.length; i++) {
      if ((dots[i].decoration as BoxDecoration?)?.color == Colors.white) {
        return i;
      }
    }
    return -1;
  }

  testWidgets('aktif nokta genişleyerek belirginleşir', (tester) async {
    // Yalnızca opaklık farkı açık renkli fotoğraflarda seçilemiyordu; aktif
    // gösterge çubuğa dönüşüyor ve arkasında koyu şerit var.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VenuePhotoGallery(photos: photos))),
    );

    final dots =
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(dots.length, photos.length, reason: 'her fotoğraf için bir gösterge');

    final active = dots.elementAt(0);
    final passive = dots.elementAt(1);
    expect(
      (active.constraints?.maxWidth ?? 0) >
          (passive.constraints?.maxWidth ?? 0),
      isTrue,
      reason: 'aktif gösterge pasiflerden geniş olmalı',
    );
  });

  testWidgets('tek fotoğrafta gösterge çizilmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VenuePhotoGallery(photos: [photos.first])),
      ),
    );

    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('tek başına galeri sağa/sola kaydırılır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VenuePhotoGallery(photos: photos))),
    );

    expect(activePage(tester), 0, reason: 'başlangıçta ilk fotoğraf aktif');

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      activePage(tester),
      1,
      reason: 'sola sürükleyince ikinci fotoğrafa geçmeli',
    );
  });

  testWidgets('gradyan IgnorePointer ile sarılıysa kaydırma çalışır',
      (tester) async {
    await tester.pumpWidget(buildWithOverlay(ignorePointer: true));

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(activePage(tester), 1, reason: 'gradyan dokunmayı geçirmeli');
  });

  testWidgets('REGRESYON: IgnorePointer yoksa gradyan kaydırmayı engeller',
      (tester) async {
    // Hatalı hâli kayda geçiriyoruz: gradyan doğrudan Stack'te durursa
    // dokunmaları yutar ve galeri ilk fotoğrafta takılı kalır.
    await tester.pumpWidget(buildWithOverlay(ignorePointer: false));

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      activePage(tester),
      0,
      reason: 'gradyan dokunmayı yuttuğu için sayfa değişmemeli',
    );
  });
}
