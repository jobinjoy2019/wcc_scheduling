import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SwapUserDialog extends StatefulWidget {
  final String dateId;
  final String functionName;
  final String serviceLanguage;
  final String currentUserId;

  const SwapUserDialog({
    super.key,
    required this.dateId,
    required this.functionName,
    required this.serviceLanguage,
    required this.currentUserId,
  });

  @override
  State<SwapUserDialog> createState() => _SwapUserDialogState();
}

class _SwapUserDialogState extends State<SwapUserDialog> {
  String? _selectedUserId;
  bool _loading = true;
  List<Map<String, dynamic>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    final firestore = FirebaseFirestore.instance;
    final usersSnapshot = await firestore.collection('users').get();
    final List<Map<String, dynamic>> candidates = [];

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'];
      final functions = List<String>.from(data['functions'] ?? []);

      final firstName = (data['firstName'] as String?)?.trim() ?? '';
      final lastName = (data['lastName'] as String?)?.trim() ?? '';
      String name = ('$firstName $lastName').trim();

      if (name.isEmpty) {
        name = 'Unnamed';
      }

      if (uid == widget.currentUserId) continue; // exclude self
      if (!functions.contains(widget.functionName)) continue;

      final scheduleDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(widget.dateId)
          .get();

      final scheduleData = scheduleDoc.data();
      final blockout = scheduleData?['blockout'] == true;
      final hasFunction =
          (scheduleData?['functions'] as List?)?.isNotEmpty ?? false;

      if (blockout || hasFunction) continue;

      candidates.add({
        'uid': uid,
        'name': name,
      });
    }

    if (mounted) {
      setState(() {
        _availableUsers = candidates;
        _loading = false;
      });
    }
  }

  Future<void> _performSwap() async {
    if (_selectedUserId == null) return;

    final firestore = FirebaseFirestore.instance;

    // 1. Remove function from current user
    final currentUserScheduleRef = firestore
        .collection('users')
        .doc(widget.currentUserId)
        .collection('schedules')
        .doc(widget.dateId);

    await currentUserScheduleRef.set(
      {
        'functions': FieldValue.arrayRemove([widget.functionName]),
        'response': null,
        'service': widget.serviceLanguage,
      },
      SetOptions(merge: true),
    );

    // 2. Assign function to new user with Pending response
    final newUserScheduleRef = firestore
        .collection('users')
        .doc(_selectedUserId)
        .collection('schedules')
        .doc(widget.dateId);

    await newUserScheduleRef.set(
      {
        'functions': [widget.functionName],
        'response': 'Pending',
        'service': widget.serviceLanguage,
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      Navigator.pop(context, true); // Return success
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3D),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Swap with...',
            style: TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _availableUsers.isEmpty
                ? const Text(
                    'No available users found.',
                    style: TextStyle(color: Colors.white70),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableUsers.length,
                    itemBuilder: (context, index) {
                      final user = _availableUsers[index];
                      final uid = user['uid'];
                      final name = user['name'];
                      final selected = _selectedUserId == uid;

                      return ListTile(
                        tileColor: selected ? Colors.blue : Colors.transparent,
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedUserId = uid;
                          });
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _selectedUserId != null ? _performSwap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm Swap'),
        ),
      ],
    );
  }
}
