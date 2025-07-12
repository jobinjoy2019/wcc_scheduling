// 🔁 Reusable Widget and Utilities for Schedule and Practice Time

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/whatsapp_message.dart';

class ScheduleUtils {
  static const List<String> functionOrder = [
    'Worship Leader',
    'Acoustic Guitar',
    'Keyboard',
    'Drums',
    'Bass',
    'Lead Guitar',
    'Backup Vox',
    'Tech and Media',
    'Sound Engineer',
  ];

  static Future<Map<String, List<Map<String, dynamic>>>> fetchTeamStatusForDate(
    DateTime date, [
    String? serviceLanguage,
  ]) async {
    final formattedDate = _formatDateKey(date);

    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final Map<String, List<Map<String, dynamic>>> assignmentMap = {};

    for (final userDoc in usersSnapshot.docs) {
      final uid = userDoc['uid'];
      final firstName = (userDoc.data()['firstName'] as String?)?.trim() ?? '';
      final lastName = (userDoc.data()['lastName'] as String?)?.trim() ?? '';
      String name = ('$firstName $lastName').trim();

      if (name.isEmpty) {
        name = (userDoc.data()['name'] as String?)?.trim() ?? 'Unnamed';
      }

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(formattedDate)
          .get();

      if (!scheduleDoc.exists) continue;

      final data = scheduleDoc.data();
      if (data == null) continue;

      // ✅ Optional service filtering
      final docService = data['service'];
      if (serviceLanguage != null && docService != serviceLanguage) continue;

      final List<dynamic>? functions = data['functions'];
      if (functions == null) continue;

      final String response = data['response'] ?? 'Unknown';
      final String? practiceTime = data['practiceTime'];
      final String? service = data['service'];

      for (final func in functions) {
        assignmentMap.putIfAbsent(func, () => []).add({
          'uid': uid,
          'name': name,
          'response': response,
          'practiceTime': practiceTime,
          'service': service,
          "date": formattedDate,
          "function": func,
        });
      }
    }

    // Ensure all functions are present in the map
    for (final func in functionOrder) {
      assignmentMap.putIfAbsent(func, () => []);
    }

    return assignmentMap;
  }

