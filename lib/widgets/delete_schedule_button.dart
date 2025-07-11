import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeleteScheduleButton extends StatelessWidget {
  final DateTime? date;
  final String serviceLanguage;

  const DeleteScheduleButton({
    super.key,
    required this.date,
    required this.serviceLanguage,
  });

  Future<void> _clearScheduleForDate(BuildContext context) async {
    if (date == null) return;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date!);

    final batch = FirebaseFirestore.instance.batch();
    bool hasAnythingToClear = false;

    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final uid = userDoc['uid'];
        final userScheduleRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .doc(formattedDate);

        final userScheduleSnap = await userScheduleRef.get();

        if (!userScheduleSnap.exists) continue;

        final data = userScheduleSnap.data() ?? {};
        final userService = data['service'];

        if (userService == serviceLanguage) {
          final hasFunctions = (data['functions'] is List &&
              (data['functions'] as List).isNotEmpty);
          final hasResponse = data.containsKey('response');
          final hasPracticeTime = data.containsKey('practiceTime');

          if (hasFunctions || hasResponse || hasPracticeTime) {
            batch.update(userScheduleRef, {
              'functions': FieldValue.delete(),
              'response': FieldValue.delete(),
              'practiceTime': FieldValue.delete(),
              'service': FieldValue.delete(),
            });
            hasAnythingToClear = true;
          }
        }
      }

      if (hasAnythingToClear) {
        await batch.commit();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cleared $serviceLanguage schedule for selected day.',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No $serviceLanguage schedule found to clear.',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error clearing schedule: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton.icon(
      onPressed: date != null ? () => _clearScheduleForDate(context) : null,
      icon: Icon(
        FontAwesomeIcons.trash,
        color: colorScheme.onError,
        size: 18,
      ),
      label: Text(
        'Delete',
        style: TextStyle(color: colorScheme.onError),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
