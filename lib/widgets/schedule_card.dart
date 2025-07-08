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

        // Light red accent shade if hasAssignments
        final backgroundColor = hasAssignments
            ? const Color(0xFF2A2A3D)
                .withGreen(150)
                .withBlue(136)
                .withAlpha(150)
            : const Color(0xFF2A2A3D);

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
            width: 140, // Reduced width from 160
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else if (hasError)
                      const Icon(Icons.error, color: Colors.red, size: 18)
                    else
                      Icon(
                        hasAssignments
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: hasAssignments ? Colors.green : Colors.amber,
                        size: 18,
                      ),
                  ],
                ),
                if (isLoading || hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    isLoading ? 'Loading...' : 'Error loading',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
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
