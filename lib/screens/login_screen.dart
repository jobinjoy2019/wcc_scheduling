import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/appbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _passwordFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;

      if (user != null) {
        // AUTHORIZATION CHECK
        final isAllowed = await _isEmailAllowed(user.email ?? '');
        if (!isAllowed) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _error = 'Access denied: Please contact administrator.';
          });
          return;
        }
        final uid = user.uid;
        // Check if there are any users in the 'users' collection to decide
        // if this is the very first user (who becomes Admin/Leader).
        final usersSnapshot =
            await FirebaseFirestore.instance.collection('users').get();

        if (usersSnapshot.docs.isEmpty) {
          // If no users exist, create the first user with Admin and Leader roles
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': user.displayName ?? '',
            'email': user.email,
            'roles': ['Admin', 'Leader'], // Assign both roles to the first user
            'functions': [],
          });
        }

        // Always fetch the user document after potential write to ensure current roles
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final roles = List<String>.from(doc.data()?['roles'] ?? []);

        if (!mounted) return;
        final rolesLower = roles.map((r) => r.toLowerCase()).toList();
        final defaultRole =
            (await DefaultRoleService.getDefaultRole())?.toLowerCase();

        if (user.displayName == null || user.displayName!.isEmpty) {
          Navigator.pushReplacementNamed(context, '/complete-profile');
        } else if (defaultRole != null && rolesLower.contains(defaultRole)) {
          // Respect the user’s saved default role
          if (defaultRole == 'admin') {
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (defaultRole == 'leader') {
            Navigator.pushReplacementNamed(context, '/leader');
          } else {
            Navigator.pushReplacementNamed(context, '/members');
          }
        } else if (rolesLower.contains('admin')) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (rolesLower.contains('leader')) {
          Navigator.pushReplacementNamed(context, '/leader');
        } else {
          Navigator.pushReplacementNamed(context, '/members');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _tryLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      _signIn();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false); // User cancelled the sign-in
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (!mounted) return;
      final user = userCredential.user;
      if (user == null || user.email == null) {
        setState(() {
          _error = 'Google Sign-In failed: No email found.';
        });
        return;
      }

      // AUTHORIZATION CHECK
      final isAllowed = await _isEmailAllowed(user.email!);
      if (!isAllowed) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 'Access denied: You are not authorized to use this app.';
        });
        return;
      }

      if (isNewUser) {
        // For new Google users, navigate to profile completion
        Navigator.pushReplacementNamed(context, '/complete_profile');
      } else {
        // For existing Google users, fetch roles and navigate
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final roles = List<String>.from(doc.data()?['roles'] ?? []);

          if (roles.contains('Admin')) {
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (roles.contains('Leader')) {
            Navigator.pushReplacementNamed(context, '/leader');
          } else {
            Navigator.pushReplacementNamed(context, '/members');
          }
        } else {
          // Handle case where UID is null after Google sign-in (shouldn't happen often)
          setState(() {
            _error = 'Could not retrieve user ID after Google sign-in.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Google Sign-In failed: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _isEmailAllowed(String email) async {
    final doc = await FirebaseFirestore.instance
        .collection('allowedEmails')
        .doc(email)
        .get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Keep mainAxisSize.min
            children: [
              const Text(
                'Worship Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocus);
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Email is required' : null,
              ),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _tryLogin(),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Password is required'
                    : null,
              ),
              const SizedBox(height: 16),
              // Error message display
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFEC7440)),
                    textAlign: TextAlign.center,
                    softWrap: true, // Ensures long error messages wrap
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _tryLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F7CEF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        8), // <-- rectangle with rounded corners
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),
              const SizedBox(height: 10), // Space between buttons

              /// 🔹 Google Sign-In button
              OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.grey),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: Image.asset(
                  'assets/Google_Icons-09-512.webp',
                  height: 20,
                ),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: RichText(
                  text: TextSpan(
                    text: "Don't have an account? ",
                    style: const TextStyle(color: Colors.white70),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: const TextStyle(
                            color: Color(0xFF00AAAA),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
