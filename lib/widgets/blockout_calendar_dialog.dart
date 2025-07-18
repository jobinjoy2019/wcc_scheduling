import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/custom_schedule_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class BlockoutCalendarDialog extends StatefulWidget {
  const BlockoutCalendarDialog({super.key});

  @override
  State<BlockoutCalendarDialog> createState() => _BlockoutCalendarDialogState();
}

class _BlockoutCalendarDialogState extends State<BlockoutCalendarDialog> {
  Set<DateTime> selectedDates = {};
  Set<DateTime> existingBlockouts = {};
  DateTime focusedDate = DateTime.now();
  late String uid;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadBlockoutDates();
  }

  Future<void> _loadBlockoutDates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .get(const GetOptions(source: Source.serverAndCache));

    final dates = snapshot.docs
        .where((doc) => (doc.data()['blockout'] ?? false) == true)
        .map((doc) {
          try {
            final date = DateTime.parse(doc.id);
            return DateTime(date.year, date.month, date.day);
          } catch (_) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toSet();

    setState(() {
      existingBlockouts = dates;
      selectedDates.clear();
    });
  }

  void _toggleDate(DateTime day) {
    final cleanDay = DateTime(day.year, day.month, day.day);
    setState(() {
      if (selectedDates.contains(cleanDay)) {
        selectedDates.remove(cleanDay);
      } else {
        selectedDates.add(cleanDay);
      }
    });
  }

  void _handleDaySelected(Set<DateTime> selected) {
    if (selected.isEmpty) return;
    _toggleDate(selected.first);
  }

  Future<void> _confirmBlockouts() async {
    if (selectedDates.isEmpty) {
      await _showAutoDismissDialog('No new blockouts selected.');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // Get current user functions
    final userDoc = await firestore.collection('users').doc(uid).get();
    final userFunctions = List<String>.from(userDoc['functions'] ?? []);

    // To track functions with no backup on certain dates
    final Map<DateTime, List<String>> functionsWithoutBackup = {};

    for (final date in selectedDates) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      final unavailableFunctions = <String>[];

      for (final functionName in userFunctions) {
        final allUsersSnapshot = await firestore.collection('users').get();

        bool someoneElseAvailable = false;

        for (final doc in allUsersSnapshot.docs) {
          final otherUid = doc.id;
          if (otherUid == uid) continue; // skip current user

          final otherUserFunctions = List<String>.from(doc['functions'] ?? []);
          if (!otherUserFunctions.contains(functionName)) continue;

          final otherScheduleDoc = await firestore
              .collection('users')
              .doc(otherUid)
              .collection('schedules')
              .doc(formattedDate)
              .get();

          final isBlockedOut = otherScheduleDoc.data()?['blockout'] == true;

          if (!isBlockedOut) {
            someoneElseAvailable = true;
            break;
          }
        }

        if (!someoneElseAvailable) {
          unavailableFunctions.add(functionName);
        }
      }

      if (unavailableFunctions.isNotEmpty) {
        functionsWithoutBackup[date] = unavailableFunctions;
      }
    }

    // Show confirmation if any unavailable functions found
    if (functionsWithoutBackup.isNotEmpty) {
      final buffer = StringBuffer();
      functionsWithoutBackup.forEach((date, funcs) {
        final dateStr = DateFormat('MMM d, yyyy').format(date);
        buffer.writeln('• $dateStr: ${funcs.join(', ')}');
      });

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Backup Available'),
          content: Text(
            'You are the only one available for the following functions on these dates:\n\n${buffer.toString()}\nAre you sure you want to block out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Proceed with blockouts
    await Future.wait(
      selectedDates.map((date) {
        final docRef = firestore
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .doc(DateFormat('yyyy-MM-dd').format(date));
        return docRef.set({'blockout': true}, SetOptions(merge: true));
      }),
    );

    if (mounted) {
      await _loadBlockoutDates();
      await _showAutoDismissDialog('Blockouts saved successfully');
    }
  }

  Future<void> _removeBlockouts() async {
    if (selectedDates.isEmpty) {
      await _showAutoDismissDialog('No blockouts selected for removal.');
      return;
    }

    await Future.wait(
      selectedDates.map((date) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .doc(DateFormat('yyyy-MM-dd').format(date));
        return docRef.set({'blockout': false}, SetOptions(merge: true));
      }),
    );

    await _loadBlockoutDates();
    await _showAutoDismissDialog('Blockouts removed successfully');
  }

  Future<void> _showAutoDismissDialog(String message) async {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      titlePadding:
          const EdgeInsets.only(top: 8, left: 16, right: 8, bottom: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Manage Blockouts',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          IconButton(
            icon: Icon(FontAwesomeIcons.xmark, color: colorScheme.onSurface),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 450,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 400,
                child: CustomScheduleCalendar(
                  focusedDay: focusedDate,
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (newFormat) {
                    setState(() {
                      _calendarFormat = newFormat;
                    });
                  },
                  onFocusedDayChanged: (newFocused) {
                    setState(() {
                      focusedDate = newFocused;
                    });
                  },
                  selectedDates: selectedDates,
                  onDaySelected: _handleDaySelected,
                  onDayDoubleTapped: null,
                  colorHighlights: {
                    colorScheme.error.withAlpha(220):
                        existingBlockouts.toList(),
                  },
                  showLegend: true,
                  legendMap: {
                    colorScheme.error.withAlpha(220): 'Blockout',
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _confirmBlockouts,
                      icon: Icon(Icons.check, color: colorScheme.onPrimary),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          (selectedDates.isEmpty && existingBlockouts.isEmpty)
                              ? null
                              : _removeBlockouts,
                      icon: Icon(FontAwesomeIcons.trash,
                          color: colorScheme.onError),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
