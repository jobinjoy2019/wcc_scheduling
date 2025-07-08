import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/services/user_session.dart';
import 'package:scheduler_app/widgets/reusable_schedule_util.dart';
import 'package:scheduler_app/widgets/appbar.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<DocumentSnapshot> users = [];
  bool isLeader = false;
  late String name;
  final user = FirebaseAuth.instance.currentUser;
  List<String> userRoles = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      name = user.displayName ?? 'Team Leader';
    }
    _fetchUsers();
    _checkRoles();
  }

  String getFullName(Map<String, dynamic> user) {
    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'No Name' : full;
  }

  Future<void> _checkRoles() async {
    final uid = user?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final roles = List<String>.from(doc.data()?['roles'] ?? []);

    setState(() {
      userRoles = roles;
    });
  }

  Future<void> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      users = snapshot.docs;
    });
  }

  void _showUserListForUpdate() {
    final sortedUsers = [...users]..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = getFullName(aData).toLowerCase();
        final bName = getFullName(bData).toLowerCase();
        return aName.compareTo(bName);
      });

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select a User to Update'),
        children: sortedUsers.map((userDoc) {
          final user = userDoc.data() as Map<String, dynamic>;
          return SimpleDialogOption(
            child: Text(getFullName(user)),
            onPressed: () {
              Navigator.pop(context);
              _openEditUserDialog(userDoc);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showUserListForDelete() {
    final sortedUsers = [...users]..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = getFullName(aData).toLowerCase();
        final bName = getFullName(bData).toLowerCase();
        return aName.compareTo(bName);
      });

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select a User to Delete'),
        children: sortedUsers.map((userDoc) {
          final user = userDoc.data() as Map<String, dynamic>;
          return SimpleDialogOption(
            child: Text(getFullName(user)),
            onPressed: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Deletion'),
                  content: Text(
                    'Are you sure you want to delete ${getFullName(user)}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userDoc.id)
                    .delete();
                _fetchUsers();
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _openEditUserDialog(DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final firstNameController =
        TextEditingController(text: data['firstName'] ?? '');
    final lastNameController =
        TextEditingController(text: data['lastName'] ?? '');
    final email = data['email'];
    bool isLeader = (data['roles'] ?? []).contains('Leader');
    bool isAdmin = (data['roles'] ?? []).contains('Admin');
    List<String> selectedFunctions = List<String>.from(data['functions'] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3D),
              title: const Text('Update User Profile',
                  style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: $email',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Make Leader',
                          style: TextStyle(color: Colors.white)),
                      value: isLeader,
                      onChanged: (val) => setDialogState(() => isLeader = val),
                    ),
                    SwitchListTile(
                      title: const Text('Make Admin',
                          style: TextStyle(color: Colors.white)),
                      value: isAdmin,
                      onChanged: (val) => setDialogState(() => isAdmin = val),
                    ),
                    const Divider(color: Colors.white24),
                    const Text('Functions:',
                        style: TextStyle(color: Colors.white70)),
                    Wrap(
                      spacing: 8,
                      children: ScheduleUtils.functionOrder.map((f) {
                        final selected = selectedFunctions.contains(f);
                        return FilterChip(
                          label: Text(f),
                          selected: selected,
                          selectedColor: Colors.green,
                          checkmarkColor: Colors.white,
                          labelStyle: const TextStyle(color: Colors.white),
                          onSelected: (isSelected) {
                            setDialogState(() {
                              if (isSelected) {
                                selectedFunctions.add(f);
                              } else {
                                selectedFunctions.remove(f);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        List<String> roles = ['Member'];
                        if (isLeader) roles.add('Leader');
                        if (isAdmin) roles.add('Admin');

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userDoc.id)
                            .update({
                          'firstName': firstNameController.text.trim(),
                          'lastName': lastNameController.text.trim(),
                          'roles': roles,
                          'functions': selectedFunctions,
                        });

                        Navigator.pop(context);
                        _fetchUsers();
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: ChurchAppBar(
          name: name, roles: userRoles, currentRole: UserSession.currentRole),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _showUserListForUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F7CEF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Update User'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC7440),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _showUserListForDelete,
                  child: const Text('Delete User'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('All Users',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  return Card(
                    color: const Color(0xFF2A2A3D),
                    child: ListTile(
                      title: Text(getFullName(user),
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(user['email'] ?? '',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
