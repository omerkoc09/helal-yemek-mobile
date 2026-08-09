import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK anahtarı Info.plist üzerinden gelir; değeri ios/Flutter/Maps.xcconfig
    // besler (gitignore'lı). Anahtar önce burada hardcoded'dı ve git'e commit
    // edilmişti — artık kaynak kodda durmuyor ve Android'den AYRI, bundle ID ile
    // kısıtlanmış bir anahtar kullanılıyor.
    //
    // Anahtar yoksa (yapılandırmasız klon) uygulama ÇÖKMEZ: harita boş görünür,
    // geri kalan akışlar çalışmaya devam eder.
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String,
       !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    } else {
      NSLog("[İtimat] UYARI: Maps anahtarı yok — ios/Flutter/Maps.xcconfig doldurulmalı. Harita boş görünecek.")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
