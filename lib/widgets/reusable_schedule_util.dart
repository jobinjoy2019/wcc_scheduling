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

  static Map<String, List<Map<String, dynamic>>> parseScheduleDocument(
    Map<String, dynamic>? data,
    String formattedDate,
    String? serviceLanguage,
  ) {
    if (data == null || data.isEmpty) {
      return {for (final func in functionOrder) func: []};
    }

    final Map<String, dynamic>? serviceSection;
    if (serviceLanguage != null) {
      final section = data[serviceLanguage];
      if (section is Map<String, dynamic>) {
        serviceSection = section;
      } else {
        return {for (final func in functionOrder) func: []};
      }
    } else {
      final firstSection = data.entries.first.value;
      if (firstSection is Map<String, dynamic>) {
        serviceSection = firstSection;
      } else {
        return {for (final func in functionOrder) func: []};
      }
    }

    final String? practiceTime = serviceSection['practiceTime'] as String?;
    final String? service = serviceSection['serviceLanguage'] as String?;
    final assignments = serviceSection['assignments'];

    final Map<String, List<Map<String, dynamic>>> assignmentMap = {};

    if (assignments is Map) {
      assignments.forEach((function, userList) {
        if (userList is List) {
          for (final user in userList) {
            if (user is Map) {
              final uid = user['uid'] ?? '';
              final name = (user['name'] ?? 'Unnamed').toString();
              final response = (user['response'] ?? 'Unknown').toString();

              assignmentMap.putIfAbsent(function, () => []).add({
                'uid': uid,
                'name': name,
                'response': response,
                'practiceTime': practiceTime,
                'service': service,
                'date': formattedDate,
                'function': function,
              });
            }
          }
        }
      });
    }

    for (final func in functionOrder) {
      assignmentMap.putIfAbsent(func, () => []);
    }

    return assignmentMap;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> fetchTeamStatusForDate(
    DateTime date, [
    String? serviceLanguage,
  ]) async {
    final formattedDate = _formatDateKey(date);

    final centralDoc = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(formattedDate)
        .get();

    final data = centralDoc.data();
    return parseScheduleDocument(data, formattedDate, serviceLanguage);
  }

  static Future<bool> isUserScheduledForDate(String uid, DateTime date) async {
    final formattedDate = _formatDateKey(date);

    final docSnapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(formattedDate)
        .get();

    if (!docSnapshot.exists) return false;

    final data = docSnapshot.data();
    if (data == null) return false;

    // For each serviceLanguage section
    for (final serviceEntry in data.entries) {
      final serviceData = serviceEntry.value;
      if (serviceData is! Map<String, dynamic>) continue;

      final assignments = serviceData['assignments'];
      if (assignments is! Map<String, dynamic>) continue;

      // For each function
      for (final funcEntry in assignments.entries) {
        final usersList = funcEntry.value;
        if (usersList is! List) continue;

        // For each user
        for (final user in usersList) {
          if (user is Map && user['uid'] == uid) {
            return true;
          }
        }
      }
    }

    return false;
  }

  static Future<String?> fetchPracticeTimeForWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateId = _formatDateKey(date);

      try {
        final teamStatus = await fetchTeamStatusForDate(date);

        for (final assignments in teamStatus.values) {
          for (final user in assignments) {
            if (user['uid'] == uid) {
              return user['practiceTime'] as String?;
            }
          }
        }
      } catch (e) {
        print('⚠️ Error fetching practice time for $dateId: $e');
        continue;
      }
    }

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

  static bool hasAnyFunctionAssignedForService(
    Map<String, dynamic> fullSchedule,
    String serviceLanguage,
  ) {
    // If fullSchedule is already just the assignment map
    for (final value in fullSchedule.values) {
      if (value is List && value.isNotEmpty) {
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

  static Stream<Map<String, List<Map<String, dynamic>>>>
      getScheduleStreamForDate(
    DateTime date,
    String? serviceLanguage,
  ) {
    final formattedDate = _formatDateKey(date);

    return FirebaseFirestore.instance
        .collection('schedules')
        .doc(formattedDate)
        .snapshots()
        .map((doc) {
      return parseScheduleDocument(
        doc.data(),
        formattedDate,
        serviceLanguage,
      );
    });
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
  bool isLeaderOrAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _checkUserRole();
  }

  void _checkUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('❌ No current user');
      return;
    }

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      print('❌ User document not found for UID: $uid');
      return;
    }

    final data = userDoc.data();
    final role = data?['roles'];

    print('👤 UID: $uid');
    print('📝 Role from Firestore: $role');

    setState(() {
      isLeaderOrAdmin = role.contains('Leader') || role.contains('Admin');
      print('✅ isLeaderOrAdmin set to: $isLeaderOrAdmin');
    });
  }

  String _generateScheduleMessage() {
    final buffer = StringBuffer();

    // Add Date
    buffer.writeln(
        '📅 ${DateFormat('EEE, MMM d, yy').format(widget.selectedDate)}');

    // Add Service
    buffer.writeln('Service: ${widget.serviceLanguage ?? 'Not scheduled'}');

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

    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    final scheduleDoc = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(formattedDate)
        .get();

    if (!scheduleDoc.exists) {
      setState(() {
        scheduleMap = {};
        isUserScheduled = false;
        isWorshipLeader = false;
        selectedPracticeTime = null;
      });
      return;
    }

    final data = scheduleDoc.data();
    if (data == null || !data.containsKey(widget.serviceLanguage)) {
      setState(() {
        scheduleMap = {};
        isUserScheduled = false;
        isWorshipLeader = false;
        selectedPracticeTime = null;
      });
      return;
    }

    final serviceData = data[widget.serviceLanguage] as Map<String, dynamic>;
    final assignments = serviceData['assignments'] ?? {};
    final practiceTimeStr = serviceData['practiceTime'] as String?;

    // Build scheduleMap assuming all assignments are lists
    final Map<String, List<Map<String, dynamic>>> teamSchedule = {};

    for (final function in ScheduleUtils.functionOrder) {
      final assignmentList = assignments[function];
      if (assignmentList is List) {
        teamSchedule[function] = assignmentList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        teamSchedule[function] = [];
      }
    }

    // Check if current user is in any assignment
    bool userIsScheduled = teamSchedule.values.expand((v) => v).any((member) {
      return member['uid'] == currentUser.uid;
    });

    // Check specifically for Worship Leader
    bool userIsWorshipLeader = teamSchedule['Worship Leader']
            ?.any((member) => member['uid'] == currentUser.uid) ??
        false;

    setState(() {
      scheduleMap = teamSchedule;
      isUserScheduled = userIsScheduled;
      isWorshipLeader = userIsWorshipLeader;
      selectedPracticeTime =
          practiceTimeStr != null ? DateTime.tryParse(practiceTimeStr) : null;
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
      final scheduleDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(dateKey);

      final scheduleDocSnapshot = await scheduleDocRef.get();

      if (scheduleDocSnapshot.exists) {
        await scheduleDocRef.update({
          'practiceTime': practiceTimeStr,
        });
        print('Updated practiceTime for user $uid on $dateKey');
      } else {
        print(
            'Schedule document for user $uid on $dateKey does not exist. Skipping update.');
      }
    }

    // 4️⃣ NEW: Also update the central schedules/{dateKey} doc
    if (widget.serviceLanguage != null &&
        widget.serviceLanguage!.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('schedules')
          .doc(dateKey)
          .set({
        widget.serviceLanguage!: {
          'practiceTime': practiceTimeStr,
        }
      }, SetOptions(merge: true));
      print(
          'Updated central schedule for service ${widget.serviceLanguage} on $dateKey');
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
                if (isLeaderOrAdmin)
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