  static Future<bool> isUserScheduledForDate(String uid, DateTime date) async {
    final teamMap = await fetchTeamStatusForDate(date);

    for (final funcMembers in teamMap.values) {
      for (final member in funcMembers) {
        if (member['uid'] == uid) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<String?> fetchPracticeTimeForWeek(String uid) async {
    final now = DateTime.now();
    // Calculate the start of the current week (Sunday)
    // (now.weekday - 1) gives days since Monday (0 for Monday, 6 for Sunday)
    // For Sunday, now.weekday is 7. (7 - 1) = 6. now.day - 6 will give previous Sunday.
    // We need to adjust it to start from Monday, or consistently from Sunday.
    // Assuming a week starts on Monday (weekday 1) for Dart's DateTime.weekday
    // If your week starts on Sunday, adjust (now.weekday % 7)
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final scheduleRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules');

    // Fetch all schedule documents for the user
    final querySnapshot = await scheduleRef.get();

    for (final doc in querySnapshot.docs) {
      try {
        // Parse the document ID (which is the dateKey like 'yyyy-MM-dd')
        final docDate = DateTime.parse(doc.id);

        // Normalize docDate to midnight to compare only dates
        final normalizedDocDate =
            DateTime(docDate.year, docDate.month, docDate.day);
        final normalizedStartOfWeek =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final normalizedEndOfWeek =
            DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

        // Check if the document's date falls within the current week (inclusive)
        if ((normalizedDocDate.isAtSameMomentAs(normalizedStartOfWeek) ||
                normalizedDocDate.isAfter(normalizedStartOfWeek)) &&
            (normalizedDocDate.isAtSameMomentAs(normalizedEndOfWeek) ||
                normalizedDocDate.isBefore(normalizedEndOfWeek))) {
          final data = doc.data();
          if (data.containsKey('practiceTime')) {
            // Return the first practice time found within the week
            // Assuming a user only has ONE practice time for a given week,
            // regardless of how many days they are scheduled.
            // If a user can have multiple practice times for a week across different days,
            // you'd need to modify this to return a list or the most relevant one.
            return data['practiceTime'] as String?;
          }
        }
      } catch (e) {
        // Log the error for invalid date formats in document IDs, useful for debugging
        print('Error parsing document ID ${doc.id}: $e');
        // Continue to the next document
      }
    }

    // If no practice time is found for any scheduled date in the week
    return null;
  }

  static Future<List<DateTime>> loadBlockoutDatesForUser(String uid) async {
    final blockoutDates = <DateTime>[];

    // Always try to get from server first, fallback to cache if offline
    final schedulesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .get(const GetOptions(source: Source.serverAndCache));

    for (final doc in schedulesSnapshot.docs) {
      final data = doc.data();
      if (data['blockout'] == true) {
        try {
          // Defensive parse: if ID has time, strip it
          final id = doc.id.split('T').first;
          final parsed = DateTime.parse(id);
          final cleaned = DateTime(parsed.year, parsed.month, parsed.day);
          blockoutDates.add(cleaned);
        } catch (e) {
          debugPrint('Invalid blockout doc ID format: ${doc.id}');
        }
      }
    }

    // Remove duplicates
    final uniqueDates = blockoutDates.toSet().toList()..sort();

    return uniqueDates;
  }

  static bool hasAnyFunctionAssigned(
      Map<String, List<Map<String, dynamic>>> teamStatus) {
    for (final entries in teamStatus.values) {
      if (entries.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  static String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class ScheduleDetailsDialog extends StatefulWidget {
  final DateTime selectedDate;
  final String? serviceLanguage;
  final bool isServiceScheduled;

  const ScheduleDetailsDialog({
    super.key,
    required this.selectedDate,
    this.serviceLanguage,
    required this.isServiceScheduled,
  });

  @override
  State<ScheduleDetailsDialog> createState() => _ScheduleDetailsDialogState();
}

class UserScheduleInfo {
  final Map<String, List<Map<String, dynamic>>> scheduleMap;
  final bool isUserScheduled;
  final bool isWorshipLeader;

  UserScheduleInfo({
    required this.scheduleMap,
    required this.isUserScheduled,
    required this.isWorshipLeader,
  });
}

class _ScheduleDetailsDialogState extends State<ScheduleDetailsDialog> {
  Map<String, List<Map<String, dynamic>>> scheduleMap = {};
  DateTime? selectedPracticeTime;
  bool isWorshipLeader = false;
  bool isUserScheduled = false;
  late String dateKey;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  String _generateScheduleMessage() {
    final buffer = StringBuffer();

    // Add Date
    buffer.writeln(
        '📅 ${DateFormat('EEE, MMM d, yy').format(widget.selectedDate)}');

    // Add Service
    if (widget.isServiceScheduled) {
      buffer.writeln('Service: ${widget.serviceLanguage ?? 'Not scheduled'}');
    } else {
      buffer.writeln('Service: Not scheduled');
    }

    buffer.writeln('');
    buffer.writeln('Worship Team Schedule:');

    // Add Functions and Users
    for (final function in ScheduleUtils.functionOrder) {
      final members = scheduleMap[function] ?? [];
      if (members.isEmpty) {
        buffer.writeln('• $function: No one scheduled');
      } else {
        final formattedMembers = members.map((m) {
          final mobile = m['mobile']?.toString().trim();
          if (mobile != null && mobile.isNotEmpty) {
            return '@$mobile';
          } else {
            return m['name'] ?? 'Unnamed';
          }
        }).join(', ');
        buffer.writeln('• $function: $formattedMembers');
      }
    }

    // Add Practice Time (if set)
    if (selectedPracticeTime != null) {
      buffer.writeln('');
      buffer.writeln(
        'Practice Time: ${DateFormat('EEE, MMM d • hh:mm a').format(selectedPracticeTime!)}',
      );
    }

    return buffer.toString();
  }

  Future<void> _loadSchedule() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final userSnapshot = await userRef.get();

    final userData = userSnapshot.data();
    if (userData == null) {
      setState(() {
        scheduleMap = {};
        isUserScheduled = false;
        isWorshipLeader = false;
      });
      return;
    }

    // 1️⃣ Load the full team schedule for this date
    final teamSchedule = await ScheduleUtils.fetchTeamStatusForDate(
        widget.selectedDate, widget.serviceLanguage);

    // 2️⃣ Check if the user is assigned to *any* function
    bool userIsScheduled = false;
    for (final entry in teamSchedule.entries) {
      final members = entry.value;
      if (members.any((member) => member['uid'] == currentUser.uid)) {
        userIsScheduled = true;
        break;
      }
    }

    // 3️⃣ By default, Worship Leader is false unless user is scheduled
    bool userIsWorshipLeader = false;
    if (userIsScheduled) {
      final worshipLeaders = teamSchedule['Worship Leader'] ?? [];
      userIsWorshipLeader =
          worshipLeaders.any((member) => member['uid'] == currentUser.uid);
    }

    setState(() {
      scheduleMap = teamSchedule;
      isUserScheduled = userIsScheduled;
      isWorshipLeader = userIsWorshipLeader;
    });
  }

  DateTime getPracticeMinDate(DateTime sunday) {
    return sunday.subtract(const Duration(days: 6));
  }

  DateTime getPracticeMaxDate(DateTime sunday) {
    return sunday;
  }

  Future<void> _pickPracticeTime() async {
    final minDate = getPracticeMinDate(widget.selectedDate);
    final maxDate = getPracticeMaxDate(widget.selectedDate);

    final date = await showDatePicker(
      context: context,
      initialDate: selectedPracticeTime ?? minDate,
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(selectedPracticeTime ?? DateTime.now()),
    );

    if (time == null) return;

    setState(() {
      selectedPracticeTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _savePracticeTime() async {
    if (selectedPracticeTime == null) return;

    final practiceTimeStr = selectedPracticeTime!.toIso8601String();
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    // 1️⃣ Fetch the map of assigned roles for the date
    final teamMap = await ScheduleUtils.fetchTeamStatusForDate(
        widget.selectedDate, widget.serviceLanguage);

    // 2️⃣ Collect all unique user UIDs with a non-empty function
    final Set<String> assignedUserUids = {};
    teamMap.forEach((functionName, members) {
      if (functionName.trim().isNotEmpty) {
        for (var member in members) {
          if (member['uid'] != null && (member['uid'] as String).isNotEmpty) {
            assignedUserUids.add(member['uid']);
          }
        }
      }
    });

    if (assignedUserUids.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No users assigned for this date.'),
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    // 3️⃣ Update only assigned users
    for (final uid in assignedUserUids) {
      // Get a reference to the specific schedule document for this date
      final scheduleDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(dateKey);

      final scheduleDocSnapshot = await scheduleDocRef.get();

      // Check if the schedule document for this date exists
      if (scheduleDocSnapshot.exists) {
        // If it exists, update the 'practiceTime' field within it
        await scheduleDocRef.update({
          'practiceTime': practiceTimeStr,
        });
        print(
            'Updated practiceTime for user $uid on $dateKey'); // For debugging
      } else {
        // If it doesn't exist, you might want to create it or log an error
        // Depending on your app logic, if a user is assigned, their schedule document should exist.
        // If it doesn't, this indicates a data inconsistency.
        print(
            'Schedule document for user $uid on $dateKey does not exist. Skipping update.'); // For debugging
        // You could also create the document if it's expected to be created here:
        // await scheduleDocRef.set({'practiceTime': practiceTimeStr}, SetOptions(merge: true));
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Practice time updated successfully'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, MMM d, yy').format(widget.selectedDate),
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurface),
                splashRadius: 20,
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          if (widget.isServiceScheduled) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Service: ${(widget.serviceLanguage != null && widget.serviceLanguage!.isNotEmpty) ? widget.serviceLanguage : 'Not scheduled'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.notifications, color: colorScheme.primary),
                  tooltip: 'Notify',
                  splashRadius: 20,
                  onPressed: () async {
                    final message = _generateScheduleMessage();
                    await WhatsAppHelper.shareWhatsAppGroupMessage(message);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final function in ScheduleUtils.functionOrder) ...[
                Text(
                  function,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: (scheduleMap[function] ?? []).isNotEmpty
                      ? scheduleMap[function]!
                          .map((user) => Chip(
                                label: Text(
                                  user['name'] ?? 'Unnamed',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                                backgroundColor: colorScheme.secondaryContainer,
                              ))
                          .toList()
                      : [
                          Chip(
                            label: Text(
                              'No one scheduled',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer
                                    .withAlpha(178),
                              ),
                            ),
                            backgroundColor: colorScheme.secondaryContainer,
                          )
                        ],
                ),
                const SizedBox(height: 12),
              ],
              if (isWorshipLeader) ...[
                Divider(color: colorScheme.outline.withAlpha(100)),
                Text(
                  'Set Practice Time:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickPracticeTime,
                  icon: Icon(Icons.schedule, color: colorScheme.onPrimary),
                  label: Text(
                    selectedPracticeTime != null
                        ? DateFormat('EEE, MMM d • hh:mm a')
                            .format(selectedPracticeTime!)
                        : 'Select Practice Time',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _savePracticeTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Update Practice Time'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
