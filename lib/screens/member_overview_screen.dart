import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/custom_schedule_calendar.dart';
import 'package:scheduler_app/widgets/blockout_calendar_dialog.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';
import 'package:scheduler_app/widgets/schedule_card.dart';
import 'package:scheduler_app/widgets/appbar.dart';
import 'package:scheduler_app/widgets/pending_requests_list.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String displayName = 'Team Member';
  DateTime _calendarFocusedDay = DateTime.now();
  List<DateTime> scheduledDates = [];
  List<DateTime> selectedBlockoutDates = [];
  String? practiceTime;
  List<String> functions = [];
  Future<String?>? _practiceTimeFuture;
  String functionforday = '';
  String serviceLanguageforday = '';

  List<String> userRoles = [];
  String currentRole = 'Member';
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchUserFunctions();
    _checkRoles();
    _loadMemberCalendarData();
  }

  Future<void> _loadUserProfile() async {
    final uid = user?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      final first = (data['firstName'] ?? '').toString().trim();
      setState(() {
        displayName = first.isEmpty ? 'Team Member' : first;
      });
    }
  }

  Future<void> _loadMemberCalendarData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() {
        _practiceTimeFuture = Future.value('Not set');
        scheduledDates = [];
      });
      return;
    }

    final blockouts = await ScheduleUtils.loadBlockoutDatesForUser(uid);
    final practiceTime = await ScheduleUtils.fetchPracticeTimeForWeek(uid);

    setState(() {
      selectedBlockoutDates = blockouts;
      _practiceTimeFuture = Future.value(practiceTime ?? 'Not set');

      if (practiceTime != null && practiceTime.isNotEmpty) {
        try {
          scheduledDates = [DateTime.parse(practiceTime)];
        } catch (e) {
          scheduledDates = [];
        }
      } else {
        scheduledDates = [];
      }
    });
  }

  Future<void> _fetchUserFunctions() async {
    final uid = user?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['functions'] != null) {
      setState(() {
        functions = List<String>.from(data['functions']);
      });
    }
  }

  Future<void> _checkRoles() async {
    final uid = user?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final roles = List<String>.from(doc.data()?['roles'] ?? []);

    String determinedRole = 'Member';
    if (roles.contains('Admin')) {
      determinedRole = 'Admin';
    } else if (roles.contains('Leader')) {
      determinedRole = 'Leader';
    }

    setState(() {
      userRoles = roles;
      currentRole = determinedRole;
    });
  }

  DateTime _cleanDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<String?> _getUserServiceForDate(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .doc(formattedDate)
        .get();

    if (!docSnapshot.exists) return null;

    final data = docSnapshot.data();
    return data?['service'] as String?;
  }

  String formatPracticeTime(String raw) {
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('EEEE, MMMM d • h:mm a').format(parsed);
    } catch (e) {
      return raw;
    }
  }

  void _openBlockoutDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const BlockoutCalendarDialog(),
    );

    await _loadMemberCalendarData();
  }

  Future<void> _refreshDashboard() async {
    // For example
    await Future.wait([
      _fetchUserFunctions(),
      _loadMemberCalendarData(),
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final upcomingSunday = now.add(Duration(days: (7 - now.weekday) % 7));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: ChurchAppBar(
          name: displayName, roles: userRoles, currentRole: currentRole),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          edgeOffset: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Upcoming Schedule',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final date =
                          upcomingSunday.add(Duration(days: 7 * index));
                      final cleanDate = _cleanDate(date);

                      return FutureBuilder<String?>(
                        future: _getUserServiceForDate(cleanDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              width: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: colorScheme.primary,
                                ),
                              ),
                            );
                          }

                          final String? serviceLanguage = snapshot.data;

                          return ScheduleCard(
                            date: cleanDate,
                            scheduleStream:
                                ScheduleUtils.getScheduleStreamForDate(
                                    cleanDate, serviceLanguage),
                            serviceLanguage: serviceLanguage,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upcoming Practice Time',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<bool>(
                    future: ScheduleUtils.isUserScheduledForDate(
                      FirebaseAuth.instance.currentUser!.uid,
                      upcomingSunday,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'Loading...',
                          style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(178)),
                        );
                      }

                      final isScheduled = snapshot.data ?? false;

                      if (!isScheduled) {
                        return Text(
                          'Not scheduled for this week.',
                          style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(178)),
                        );
                      }

                      return FutureBuilder<String?>(
                        future: _practiceTimeFuture,
                        builder: (context, practiceSnapshot) {
                          if (practiceSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                              'Loading practice time...',
                              style: TextStyle(
                                color: colorScheme.onSurface.withAlpha(178),
                              ),
                            );
                          }

                          final raw = practiceSnapshot.data;
                          if (raw == null || raw.isEmpty || raw == 'Not set') {
                            return Text(
                              'Practice not set yet.',
                              style: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(178)),
                            );
                          }

                          final formattedTime = formatPracticeTime(raw);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Practice Time:',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withAlpha(178),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Calendar View',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _openBlockoutDialog,
                      icon: Icon(Icons.calendar_today,
                          color: colorScheme.onPrimary),
                      label: const Text('Manage Blockout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomScheduleCalendar(
                  focusedDay: _calendarFocusedDay,
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (newFormat) {
                    setState(() {
                      _calendarFormat = newFormat;
                    });
                  },
                  selectedDates: const {},
                  onDaySelected: (_) {},
                  colorHighlights: {
                    colorScheme.error: selectedBlockoutDates,
                    colorScheme.secondary: scheduledDates,
                  },
                  showLegend: true,
                  legendMap: {
                    colorScheme.error: 'Blockout',
                    colorScheme.secondary: 'Practice',
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Pending Requests',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const PendingRequestsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
