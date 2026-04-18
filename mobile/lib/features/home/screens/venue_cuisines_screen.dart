import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../providers/venue_filter_provider.dart';

class VenueCuisinesScreen extends ConsumerStatefulWidget {
  const VenueCuisinesScreen({super.key});

  @override
  ConsumerState<VenueCuisinesScreen> createState() =>
      _VenueCuisinesScreenState();
}

class _VenueCuisinesScreenState extends ConsumerState<VenueCuisinesScreen> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...ref.read(venueFilterProvider).selectedCuisineIds};
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(foodCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mutfaklar')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mutfaklar yüklenemedi.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(foodCategoriesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
        data: (categories) => ListView.builder(
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat = categories[i];
            return CheckboxListTile(
              value: _selected.contains(cat.id),
              activeColor: AppTheme.primary,
              title: Text(cat.labelTr),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(cat.id);
                  } else {
                    _selected.remove(cat.id);
                  }
                });
              },
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Tamam'),
            ),
          ),
        ),
      ),
    );
  }
}
