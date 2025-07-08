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

      // Check user's schedule for this date
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
        continue; // skip this user
      }

      // Add to their functions
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

    // Map each userId to their selected functions
    final Map<String, List<String>> userFunctionsMap = {};

    for (final entry in selectedUsersByFunction.entries) {
      final function = entry.key;
      for (final uid in entry.value) {
        userFunctionsMap.putIfAbsent(uid, () => []);
        userFunctionsMap[uid]!.add(function);
      }
    }

    // For each user, overwrite their schedule for the selected date
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: Colors.white,
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
                        // Make text *always* white
                        color: Colors.white,
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFF00AAAA),
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
          const Text(
            'Select Week Date',
            style: TextStyle(color: Colors.white, fontSize: 18),
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
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white),
              todayDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(color: Colors.white),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.redAccent),
            ),
          ),
          const SizedBox(height: 16),

          // Always show function names, users only if date selected
          ...functionOrder.map((function) {
            final users = functionUsers[function] ?? [];
            final selectedSet =
                selectedUsersByFunction.putIfAbsent(function, () => {});

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  function,
                  style: const TextStyle(
                    color: Colors.white,
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
                        selectedColor: Colors.green,
                        checkmarkColor: Colors.white,
                        labelStyle: const TextStyle(color: Colors.white),
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
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
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
