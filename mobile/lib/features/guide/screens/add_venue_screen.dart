import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/guide_provider.dart';
import '../widgets/add_venue_details_step.dart';
import '../widgets/add_venue_food_step.dart';
import '../widgets/add_venue_location_step.dart';
import '../widgets/photo_widgets.dart';
import '../widgets/step_indicator.dart';

class AddVenueScreen extends ConsumerStatefulWidget {
  const AddVenueScreen({super.key});

  @override
  ConsumerState<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends ConsumerState<AddVenueScreen> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addVenueProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addVenueProvider);
    final notifier = ref.read(addVenueProvider.notifier);

    ref.listen<AddVenueState>(addVenueProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mekan Ekle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
      ),
      body: Column(
        children: [
          StepIndicator(currentStep: state.currentStep),
          Expanded(
            child: state.currentStep == 5
                ? _buildSuccessStep()
                : _buildStepContent(state),
          ),
          if (state.currentStep < 5)
            _buildNavigationBar(state, notifier),
        ],
      ),
    );
  }

  Widget _buildStepContent(AddVenueState state) {
    return switch (state.currentStep) {
      0 => const AddVenueLocationStep(), // link girişi
      1 => const AddVenueDetailsStep(),  // ad + il/ilçe + konum doğrulama
      2 => _buildCriteriaStep(),
      3 => _buildNotesPhotoStep(state),
      4 => const AddVenueFoodStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── Adım 2: Helal Kriterleri ───

  Widget _buildCriteriaStep() {
    final criteriaAsync = ref.watch(halalCriteriaProvider);
    final state = ref.watch(addVenueProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Helal Kriterleri',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu mekan için geçerli olan helal kriterlerini seçin.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          criteriaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Kriterler yüklenemedi.'),
            data: (criteria) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: criteria.map((c) {
                  final isSelected = state.selectedCriteriaIds.contains(c.id);
                  return FilterChip(
                    label: Text(c.labelTr),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(addVenueProvider.notifier).toggleCriteria(c.id),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                    avatar: isSelected
                        ? null
                        : const Icon(Icons.add, size: 18),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Adım 4: Not + Fotoğraf ───

  Widget _buildNotesPhotoStep(AddVenueState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not & Fotoğraflar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İsteğe bağlı olarak not ekleyin ve fotoğraf yükleyin.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Not (isteğe bağlı)',
              hintText: 'Mekan hakkında eklemek istediğiniz bilgiler...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.note_outlined),
            ),
            maxLines: 4,
            onChanged: (value) =>
                ref.read(addVenueProvider.notifier).setNotes(value),
          ),
          const SizedBox(height: 24),
          const Text(
            'Fotoğraflar (isteğe bağlı)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...state.photoPaths.map((path) => PhotoThumbnail(
                    path: path,
                    onRemove: () =>
                        ref.read(addVenueProvider.notifier).removePhoto(path),
                  )),
              if (state.photoPaths.length < 5)
                AddPhotoButton(onTap: _pickPhoto),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (image != null) {
      ref.read(addVenueProvider.notifier).addPhoto(image.path);
    }
  }

  // ─── Başarılı ───

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Mekan Gönderildi!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mekanınız admin onayına gönderildi.\nOnaylandığında haritada görünecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/my-venues'),
                child: const Text('Mekanlarımı Gör'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Haritaya Dön'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Navigation Bar ───

  Widget _buildNavigationBar(AddVenueState state, AddVenueNotifier notifier) {
    final canProceed = switch (state.currentStep) {
      0 => state.canProceedStep0,
      1 => state.canProceedStep1,
      2 => state.canProceedStep2,
      3 => state.canProceedStep3,
      4 => state.canProceedStep4,
      _ => false,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (state.currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: notifier.previousStep,
                  child: const Text('Geri'),
                ),
              ),
            if (state.currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: state.currentStep > 0 ? 2 : 1,
              child: ElevatedButton(
                onPressed: canProceed
                    ? () {
                        if (state.currentStep == 4) {
                          notifier.submit();
                        } else {
                          notifier.nextStep();
                        }
                      }
                    : null,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(state.currentStep == 4 ? 'Gönder' : 'Devam'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final state = ref.read(addVenueProvider);
    if (state.name.isEmpty && state.photoPaths.isEmpty) {
      context.pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vazgeç'),
        content: const Text(
          'Girdiğiniz bilgiler kaybolacak. Çıkmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Çık'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      context.pop();
    }
  }
}
