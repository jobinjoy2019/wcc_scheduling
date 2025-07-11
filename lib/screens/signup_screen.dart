import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstnamecontroller = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<bool> isEmailAllowed(String email) async {
    final emailKey = email.trim().toLowerCase();
    final doc = await FirebaseFirestore.instance
        .collection('allowedEmails')
        .doc(emailKey)
        .get();
    return doc.exists;
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final isAllowed = await isEmailAllowed(email);

      if (!isAllowed) {
        setState(() {
          _error = 'This email is not authorized to sign up.';
          _loading = false;
        });
        return;
      }

      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      await userCredential.user
          ?.updateDisplayName(_firstnamecontroller.text.trim());

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/complete-profile');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Signup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final email = googleUser.email.trim().toLowerCase();
      final isAllowed = await isEmailAllowed(email);

      if (!isAllowed) {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 'This email is not authorized to sign in.';
        });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(googleUser.displayName ?? '');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/complete-profile');
    } catch (e) {
      setState(() => _error = 'Google Sign-In failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final border = UnderlineInputBorder(
      borderSide: BorderSide(color: colorScheme.onSurface.withAlpha(128)),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: const Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _firstnamecontroller,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withAlpha(178)),
                enabledBorder: border,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withAlpha(178)),
                enabledBorder: border,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withAlpha(178)),
                enabledBorder: border,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: _loading
                  ? CircularProgressIndicator(
                      color: colorScheme.onPrimary,
                    )
                  : const Text('Sign Up'),
            ),
            Divider(
              height: 32,
              color: colorScheme.onSurface.withAlpha(128),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outline),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: Image.asset(
                'assets/Google_Icons-09-512.webp',
                height: 20,
              ),
              label: Text(
                'Sign in with Google',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: RichText(
                text: TextSpan(
                  text: "Already have an account? ",
                  style: TextStyle(color: colorScheme.onSurface.withAlpha(178)),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
