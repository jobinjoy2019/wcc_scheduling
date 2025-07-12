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
        SnackBar(
          content: const Text(
              'Please enter your first name and select at least one role.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await user.updateDisplayName(trimmedFirstName);
      await user.reload();

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
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _email != null ? "Update Your Profile" : "Complete Your Profile",
          style: TextStyle(color: colorScheme.onPrimary),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
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
                      child: Text(
                        'Email: $_email',
                        style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(178)),
                      ),
                    ),
                  Text("Enter your name",
                      style: TextStyle(
                          fontSize: 16, color: colorScheme.onSurface)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _firstnameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      labelStyle: TextStyle(
                          color: colorScheme.onSurface.withAlpha(178)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: colorScheme.onSurface.withAlpha(128)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lastnameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      labelStyle: TextStyle(
                          color: colorScheme.onSurface.withAlpha(178)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: colorScheme.onSurface.withAlpha(128)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      labelStyle: TextStyle(
                          color: colorScheme.onSurface.withAlpha(178)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: colorScheme.onSurface.withAlpha(128)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Select your roles (you can pick more than one):",
                    style:
                        TextStyle(fontSize: 16, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: ScheduleUtils.functionOrder.map((role) {
                      final selected = _selectedRoles.contains(role);
                      return FilterChip(
                        label: Text(role,
                            style: TextStyle(color: colorScheme.onSurface)),
                        selected: selected,
                        onSelected: (_) => _toggleRole(role),
                        selectedColor: colorScheme.primary,
                        checkmarkColor: colorScheme.onPrimary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saving ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary),
                            ),
                          )
                        : const Text("Save and Continue"),
                  ),
                ],
              ),
            ),
    );
  }
}
