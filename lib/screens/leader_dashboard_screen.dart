import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/appbar.dart';
import 'package:scheduler_app/widgets/schedule_card.dart';
import 'package:scheduler_app/widgets/custom_schedule_calendar.dart';
import 'package:scheduler_app/widgets/swap_user_dialog.dart';
import 'package:scheduler_app/widgets/blockout_calendar_dialog.dart';
import 'package:scheduler_app/widgets/pending_requests_list.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:scheduler_app/widgets/whatsapp_message.dart';
import 'package:table_calendar/table_calendar.dart';

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
  Map<String, List<Map<String, dynamic>>> teamStatusByFunction = {};
  Future<String?> _practiceTimeFuture = Future.value(null);
  CalendarFormat _format = CalendarFormat.month;
  DateTime _scheduleRefreshToken = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (user != null) {
      name = user!.displayName ?? 'Leader';
      uid = user!.uid;
    }
    _checkRoles();
    _loadAllUserBlockouts();
    _loadScheduledPracticeDates();
    _loadInitialPracticeTime();
  }

  @override
  void dispose() {
    super.dispose();
  }

  DateTime _cleanDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _checkRoles() async {
    final uid = user?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final roles = List<String>.from(doc.data()?['roles'] ?? []);
    String determinedRole = 'Member';
    if (roles.contains('Admin'))
      determinedRole = 'Admin';
    else if (roles.contains('Leader')) determinedRole = 'Leader';
    setState(() {
      userRoles = roles;
      currentRole = determinedRole;
    });
  }

  Future<void> _loadInitialPracticeTime() async {
    if (_firstScheduleCardDate == null || selectedService.isEmpty) {
      setState(() {
        _practiceTimeFuture = Future.value(null);
        worshipLeaderPhoneNumber = null;
      });
      return;
    }

    try {
      final uid =
          await _findWorshipLeaderUid(_firstScheduleCardDate!, selectedService);

      if (uid != null) {
        final practiceTime = await ScheduleUtils.fetchPracticeTimeForWeek(uid);
        final leaderDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final phoneNumber = leaderDoc.data()?['mobile'] as String?;

        if (mounted) {
          setState(() {
            _practiceTimeFuture = Future.value(practiceTime ?? 'Not set');
            worshipLeaderPhoneNumber = phoneNumber ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _practiceTimeFuture = Future.value('Not set');
            worshipLeaderPhoneNumber = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading practice time or leader phone number: $e');
      if (mounted) {
        setState(() {
          _practiceTimeFuture = Future.value('Not set');
          worshipLeaderPhoneNumber = null;
        });
      }
    }
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
          debugPrint('Error parsing blockout date: ${scheduleDoc.id}');
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
    if (selectedDate.isNotEmpty) _loadTeamStatusForDate(picked);
  }

  void _handleDayDoubleTapped(DateTime date) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cleanDate = _cleanDate(date);
    final names = blockoutUsersByDate[cleanDate] ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Blockouts for ${DateFormat('EEEE, MMM d').format(cleanDate)}',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: names.isEmpty
            ? Text(
                'No users blocked this date.',
                style: TextStyle(color: colorScheme.onSurface.withAlpha(150)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: names
                    .map((name) => Text(name,
                        style: TextStyle(color: colorScheme.onSurface)))
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: colorScheme.primary)),
          )
        ],
      ),
    );
  }

  Future<void> _openBlockoutManager() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const BlockoutCalendarDialog(),
    );
    if (result == true) await _loadAllUserBlockouts();
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
    } catch (_) {
      return raw;
    }
  }

  Future<void> _handleServiceToggle(int index) async {
    final newService = index == 0 ? 'English' : 'Hindi';
    setState(() {
      selectedService = newService;
      selectedDate.clear();
      _practiceTimeFuture = Future.value(null);
      worshipLeaderPhoneNumber = null;
    });

    if (_firstScheduleCardDate != null) {
      final uid =
          await _findWorshipLeaderUid(_firstScheduleCardDate!, newService);
      if (uid != null) {
        final practiceTimeFuture = ScheduleUtils.fetchPracticeTimeForWeek(uid);
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
      if (data['service'] != service) continue;
      final functions = data['functions'] as List<dynamic>?;
      if (functions == null || !functions.contains('Worship Leader')) continue;
      return uid;
    }
    return null;
  }

  Future<void> _loadScheduledPracticeDates() async {
    final dateString = await _practiceTimeFuture;
    if (dateString == null || dateString.isEmpty) return;
    try {
      final formatter = DateFormat('EEEE, MMMM d • h:mm a');
      final parsedDateTime = formatter.parse(dateString);
      if (mounted) {
        setState(() {
          scheduledDates = [parsedDateTime];
        });
      }
    } catch (e) {
      debugPrint('Error parsing scheduled date: $e');
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _scheduleRefreshToken = DateTime.now(); // forces schedule refresh
    });
    // For example
    await Future.wait([
      _loadAllUserBlockouts(),
      _loadInitialPracticeTime(),
      _loadScheduledPracticeDates(),
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceColor = colorScheme.surfaceContainerHighest;
    final primaryColor = colorScheme.primary;
    final onSurfaceColor = colorScheme.onSurface;
    final highlightColor = colorScheme.tertiary;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: ChurchAppBar(
        name: name,
        roles: userRoles,
        currentRole: currentRole,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          edgeOffset: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SERVICE TOGGLE
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
                        color: onSurfaceColor,
                        selectedColor: onSurfaceColor,
                        fillColor: highlightColor.withAlpha(150),
                        constraints: BoxConstraints(
                          minHeight: 40,
                          minWidth: halfWidth,
                        ),
                        children: const [
                          Center(
                              child:
                                  Text('English', textAlign: TextAlign.center)),
                          Center(
                              child:
                                  Text('Hindi', textAlign: TextAlign.center)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // UPCOMING SCHEDULE
                Text(
                  'Upcoming Schedule',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: onSurfaceColor),
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
                      final date =
                          upcomingSunday.add(Duration(days: 7 * index));
                      final cleanDate = _cleanDate(date);

                      if (index == 0 && _firstScheduleCardDate == null) {
                        _firstScheduleCardDate = cleanDate;
                        // 👉 Call practice time loader AFTER _firstScheduleCardDate is available
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadInitialPracticeTime();
                        });
                      }

                      return ScheduleCard(
                        date: cleanDate,
                        serviceLanguage: selectedService,
                        key: ValueKey(
                            'schedule_${cleanDate}_$_scheduleRefreshToken'),
                        scheduleStream: ScheduleUtils.getScheduleStreamForDate(
                            cleanDate, selectedService),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // PRACTICE TIME SECTION
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Upcoming Practice Time',
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        if (worshipLeaderPhoneNumber == null ||
                            worshipLeaderPhoneNumber!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Worship leader contact not found.')),
                          );
                          return;
                        }
                        await WhatsAppHelper.sendWhatsAppMessage(
                          phoneNumber:
                              worshipLeaderPhoneNumber!.startsWith('91')
                                  ? worshipLeaderPhoneNumber!
                                  : '91${worshipLeaderPhoneNumber!}',
                          message:
                              'Hi there 😊, Could you please schedule the practice time when you get a chance? 🗓️✨ Really appreciate it — thank you! 🙏🌟',
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
                    color: surfaceColor.withAlpha(200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<String?>(
                    future: _practiceTimeFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'Loading practice time...',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: onSurfaceColor.withAlpha(178)),
                        );
                      }
                      final raw = snapshot.data;
                      if (raw == null || raw.isEmpty || raw == 'Not set') {
                        return Text(
                          'Practice not set yet.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: onSurfaceColor.withAlpha(178)),
                        );
                      }
                      final formattedTime = formatPracticeTime(raw);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Practice Time:',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: onSurfaceColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTime,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: onSurfaceColor.withAlpha(200)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // CALENDAR VIEW
                Row(
                  children: [
                    Text(
                      'Calendar View',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: onSurfaceColor),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _openBlockoutManager,
                      icon: Icon(Icons.calendar_today, color: onSurfaceColor),
                      label: const Text('Manage Blockout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: highlightColor.withAlpha(150),
                        foregroundColor: onSurfaceColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomScheduleCalendar(
                  focusedDay: _calendarFocusedDay,
                  calendarFormat: _format,
                  onFormatChanged: (newFormat) {
                    setState(() {
                      _format = newFormat;
                    });
                  },
                  onFocusedDayChanged: (newFocused) {
                    setState(() {
                      _calendarFocusedDay = newFocused;
                    });
                  },
                  selectedDates: selectedDate,
                  onDaySelected: _handleDaySelected,
                  onDayDoubleTapped: _handleDayDoubleTapped,
                  colorHighlights: {
                    highlightColor.withAlpha(178):
                        selectedBlockoutDates.toList(),
                    primaryColor.withAlpha(178): scheduledDates,
                  },
                  showLegend: true,
                  legendMap: {
                    highlightColor.withAlpha(178): 'Blockout',
                    primaryColor.withAlpha(178): 'Practice',
                  },
                ),
                const SizedBox(height: 24),

                // TEAM STATUS
                Row(
                  children: [
                    Text(
                      'Team Status',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: onSurfaceColor),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/schedule');
                      },
                      icon: Icon(Icons.schedule, color: onSurfaceColor),
                      label: const Text('Schedule Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: highlightColor.withAlpha(150),
                        foregroundColor: onSurfaceColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.secondary),
                      ),
                      const SizedBox(height: 8),
                      if (members.isEmpty)
                        Text(
                          'No one scheduled',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: onSurfaceColor.withAlpha(150)),
                        )
                      else
                        ...members.map((member) {
                          final name = member['name'] ?? 'Unnamed';
                          final response = member['response'];
                          final uid = member['uid'] as String? ?? '';
                          final functionName =
                              member['function'] as String? ?? '';
                          final dateStr = member['date'] as String? ?? '';
                          final service = member['service'] as String? ?? '';

                          Icon statusIcon;
                          if (response == "accepted") {
                            statusIcon = Icon(LucideIcons.checkCircle,
                                color: Colors.green, size: 24);
                          } else if (response == "declined") {
                            statusIcon = Icon(LucideIcons.ban,
                                color: Colors.red, size: 24);
                          } else {
                            statusIcon = Icon(FontAwesomeIcons.hourglassHalf,
                                color: Colors.amber);
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor.withAlpha(230),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: onSurfaceColor.withAlpha(200)),
                                  ),
                                ),
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
                                                  'Cannot swap: Missing data for this entry.')),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: highlightColor,
                                    ),
                                    child: const Text('Update'),
                                  ),
                                const SizedBox(width: 8),
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

                // PENDING REQUESTS
                Text(
                  'Pending Requests',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: onSurfaceColor),
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
