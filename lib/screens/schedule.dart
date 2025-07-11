import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/delete_schedule_button.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime? selectedDate;
  DateTime _calendarFocusedDay = DateTime.now();
  final Map<String, List<DocumentSnapshot>> functionUsers = {};
  final Map<String, Set<String>> selectedUsersByFunction = {};

  final List<String> functionOrder = ScheduleUtils.functionOrder;
  String _serviceLanguage = 'English';

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  Future<void> _fetchAvailableUsers() async {
    if (selectedDate == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final allUsersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final availableByFunction = <String, List<DocumentSnapshot>>{};
    for (final func in functionOrder) {
      availableByFunction[func] = [];
    }

    for (final userDoc in allUsersSnapshot.docs) {
      final uid = userDoc['uid'];
      final functions = List<String>.from(userDoc['functions'] ?? []);

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(formattedDate)
          .get();

      final data = scheduleDoc.data();
      final isBlockedOut = (data?['blockout'] == true);
      final hasFunctions = (data?['functions'] is List &&
          (data?['functions'] as List).isNotEmpty);

      if (isBlockedOut || hasFunctions) {
        continue;
      }

      for (final func in functions) {
        if (functionOrder.contains(func)) {
          availableByFunction[func]!.add(userDoc);
        }
      }
    }

    setState(() {
      functionUsers.clear();
      functionUsers.addAll(availableByFunction);
      selectedUsersByFunction.clear();
    });
  }

  Future<void> _submitSchedule() async {
    if (selectedDate == null) return;

    final scheduleDate = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );
    final formattedDate = DateFormat('yyyy-MM-dd').format(scheduleDate);

    final batch = FirebaseFirestore.instance.batch();
    final Map<String, List<String>> userFunctionsMap = {};

    for (final entry in selectedUsersByFunction.entries) {
      final function = entry.key;
      for (final uid in entry.value) {
        userFunctionsMap.putIfAbsent(uid, () => []);
        userFunctionsMap[uid]!.add(function);
      }
    }

    for (final entry in userFunctionsMap.entries) {
      final uid = entry.key;
      final functions = entry.value;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(formattedDate);

      batch.set(docRef, {
        'functions': functions,
        'response': 'Pending',
        'service': _serviceLanguage,
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule successfully saved!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: const Text('Schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final halfWidth = (constraints.maxWidth - 8) / 2;
                      return ToggleButtons(
                        borderRadius: BorderRadius.circular(8),
                        isSelected: [
                          _serviceLanguage == 'English',
                          _serviceLanguage == 'Hindi',
                        ],
                        onPressed: (index) {
                          setState(() {
                            _serviceLanguage = index == 0 ? 'English' : 'Hindi';
                            selectedDate = null;
                            selectedUsersByFunction.clear();
                          });
                        },
                        color: colorScheme.tertiary.withAlpha(178),
                        selectedColor: colorScheme.onSurface,
                        fillColor: colorScheme.tertiary,
                        constraints: BoxConstraints(
                          minHeight: 40,
                          minWidth: halfWidth,
                        ),
                        children: const [
                          Text('English', textAlign: TextAlign.center),
                          Text('Hindi', textAlign: TextAlign.center),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select Week Date',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
          ),
          const SizedBox(height: 12),
          TableCalendar(
            focusedDay: _calendarFocusedDay,
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 28)),
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) =>
                selectedDate != null && day == selectedDate,
            onDaySelected: (selected, focused) {
              setState(() {
                if (selectedDate == selected) {
                  selectedDate = null;
                  selectedUsersByFunction.clear();
                } else {
                  selectedDate = selected;
                  _calendarFocusedDay = focused;
                  selectedUsersByFunction.clear();
                  _fetchAvailableUsers();
                }
              });
            },
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              todayDecoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(color: colorScheme.onSurface),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: colorScheme.onSurface),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: colorScheme.onSurface),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  TextStyle(color: colorScheme.onSurface.withAlpha(178)),
              weekendStyle: TextStyle(color: colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
          ...functionOrder.map((function) {
            final users = functionUsers[function] ?? [];
            final selectedSet =
                selectedUsersByFunction.putIfAbsent(function, () => {});

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  function,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedDate != null)
                  Wrap(
                    spacing: 6,
                    children: users.map((doc) {
                      final uid = doc['uid'];
                      final firstName =
                          (doc['firstName'] ?? '').toString().trim();
                      final lastName =
                          (doc['lastName'] ?? '').toString().trim();

                      final name = '$firstName $lastName'.trim();
                      final displayName = name.isEmpty ? 'Unnamed' : name;
                      final selected = selectedSet.contains(uid);
                      return FilterChip(
                        label: Text(displayName),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selectedSet.add(uid);
                            } else {
                              selectedSet.remove(uid);
                            }
                          });
                        },
                        selectedColor: colorScheme.primary,
                        checkmarkColor: colorScheme.onPrimary,
                        labelStyle: TextStyle(color: colorScheme.onSurface),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
              ],
            );
          }),
          if (selectedDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitSchedule,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DeleteScheduleButton(
                      date: selectedDate,
                      serviceLanguage: _serviceLanguage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
