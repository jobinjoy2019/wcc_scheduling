import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _saving = false;
  bool _isLoading = true;
  String? _email;
  String? _fromRoute;
  final List<String> _selectedRoles = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _fromRoute ??= args?['from'] ?? '/members';
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _email = user.email;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      // Only load firstName and lastName
      if (data['firstName'] is String && data['firstName'].trim().isNotEmpty) {
        _firstnameController.text = data['firstName'].trim();
      }

      if (data['lastName'] is String && data['lastName'].trim().isNotEmpty) {
        _lastnameController.text = data['lastName'].trim();
      }

      if (data['mobile'] is String && data['mobile'].trim().isNotEmpty) {
        _mobileController.text = data['mobile'].trim();
      }

      if (data['functions'] is List) {
        _selectedRoles.addAll(List<String>.from(data['functions']));
      }
    }

    setState(() => _isLoading = false);
  }

  void _toggleRole(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  Future<void> _submitProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final trimmedFirstName = _firstnameController.text.trim();
    final trimmedLastName = _lastnameController.text.trim();
    final trimmedMobile = _mobileController.text.trim();

    if (trimmedFirstName.isEmpty || _selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please enter your first name and select at least one role.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Update FirebaseAuth displayName
      await user.updateDisplayName(trimmedFirstName);
      await user.reload();

      // Update Firestore document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': trimmedFirstName,
        'lastName': trimmedLastName,
        'mobile': trimmedMobile,
        'functions': _selectedRoles,
        'email': user.email,
        'uid': user.uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, _fromRoute ?? '/members');
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _email != null ? "Update Your Profile" : "Complete Your Profile"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_email != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Email: $_email',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  const Text("Enter your name", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _firstnameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lastnameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Mobile Number'),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Select your roles (you can pick more than one):",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: ScheduleUtils.functionOrder.map((role) {
                      final selected = _selectedRoles.contains(role);
                      return FilterChip(
                        label: Text(role),
                        selected: selected,
                        onSelected: (_) => _toggleRole(role),
                        selectedColor: Colors.deepPurple,
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saving ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F7CEF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Save and Continue"),
                  ),
                ],
              ),
            ),
    );
  }
}
