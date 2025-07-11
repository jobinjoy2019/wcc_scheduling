import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scheduler_app/widgets/appbar.dart';


class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({super.key});

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late Animation<Alignment> _alignmentAnimation;
  late Animation<double> _scaleAnimation;
  // Store the Tween object to access its begin value
  late Tween<double> _scaleTween; // <-- NEW: Store the Tween

  late AnimationController _loginFormController;
  late Animation<Offset> _loginSlideAnimation;

  bool _showLoginForm = false;
  bool _isInitialCentering = true;

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _alignmentAnimation = AlignmentTween(
      begin: Alignment.center,
      end: Alignment.topCenter,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize _scaleTween here
    _scaleTween = Tween<double>(
      begin: 2.0,
      end: 1.0,
    );

    _scaleAnimation = _scaleTween.animate(
      // Use _scaleTween to animate
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loginFormController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _loginSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _loginFormController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimationSequence();
    });
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isInitialCentering = false;
      });
    }

    await _logoAnimationController.forward();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final roles = List<String>.from(doc.data()?['roles'] ?? []);
      final defaultRole =
          (await DefaultRoleService.getDefaultRole())?.toLowerCase();
      final rolesLower = roles.map((e) => e.toLowerCase()).toList();

      if (!mounted) return;

      if (defaultRole != null && rolesLower.contains(defaultRole)) {
        Navigator.pushReplacementNamed(context, '/$defaultRole');
      } else if (rolesLower.contains('admin')) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else if (rolesLower.contains('leader')) {
        Navigator.pushReplacementNamed(context, '/leader');
      } else {
        Navigator.pushReplacementNamed(context, '/members');
      }
    } else {
      if (!mounted) return;
      setState(() {
        _showLoginForm = true;
      });
      _loginFormController.forward();
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _loginFormController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6F7CEF),
              Color(0xFF00AAAA),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: _isInitialCentering
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    flex: _showLoginForm ? 0 : 1,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _showLoginForm &&
                                MediaQuery.of(context).viewInsets.bottom > 0
                            ? 20.0
                            : 0,
                        bottom: _showLoginForm ? 0 : 24,
                      ),
                      child: AnimatedBuilder(
                        animation: _logoAnimationController,
                        builder: (context, child) {
                          return Align(
                            alignment: _isInitialCentering
                                ? Alignment.center
                                : _alignmentAnimation.value,
                            child: Transform.scale(
                              // CORRECTED LINE: Access _scaleTween.begin
                              scale: _isInitialCentering
                                  ? _scaleTween.begin
                                  : _scaleAnimation.value,
                              child: Hero(
                                tag: 'logo',
                                child: Image.asset(
                                  'assets/logos_150px_WCC-Original-White.png',
                                  height: 150,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _showLoginForm
                        ? SlideTransition(
                            position: _loginSlideAnimation,
                            child: const Padding(
                              padding: EdgeInsets.only(
                                left: 24,
                                right: 24,
                                bottom: 24,
                                top: 16,
                              ),
                              child: LoginScreen(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (_showLoginForm)
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
