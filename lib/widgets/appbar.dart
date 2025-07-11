import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scheduler_app/services/user_session.dart';
import 'package:provider/provider.dart';
import 'package:scheduler_app/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChurchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String name;
  final List<String> roles;
  final String currentRole;

  const ChurchAppBar({
    super.key,
    required this.name,
    required this.roles,
    required this.currentRole,
  });

  @override
  State<ChurchAppBar> createState() => _ChurchAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class DefaultRoleService {
  static const _key = 'default_role';

  static Future<void> setDefaultRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.toLowerCase());
  }

  static Future<String?> getDefaultRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clearDefaultRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class _ChurchAppBarState extends State<ChurchAppBar>
    with SingleTickerProviderStateMixin {
  bool isMenuOpen = false;
  final GlobalKey _settingskey = GlobalKey();
  bool get isAdmin =>
      widget.roles.map((e) => e.toLowerCase()).contains('admin');

  bool get isLeader =>
      widget.roles.map((e) => e.toLowerCase()).contains('leader');

  @override
  void didUpdateWidget(covariant ChurchAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roles != widget.roles ||
        oldWidget.currentRole != widget.currentRole ||
        oldWidget.name != widget.name) {
      setState(() {});
    }
  }

  String _getFirstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  void _showDefaultRoleDialog(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Default Role'),
          content: const Text('Select the role you want to open by default.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop('admin');
              },
              child: const Text('Admin'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop('leader');
              },
              child: const Text('Leader'),
            ),
          ],
        );
      },
    );

    if (choice != null) {
      await DefaultRoleService.setDefaultRole(choice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default role set to $choice')),
        );
      }
    }
  }

  Future<void> _toggleTheme(
      BuildContext context, ThemeProvider themeProvider) async {
    final current = themeProvider.themeMode;
    ThemeMode newMode;

    if (current == ThemeMode.dark) {
      newMode = ThemeMode.light;
    } else {
      newMode = ThemeMode.dark;
    }

    await themeProvider.setThemeMode(newMode);

    if (mounted) {
      final themeName =
          newMode.name[0].toUpperCase() + newMode.name.substring(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to $themeName Theme')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Convert roles to lowercase for easy matching
    final rolesLower = widget.roles.map((e) => e.toLowerCase()).toList();
    final currentRoleLower = UserSession.currentRole.toLowerCase();

    final isAdmin = rolesLower.contains('admin');
    final isLeader = rolesLower.contains('leader');

    // Determine if role-switching option is shown
    bool showSwitchOption = false;
    String? switchLabel;
    String? switchRoute;

    if (isAdmin && isLeader) {
      if (currentRoleLower == 'admin') {
        showSwitchOption = true;
        switchLabel = 'Go to Leader';
        switchRoute = '/leader';
      } else if (currentRoleLower == 'leader') {
        showSwitchOption = true;
        switchLabel = 'Go to Admin';
        switchRoute = '/admin';
      }
    }

    return SafeArea(
      child: Container(
        height: widget.preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: theme.appBarTheme.backgroundColor ?? colorScheme.primary,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/WCC-Responsive-White.png',
                  height: 42, // Tint logo automatically
                ),
                const SizedBox(width: 10),
                Text(
                  'Welcome ${_getFirstName(widget.name)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            _buildSettingsIcon(
              context,
              showSwitchOption,
              switchLabel,
              switchRoute,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsIcon(
    BuildContext context,
    bool showSwitchOption,
    String? switchLabel,
    String? switchRoute,
  ) {
    return GestureDetector(
      key: _settingskey,
      onTap: () async {
        setState(() {
          isMenuOpen = true;
        });

        await Future.delayed(const Duration(milliseconds: 300));

        final RenderBox button =
            _settingskey.currentContext!.findRenderObject() as RenderBox;
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final Offset offset =
            button.localToGlobal(Offset.zero, ancestor: overlay);
        final Size buttonSize = button.size;
        final Size overlaySize = overlay.size;

        final RelativeRect position = RelativeRect.fromLTRB(
          offset.dx,
          offset.dy + buttonSize.height,
          overlaySize.width - (offset.dx + buttonSize.width),
          overlaySize.height - (offset.dy + buttonSize.height),
        );

        final selected = await showMenu<int>(
          context: context,
          position: position,
          color: const Color(0xFF2A2A3D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          items: _buildMenuItems(context, showSwitchOption, switchLabel),
        );

        await _handleMenuSelection(context, selected, switchRoute);

        setState(() {
          isMenuOpen = false;
        });
      },
      child: AnimatedRotation(
        turns: isMenuOpen ? 0.25 : 0,
        duration: const Duration(milliseconds: 300),
        child: const Icon(Icons.settings, color: Colors.white),
      ),
    );
  }

  List<PopupMenuEntry<int>> _buildMenuItems(
    BuildContext context,
    bool showSwitchOption,
    String? switchLabel,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentMode = themeProvider.themeMode;

    String themeLabel;
    Icon themeIcon;
    if (currentMode == ThemeMode.dark) {
      themeLabel = 'Switch to Light Theme';
      themeIcon = const Icon(Icons.light_mode, color: Colors.white);
    } else {
      themeLabel = 'Switch to Dark Theme';
      themeIcon = const Icon(Icons.dark_mode, color: Colors.white);
    }

    return [
      const PopupMenuItem(
        value: 1,
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.white),
            SizedBox(width: 8),
            Text('Update Profile', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      if (showSwitchOption && switchLabel != null)
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.white),
              const SizedBox(width: 8),
              Text(switchLabel, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      PopupMenuItem(
        value: 4,
        child: Row(
          children: [
            themeIcon,
            const SizedBox(width: 8),
            Text(themeLabel, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 3,
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      if (isAdmin && isLeader) const PopupMenuDivider(),
      if (isAdmin && isLeader)
        const PopupMenuItem(
          value: 5,
          child: Row(
            children: [
              Icon(Icons.star_border, color: Colors.white),
              SizedBox(width: 8),
              Text('Set Default Role', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
    ];
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    int? value,
    String? switchRoute,
  ) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (value == 1) {
      Navigator.pushNamed(
        context,
        '/complete-profile',
        arguments: {
          'from': ModalRoute.of(context)?.settings.name ?? '/members'
        },
      );
    } else if (value == 2 && switchRoute != null) {
      UserSession.toggleRole();
      Navigator.pushReplacementNamed(context, switchRoute);
    } else if (value == 3) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else if (value == 4) {
      await _toggleTheme(context, themeProvider);
    } else if (value == 5) {
      _showDefaultRoleDialog(context);
    }
  }
}
