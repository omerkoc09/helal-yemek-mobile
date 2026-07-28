import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/guide_provider.dart';
import '../widgets/add_venue_details_step.dart';
import '../widgets/add_venue_food_step.dart';
import '../widgets/add_venue_location_step.dart';
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
        AppToast.error(context, next.error!);
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
            child: state.currentStep == 4
                ? _buildSuccessStep()
                : _buildStepContent(state),
          ),
          if (state.currentStep < 4)
            _buildNavigationBar(state, notifier),
        ],
      ),
    );
  }

  Widget _buildStepContent(AddVenueState state) {
    return switch (state.currentStep) {
      0 => const AddVenueLocationStep(), // link girişi
      1 => const AddVenueDetailsStep(),  // ad + il/ilçe + konum doğrulama
      2 => _buildCriteriaAndNotesStep(state), // güven kriterleri + not
      3 => const AddVenueFoodStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── Adım 2: Güven Kriterleri + Not ───

  Widget _buildCriteriaAndNotesStep(AddVenueState state) {
    final criteriaAsync = ref.watch(trustCriteriaProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Güven Kriterleri
          const Text(
            'Güven Kriterleri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu mekan için geçerli olan güven kriterlerini seçin.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
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
                    label: Text(c.name),
                    selected: isSelected,
                    onSelected: (_) =>
                        ref.read(addVenueProvider.notifier).toggleCriteria(c.id),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                    avatar: isSelected ? null : const Icon(Icons.add, size: 18),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // Not
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sticky_note_2_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'İsteğe bağlı',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText:
                    'Mekan hakkında eklemek istediğiniz bilgiler...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 4,
              style: const TextStyle(fontSize: 14, height: 1.5),
              onChanged: (value) =>
                  ref.read(addVenueProvider.notifier).setNotes(value),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Ziyaretçilere yardımcı olabilecek ek bilgiler ekleyebilirsiniz.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                onPressed: () => context.go(AppRoutes.map),
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
                        if (state.currentStep == 3) {
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
                    : Text(state.currentStep == 3 ? 'Gönder' : 'Devam'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final state = ref.read(addVenueProvider);
    if (state.name.isEmpty) {
      context.go(AppRoutes.home);
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
      context.go(AppRoutes.home);
    }
  }
}
