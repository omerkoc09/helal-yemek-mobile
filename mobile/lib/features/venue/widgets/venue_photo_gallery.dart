import 'package:flutter/material.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';

class VenuePhotoGallery extends StatefulWidget {
  final List<VenuePhoto> photos;
  final double height;

  const VenuePhotoGallery({
    super.key,
    required this.photos,
    this.height = 250,
  });

  @override
  State<VenuePhotoGallery> createState() => _VenuePhotoGalleryState();
}

class _VenuePhotoGalleryState extends State<VenuePhotoGallery> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_outlined,
                  size: 48, color: AppTheme.textSecondary),
              SizedBox(height: 8),
              Text('Fotoğraf yok',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Image.network(
                widget.photos[index].url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: AppTheme.textSecondary),
                ),
              );
            },
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
