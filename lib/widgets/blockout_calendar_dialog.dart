import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scheduler_app/widgets/custom_schedule_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BlockoutCalendarDialog extends StatefulWidget {
  const BlockoutCalendarDialog({super.key});

  @override
  State<BlockoutCalendarDialog> createState() => _BlockoutCalendarDialogState();
}

class _BlockoutCalendarDialogState extends State<BlockoutCalendarDialog> {
  Set<DateTime> selectedDates = {};
  Set<DateTime> existingBlockouts = {};
  DateTime focusedDate = DateTime.now();
  late String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadBlockoutDates();
  }

  Future<void> _loadBlockoutDates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('schedules')
        .get(const GetOptions(source: Source.serverAndCache));

    final dates = snapshot.docs
        .where((doc) => (doc.data()['blockout'] ?? false) == true)
        .map((doc) {
          try {
            final date = DateTime.parse(doc.id);
            return DateTime(date.year, date.month, date.day);
          } catch (e) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toSet();

    setState(() {
      existingBlockouts = dates;
      selectedDates.clear();
    });
  }

  void _toggleDate(DateTime day) {
    final cleanDay = DateTime(day.year, day.month, day.day);
    setState(() {
      if (selectedDates.contains(cleanDay)) {
        selectedDates.remove(cleanDay);
      } else {
        selectedDates.add(cleanDay);
      }
    });
  }

  void _handleDaySelected(Set<DateTime> selected) {
    if (selected.isEmpty) return;
    final picked = selected.first;
    _toggleDate(picked);
  }

  Future<void> _confirmBlockouts() async {
    if (selectedDates.isEmpty) {
      await _showAutoDismissDialog('No new blockouts selected.');
      return;
    }

    await Future.wait(
      selectedDates.map((date) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .doc(DateFormat('yyyy-MM-dd').format(date));
        return docRef.set({'blockout': true}, SetOptions(merge: true));
      }),
    );

    await _loadBlockoutDates();
    await _showAutoDismissDialog('Blockouts saved successfully');
  }

  Future<void> _removeBlockouts() async {
    if (selectedDates.isEmpty) {
      await _showAutoDismissDialog('No blockouts selected for removal.');
      return;
    }

    await Future.wait(
      selectedDates.map((date) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .doc(DateFormat('yyyy-MM-dd').format(date));
        return docRef.set({'blockout': false}, SetOptions(merge: true));
      }),
    );

    await _loadBlockoutDates();
    await _showAutoDismissDialog('Blockouts removed successfully');
  }

  Future<void> _showAutoDismissDialog(String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3D),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.of(context).pop(); // Close the alert
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3D),
      titlePadding:
          const EdgeInsets.only(top: 8, left: 16, right: 8, bottom: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Manage Blockouts',
            style: TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white),
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 450,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 400,
                child: CustomScheduleCalendar(
                  focusedDay: focusedDate,
                  onFocusedDayChanged: (newFocused) {
                    setState(() {
                      focusedDate = newFocused;
                    });
                  },
                  selectedDates: selectedDates,
                  onDaySelected: _handleDaySelected,
                  onDayDoubleTapped: null,
                  colorHighlights: {
                    Colors.redAccent: existingBlockouts.toList(),
                  },
                  showLegend: true,
                  legendMap: {
                    Colors.redAccent: 'Blockout',
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _confirmBlockouts,
                      icon: const Icon(Icons.check),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F7CEF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          (selectedDates.isEmpty && existingBlockouts.isEmpty)
                              ? null
                              : _removeBlockouts,
                      icon: const Icon(
                        FontAwesomeIcons.trash,
                        color: Colors.black87,
                        size: 18,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 223, 138, 138),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
