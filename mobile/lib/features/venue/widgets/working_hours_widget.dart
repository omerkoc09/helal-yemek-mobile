import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class WorkingHoursWidget extends StatelessWidget {
  final Map<String, String> workingHours;

  const WorkingHoursWidget({super.key, required this.workingHours});

  static const _dayLabels = {
    'mon': 'Pazartesi',
    'tue': 'Salı',
    'wed': 'Çarşamba',
    'thu': 'Perşembe',
    'fri': 'Cuma',
    'sat': 'Cumartesi',
    'sun': 'Pazar',
  };

  static const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Widget build(BuildContext context) {
    if (workingHours.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
            SizedBox(width: 6),
            Text(
              'Çalışma Saatleri',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...(_dayOrder
            .where((day) => workingHours.containsKey(day))
            .map((day) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _dayLabels[day] ?? day,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        workingHours[day]!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ))),
      ],
    );
  }
}
