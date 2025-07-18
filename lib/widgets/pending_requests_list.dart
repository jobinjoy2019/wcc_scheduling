import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/swap_user_dialog.dart';

class PendingRequestsList extends StatefulWidget {
  const PendingRequestsList({super.key});

  @override
  State<PendingRequestsList> createState() => _PendingRequestsListState();
}

class _PendingRequestsListState extends State<PendingRequestsList> {
  String functionforday = '';
  String serviceLanguageforday = '';

  Future<List<Map<String, dynamic>>> _loadPendingRequests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userSchedulesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .get();

    final List<Map<String, dynamic>> pendingRequests = [];

    for (final doc in userSchedulesSnap.docs) {
      final data = doc.data();

      final response = (data['response'] as String?)?.trim();
      final functions = data['functions'] as List<dynamic>?;

      if (functions != null && functions.isNotEmpty) {
        if (response == null ||
            response.isEmpty ||
            response.toLowerCase() == "pending") {
          final service = data['service'] as String?;
          pendingRequests.add({
            'date': doc.id,
            'service': service,
            'functions': functions.map((f) => f.toString()).toList(),
          });
        }
      }
    }

    pendingRequests.sort((a, b) => a['date'].compareTo(b['date']));
    return pendingRequests;
  }

  Future<void> _updateUserResponse(String dateId, String response) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (response == 'swap') {
      await SwapUserDialog(
        dateId: dateId,
        functionName: functionforday,
        serviceLanguage: serviceLanguageforday,
        currentUserId: uid,
      );
      return;
    }

    // 1️⃣ Update user's personal schedule subdoc
    final scheduleDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .doc(dateId);

    await scheduleDoc.set(
      {'response': response},
      SetOptions(merge: true),
    );

    // 2️⃣ Update central schedules/{dateId}
    final centralDocRef =
        FirebaseFirestore.instance.collection('schedules').doc(dateId);

    final centralDocSnap = await centralDocRef.get();

    if (centralDocSnap.exists) {
      final data = centralDocSnap.data()!;
      final serviceSection = data[serviceLanguageforday];

      if (serviceSection != null && serviceSection is Map) {
        final assignments = serviceSection['assignments'];
        bool updated = false;

        if (assignments != null && assignments is Map) {
          assignments.forEach((function, usersList) {
            if (usersList is List) {
              for (final user in usersList) {
                if (user is Map && user['uid'] == uid) {
                  user['response'] = response;
                  updated = true;
                }
              }
            }
          });
        }

        if (updated) {
          await centralDocRef.set({
            serviceLanguageforday: {
              ...serviceSection,
              'assignments': assignments,
            }
          }, SetOptions(merge: true));
        }
      }
    }

    // 3️⃣ Show feedback
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Response updated: $response',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pending = snapshot.data ?? [];

        if (pending.isEmpty) {
          return Text(
            'No pending requests.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          );
        }

        return Column(
          children: pending.map((request) {
            final dateStr = request['date'] as String;
            final service = request['service'] as String?;
            functionforday = request['functions']?.isNotEmpty ?? false
                ? request['functions'][0]
                : '';
            serviceLanguageforday = service ?? '';
            final displayDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            final formattedDate =
                DateFormat('EEEE, MMM d, yyyy').format(displayDate);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(220),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Service: ${service ?? 'Not set'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _updateUserResponse(dateStr, 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: theme.textTheme.labelLarge,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _updateUserResponse(dateStr, 'declined'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: theme.textTheme.labelLarge,
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateUserResponse(dateStr, 'swap'),
                          icon: Icon(Icons.swap_horiz,
                              size: 16, color: colorScheme.onSecondary),
                          label: Text(
                            'Swap',
                            style: TextStyle(color: colorScheme.onSecondary),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
