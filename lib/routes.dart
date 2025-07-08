import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/member_overview_screen.dart';
import 'screens/leader_dashboard_screen.dart';
import 'screens/schedule.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_login_screen.dart';
import 'screens/complete_profile_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashLoginScreen(),
  '/login': (context) => const LoginScreen(),
  '/signup': (context) => const SignupScreen(),
  '/complete-profile': (context) => const CompleteProfileScreen(),
  '/leader': (context) => const LeaderDashboardScreen(),
  '/admin': (context) => const AdminScreen(),
  '/members': (context) => const MemberDashboardScreen(),
  '/schedule': (context) => const ScheduleScreen(),
};
