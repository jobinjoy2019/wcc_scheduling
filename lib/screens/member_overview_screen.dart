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
  late Future<String?> _practiceTimeFuture;
  final Map<String, Future<Map<String, List<Map<String, dynamic>>>>>
      _scheduleCache = {};
  String functionforday = '';
  String serviceLanguageforday = '';

  List<String> userRoles = [];
  String currentRole = 'Member';

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
    if (uid == null) return;

    final blockouts = await ScheduleUtils.loadBlockoutDatesForUser(uid);
    final practices = await ScheduleUtils.fetchPracticeTimeForWeek(uid);

    setState(() {
      selectedBlockoutDates = blockouts;
      _practiceTimeFuture = Future.value(practices);
      if (practices != null) {
        scheduledDates = [DateTime.parse(practices)];
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

  Future<Map<String, List<Map<String, dynamic>>>> _getScheduleForDate(
    DateTime date,
    String? service,
  ) {
    final cleanDate = _cleanDate(date);
    final cacheKey = service != null
        ? '${cleanDate.toIso8601String()}|$service'
        : '${cleanDate.toIso8601String()}|ALL';

    if (!_scheduleCache.containsKey(cacheKey)) {
      _scheduleCache[cacheKey] =
          ScheduleUtils.fetchTeamStatusForDate(cleanDate, service);
    }
    return _scheduleCache[cacheKey]!;
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcomingSunday = now.add(Duration(days: (7 - now.weekday) % 7));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: ChurchAppBar(
          name: displayName, roles: userRoles, currentRole: currentRole),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Upcoming Schedule',
                style: TextStyle(
                  color: Colors.white,
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
                    final date = upcomingSunday.add(Duration(days: 7 * index));
                    final cleanDate = _cleanDate(date);

                    return FutureBuilder<String?>(
                      future: _getUserServiceForDate(cleanDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final String? serviceLanguage = snapshot.data;

                        return ScheduleCard(
                          date: cleanDate,
                          scheduleFuture:
                              _getScheduleForDate(cleanDate, serviceLanguage),
                          serviceLanguage: serviceLanguage,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Upcoming Practice Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<bool>(
                  future: ScheduleUtils.isUserScheduledForDate(
                    FirebaseAuth.instance.currentUser!.uid,
                    upcomingSunday,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        'Loading...',
                        style: TextStyle(color: Colors.white70),
                      );
                    }

                    final isScheduled = snapshot.data ?? false;

                    if (!isScheduled) {
                      return const Text(
                        'Not scheduled for this week.',
                        style: TextStyle(color: Colors.white70),
                      );
                    }

                    return FutureBuilder<String?>(
                      future: _practiceTimeFuture,
                      builder: (context, practiceSnapshot) {
                        if (practiceSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'Loading practice time...',
                            style: TextStyle(color: Colors.white70),
                          );
                        }

                        final raw = practiceSnapshot.data;
                        if (raw == null || raw.isEmpty || raw == 'Not set') {
                          return const Text(
                            'Practice not set yet.',
                            style: TextStyle(color: Colors.white70),
                          );
                        }

                        final formattedTime = formatPracticeTime(raw);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Practice Time:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                color: Colors.white,
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
                  const Text(
                    'Calendar View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _openBlockoutDialog,
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    label: const Text('Manage Blockout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomScheduleCalendar(
                focusedDay: _calendarFocusedDay,
                selectedDates: const {},
                onDaySelected: (_) {},
                colorHighlights: {
                  Colors.redAccent: selectedBlockoutDates,
                  Colors.purple: scheduledDates,
                },
                showLegend: true,
                legendMap: {
                  Colors.redAccent: 'Blockout',
                  Colors.purple: 'Practice',
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Pending Requests',
                style: TextStyle(
                  color: Colors.white,
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
    );
  }
}
