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

      if (uid == widget.currentUserId) continue;
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

    final batch = firestore.batch();

    final currentUserScheduleRef = firestore
        .collection('users')
        .doc(widget.currentUserId)
        .collection('schedules')
        .doc(widget.dateId);

    batch.set(
      currentUserScheduleRef,
      {
        'functions': FieldValue.arrayRemove([widget.functionName]),
        'response': null,
        'service': widget.serviceLanguage,
      },
      SetOptions(merge: true),
    );

    final newUserScheduleRef = firestore
        .collection('users')
        .doc(_selectedUserId)
        .collection('schedules')
        .doc(widget.dateId);

    batch.set(
      newUserScheduleRef,
      {
        'functions': FieldValue.arrayUnion([widget.functionName]),
        'response': 'Pending',
        'service': widget.serviceLanguage,
      },
      SetOptions(merge: true),
    );

    // 🔥 NEW PART: Also update the central /schedules/{dateId} doc
    // Fetch the new user's *name* from /users/{uid}
    final newUserDoc =
        await firestore.collection('users').doc(_selectedUserId).get();
    final newUserData = newUserDoc.data();
    String firstName = (newUserData?['firstName'] as String?)?.trim() ?? '';
    String lastName = (newUserData?['lastName'] as String?)?.trim() ?? '';
    String fullName = ('$firstName $lastName').trim();
    if (fullName.isEmpty) {
      fullName = (newUserData?['name'] as String?)?.trim() ?? 'Unnamed';
    }

    final centralScheduleRef =
        firestore.collection('schedules').doc(widget.dateId);

    batch.set(
      centralScheduleRef,
      {
        widget.serviceLanguage: {
          'assignments': {
            widget.functionName: [
              {
                'uid': _selectedUserId,
                'name': fullName,
                'response': 'Pending',
              }
            ]
          }
        }
      },
      SetOptions(merge: true),
    );

    // ✅ Commit all writes together
    await batch.commit();

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Swap with...',
            style: theme.textTheme.titleLarge?.copyWith(
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
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
            : _availableUsers.isEmpty
                ? Text(
                    'No available users found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withAlpha(178),
                    ),
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
                        tileColor: selected
                            ? colorScheme.primary.withAlpha(75)
                            : Colors.transparent,
                        title: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
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
          child: Text(
            'Cancel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface.withAlpha(178),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedUserId != null ? _performSwap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
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
