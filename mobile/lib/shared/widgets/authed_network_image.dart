import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/media_url.dart';
import '../../core/auth/auth_provider.dart';

/// Yetki gerektiren medya adreslerini Dio üzerinden indirip gösterir.
///
/// Neden `Image.network` değil: `Image.network` Flutter'ın kendi HTTP yığınını
/// kullanır, Dio'yu değil. Dolayısıyla ApiClient'taki auth interceptor'ın
/// dışında kalır — token'ı taze okuma ve 401'de otomatik yenileyip isteği
/// tekrarlama davranışının hiçbiri uygulanmaz. Places foto proxy'si guide/admin
/// yetkisi istediğinden, token süresi dolduğunda diğer tüm çağrılar sessizce
/// yenilenirken yalnızca görseller 401 alıp kırılıyordu.
///
/// Ayrıca `NetworkImage`'ın cache anahtarı yalnızca URL'dir; header sonradan
/// değişse bile görsel yeniden denenmez, yani hata kalıcı hale gelir.
class AuthedNetworkImage extends ConsumerStatefulWidget {
  final String url;
  final BoxFit fit;

  /// Yükleme ve hata durumlarında gösterilecek yer tutucular.
  final Widget Function(BuildContext context) loadingBuilder;
  final Widget Function(BuildContext context) errorBuilder;

  const AuthedNetworkImage({
    super.key,
    required this.url,
    required this.loadingBuilder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  ConsumerState<AuthedNetworkImage> createState() => _AuthedNetworkImageState();
}

class _AuthedNetworkImageState extends ConsumerState<AuthedNetworkImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AuthedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final requestedUrl = widget.url;
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get<List<int>>(
        resolveMediaUrl(requestedUrl),
        options: Options(
          responseType: ResponseType.bytes,
          // BaseOptions'taki JSON başlıkları görsel isteğine uymaz.
          headers: const {'Accept': 'image/*'},
        ),
      );
      // Widget bu sırada başka bir URL'e geçmiş olabilir.
      if (!mounted || requestedUrl != widget.url) return;
      final data = response.data;
      if (data == null || data.isEmpty) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (e) {
      // DioException'ın kendi toString'i sarmalanmış hatayı gizliyor;
      // asıl nedeni ayrıca yazdır.
      final cause = e is DioException ? ' neden=${e.type} / ${e.error}' : '';
      debugPrint('[FOTO] yüklenemedi url=$requestedUrl hata=$e$cause');
      if (!mounted || requestedUrl != widget.url) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorBuilder(context);
    final bytes = _bytes;
    if (bytes == null) return widget.loadingBuilder(context);
    return Image.memory(
      bytes,
      fit: widget.fit,
      errorBuilder: (context, _, _) => widget.errorBuilder(context),
    );
  }
}
