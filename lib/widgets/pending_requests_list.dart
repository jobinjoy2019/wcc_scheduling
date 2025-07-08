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
        if (response == null || response.isEmpty || response.toLowerCase() == "pending") {
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

    final scheduleDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .doc(dateId);

    await scheduleDoc.set(
      {'response': response},
      SetOptions(merge: true),
    );

    if (mounted) {
      setState(() {}); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Response updated: $response')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pending = snapshot.data ?? [];

        if (pending.isEmpty) {
          return const Text(
            'No pending requests.',
            style: TextStyle(color: Colors.white70),
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
            final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(displayDate);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3D),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Service: ${service ?? 'Not set'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateUserResponse(dateStr, 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateUserResponse(dateStr, 'declined'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateUserResponse(dateStr, 'swap'),
                          icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                          label: const Text('Swap'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 14),
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
