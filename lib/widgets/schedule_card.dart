import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';

class ScheduleCard extends StatelessWidget {
  final DateTime date;
  final Future<Map<String, List<Map<String, dynamic>>>> scheduleFuture;
  final String? serviceLanguage;
  const ScheduleCard({
    super.key,
    required this.date,
    required this.scheduleFuture,
    required this.serviceLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final formatted = DateFormat('EEE, MMM d').format(date);

    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: scheduleFuture,
      builder: (context, snapshot) {
        bool hasAssignments = false;
        bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        bool hasError = snapshot.hasError;

        if (snapshot.hasData) {
          final teamStatus = snapshot.data ?? {};
          hasAssignments = ScheduleUtils.hasAnyFunctionAssigned(teamStatus);
        }

        // Use theme surface + overlay blend for highlighting
        final baseColor = colorScheme.surface;
        final highlightColor = hasAssignments
            ? colorScheme.tertiary.withAlpha(100)
            : baseColor;

        return GestureDetector(
          onTap: () {
            if (!isLoading) {
              showDialog(
                context: context,
                builder: (_) => ScheduleDetailsDialog(
                  selectedDate: date,
                  serviceLanguage: serviceLanguage,
                  isServiceScheduled: hasAssignments,
                ),
              );
            }
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: highlightColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasAssignments
                    ? colorScheme.outlineVariant
                    : colorScheme.secondary,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        formatted,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: colorScheme.onSurface,
                          strokeWidth: 2,
                        ),
                      )
                    else if (hasError)
                      Icon(
                        Icons.error,
                        color: colorScheme.error,
                        size: 18,
                      )
                    else
                      Icon(
                        hasAssignments
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: hasAssignments
                            ? colorScheme.tertiary
                            : colorScheme.secondary,
                        size: 18,
                      ),
                  ],
                ),
                if (isLoading || hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    isLoading ? 'Loading...' : 'Error loading',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
