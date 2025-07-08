import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/blockout_calendar_dialog.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';
import 'package:scheduler_app/widgets/schedule_card.dart';
import 'package:scheduler_app/widgets/appbar.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/custom_schedule_calendar.dart';
import 'package:scheduler_app/widgets/swap_user_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:scheduler_app/widgets/whatsapp_message.dart';
import 'package:scheduler_app/widgets/pending_requests_list.dart';

class LeaderDashboardScreen extends StatefulWidget {
  const LeaderDashboardScreen({super.key});

  @override
  State<LeaderDashboardScreen> createState() => _LeaderDashboardScreenState();
}

class _LeaderDashboardScreenState extends State<LeaderDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late String name;
  late String uid;
  DateTime? _firstScheduleCardDate;
  DateTime _calendarFocusedDay = DateTime.now();
  Set<DateTime> selectedDate = {};
  String selectedService = 'English';
  List<DateTime> scheduledDates = [];
  Set<DateTime> selectedBlockoutDates = {};
  Map<DateTime, List<String>> blockoutUsersByDate = {};
  String? worshipLeaderPhoneNumber;
  List<String> userRoles = [];
  String currentRole = 'Member';
  final Map<String, Future<Map<String, List<Map<String, dynamic>>>>>
      _scheduleCache = {};

  Map<String, List<Map<String, dynamic>>> teamStatusByFunction = {};

  Future<String?> _practiceTimeFuture = Future.value(null);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      name = user.displayName ?? 'Leader';
      uid = user.uid;
    }

    _checkRoles();
    _loadAllUserBlockouts();
    _loadInitialPracticeTime();
    _loadScheduledPracticeDates();
  }

  Future<void> _loadInitialPracticeTime() async {
    final service = selectedService;

    if (_firstScheduleCardDate == null) {
      final now = DateTime.now();
      final upcomingSunday = now.add(Duration(days: (7 - now.weekday) % 7));
      _firstScheduleCardDate = _cleanDate(upcomingSunday);
    }

    final uid = await _findWorshipLeaderUid(
      _firstScheduleCardDate!,
      service,
    );

    if (mounted) {
      setState(() {
        if (uid != null) {
          _practiceTimeFuture = ScheduleUtils.fetchPracticeTimeForWeek(uid);
        } else {
          _practiceTimeFuture = Future.value('Not set');
        }
      });
    }
  }

  Future<List<DateTime>> getScheduledDatesFromFormattedFuture(
      Future<String?> futureFormattedDateString,
      {String locale = 'en_US'}) async {
    try {
      final String? dateString = await futureFormattedDateString;

      if (dateString == null || dateString.isEmpty) {
        return [];
      }

      final DateFormat formatter = DateFormat('EEEE, MMMM d • h:mm a', locale);

      final DateTime parsedDateTime = formatter.parse(dateString);

      return [parsedDateTime];
    } catch (e) {
      debugPrint('Error parsing formatted date string from Future: $e');
      return [];
    }
  }

  /// Normalize DateTime to remove time part
  DateTime _cleanDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    _scheduleCache.clear();
    super.dispose();
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

  Future<void> _loadAllUserBlockouts() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final Set<DateTime> allBlockoutDates = {};
    final Map<DateTime, List<String>> usersByDate = {};

    for (final userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final userName = ([firstName, lastName]
              .where((part) => part.isNotEmpty)
              .join(' ')
              .trim()
              .isEmpty)
          ? 'Unknown'
          : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
      final uid = userDoc.id;

      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .get();

      for (final scheduleDoc in schedulesSnapshot.docs) {
        final data = scheduleDoc.data();

        if (data['blockout'] != true) continue;

        try {
          final parsedDate = DateTime.parse(scheduleDoc.id);
          final cleanDate = _cleanDate(parsedDate);

          allBlockoutDates.add(cleanDate);
          usersByDate.putIfAbsent(cleanDate, () => []).add(userName);
        } catch (e) {
          print('Error parsing blockout date: ${scheduleDoc.id}');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      selectedBlockoutDates
        ..clear()
        ..addAll(allBlockoutDates);

      blockoutUsersByDate
        ..clear()
        ..addAll(usersByDate);
    });
  }

  void _handleDaySelected(Set<DateTime> selected) {
    if (selected.isEmpty) return;

    final picked = _cleanDate(selected.first);

    setState(() {
      if (selectedDate.contains(picked)) {
        selectedDate.remove(picked);
        teamStatusByFunction = {};
      } else {
        selectedDate = {picked};
      }
    });

    if (selectedDate.isNotEmpty) {
      _loadTeamStatusForDate(picked);
    }
  }

  Future<String?> _findWorshipLeaderUid(DateTime date, String service) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final usersSnap =
        await FirebaseFirestore.instance.collection('users').get();

    for (final userDoc in usersSnap.docs) {
      final uid = userDoc['uid'];

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(formattedDate)
          .get();

      final data = scheduleDoc.data();
      if (data == null) continue;

      final userService = data['service'] as String?;
      final functions = data['functions'] as List<dynamic>?;

      if (userService != service) continue;
      if (functions == null || !functions.contains('Worship Leader')) continue;

      return uid;
    }
    return null;
  }

  void _handleDayDoubleTapped(DateTime date) {
    final cleanDate = _cleanDate(date);
    final names = blockoutUsersByDate[cleanDate] ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3D),
        title: Text(
          'Blockouts for ${DateFormat('EEEE, MMM d').format(cleanDate)}',
          style: const TextStyle(color: Colors.white),
        ),
        content: names.isEmpty
            ? const Text(
                'No users blocked this date.',
                style: TextStyle(color: Colors.white70),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: names
                    .map((name) =>
                        Text(name, style: const TextStyle(color: Colors.white)))
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Colors.lightBlueAccent)),
          )
        ],
      ),
    );
  }

  void _openBlockoutManager() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const BlockoutCalendarDialog(),
    );

    if (result == true) {
      await _loadAllUserBlockouts();
    }
  }

  Future<void> _loadTeamStatusForDate(DateTime date) async {
    final cleanDate = _cleanDate(date);
    final result =
        await ScheduleUtils.fetchTeamStatusForDate(cleanDate, selectedService);
    if (!mounted) return;
    setState(() {
      teamStatusByFunction = result;
    });
  }

  String formatPracticeTime(String? raw) {
    if (raw == null) return 'Not set';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('EEEE, MMMM d • h:mm a').format(parsed);
    } catch (e) {
      return raw;
    }
  }

  Future<void> _handleServiceToggle(int index) async {
    final newService = index == 0 ? 'English' : 'Hindi';

    setState(() {
      selectedService = newService;
      selectedDate.clear();
      _practiceTimeFuture = Future.value(null);
      worshipLeaderPhoneNumber = null; // Reset the number
    });

    if (_firstScheduleCardDate != null) {
      final uid = await _findWorshipLeaderUid(
        _firstScheduleCardDate!,
        newService,
      );

      if (uid != null) {
        // Fetch practice time
        final practiceTimeFuture = ScheduleUtils.fetchPracticeTimeForWeek(uid);

        // Fetch worship leader phone number
        final leaderDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        final phoneNumber = leaderDoc.data()?['mobile'] as String?;

        setState(() {
          _practiceTimeFuture = practiceTimeFuture;
          worshipLeaderPhoneNumber = phoneNumber ?? '';
        });
      } else {
        setState(() {
          _practiceTimeFuture = Future.value('Not set');
          worshipLeaderPhoneNumber = null;
        });
      }
    }
  }

  Future<void> _loadScheduledPracticeDates() async {
    final List<DateTime> loadedDates =
        await getScheduledDatesFromFormattedFuture(_practiceTimeFuture);

    if (mounted) {
      setState(() {
        scheduledDates = loadedDates;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar:
          ChurchAppBar(name: name, roles: userRoles, currentRole: currentRole),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final halfWidth = (constraints.maxWidth - 8) / 2;
                    return ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [
                        selectedService == 'English',
                        selectedService == 'Hindi',
                      ],
                      onPressed: _handleServiceToggle,
                      color: Colors.white,
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFF00AAAA),
                      constraints: BoxConstraints(
                        minHeight: 40,
                        minWidth: halfWidth,
                      ),
                      children: const [
                        Center(
                            child:
                                Text('English', textAlign: TextAlign.center)),
                        Center(
                            child: Text('Hindi', textAlign: TextAlign.center)),
                      ],
                    );
                  },
                ),
              ),
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
                    final now = DateTime.now();
                    final upcomingSunday =
                        now.add(Duration(days: (7 - now.weekday) % 7));
                    final date = upcomingSunday.add(Duration(days: 7 * index));
                    final cleanDate = _cleanDate(date);

                    if (index == 0 && _firstScheduleCardDate == null) {
                      _firstScheduleCardDate = cleanDate;
                    }

                    return ScheduleCard(
                      date: cleanDate,
                      serviceLanguage: selectedService,
                      scheduleFuture:
                          _getScheduleForDate(cleanDate, selectedService),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Upcoming Practice Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await WhatsAppHelper.sendWhatsAppMessage(
                        phoneNumber: '91${worshipLeaderPhoneNumber ?? ''}',
                        message: 'Hi there 😊,'
                            'Could you please schedule the practice time when you get a chance? 🗓️✨'
                            'Really appreciate it — thank you! 🙏🌟',
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF00AAAA),
                    ),
                    icon: const Icon(FontAwesomeIcons.handPointer, size: 18),
                    label: const Text(
                      'Poke',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<String?>(
                  future: _practiceTimeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        'Loading practice time...',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    final raw = snapshot.data;
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
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    onPressed: _openBlockoutManager,
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    label: const Text('Manage Blockout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomScheduleCalendar(
                focusedDay: _calendarFocusedDay,
                onFocusedDayChanged: (newFocused) {
                  setState(() {
                    _calendarFocusedDay = newFocused;
                  });
                },
                selectedDates: selectedDate,
                onDaySelected: _handleDaySelected,
                onDayDoubleTapped: _handleDayDoubleTapped,
                colorHighlights: {
                  Colors.redAccent: selectedBlockoutDates.toList(),
                  Colors.purple: scheduledDates,
                },
                showLegend: true,
                legendMap: {
                  Colors.redAccent: 'Blockout',
                  Colors.purple: 'Practice',
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Team Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/schedule');
                    },
                    icon: const Icon(Icons.schedule, color: Colors.white),
                    label: const Text(
                      'Schedule Session',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...ScheduleUtils.functionOrder.map((function) {
                final members = teamStatusByFunction[function] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      function,
                      style: const TextStyle(
                        color: Color(0xFF00AAAA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (members.isEmpty)
                      const Text(
                        'No one scheduled',
                        style: TextStyle(color: Colors.white54),
                      )
                    else
                      ...members.map((member) {
                        // Safely get values with defaults
                        final name = member['name'] ?? 'Unnamed';
                        final response = member['response'];
                        final uid = member['uid'] as String? ?? '';
                        final functionName =
                            member['function'] as String? ?? '';
                        final dateStr = member['date'] as String? ?? '';
                        final service = member['service'] as String? ?? '';

                        Icon statusIcon;
                        if (response == "accepted") {
                          statusIcon = Icon(
                            LucideIcons.checkCircle,
                            color: Colors.green,
                            size: 24,
                          );
                        } else if (response == "declined") {
                          statusIcon = Icon(
                            LucideIcons.ban,
                            color: Colors.red,
                            size: 24,
                          );
                        } else {
                          statusIcon = Icon(
                            FontAwesomeIcons.hourglassHalf,
                            color: Colors.amber,
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Name on the left
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),

                              // Conditionally show the Update button only if selectedDate is not null
                              if (selectedDate.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    if (uid.isNotEmpty &&
                                        functionName.isNotEmpty &&
                                        dateStr.isNotEmpty &&
                                        service.isNotEmpty) {
                                      final swapped = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => SwapUserDialog(
                                          dateId: dateStr,
                                          functionName: functionName,
                                          serviceLanguage: service,
                                          currentUserId: uid,
                                        ),
                                      );
                                      if (swapped == true && mounted) {
                                        setState(() {});
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'User updated via swap')),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Cannot swap: Missing data for this entry.'),
                                        ),
                                      );
                                      debugPrint(
                                          'Missing data for swap: uid=$uid, functionName=$functionName, dateStr=$dateStr, service=$service');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blueAccent,
                                  ),
                                  child: const Text('Update'),
                                ),

                              const SizedBox(width: 8),

                              // Status icon on the right
                              statusIcon,
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                  ],
                );
              }),
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
