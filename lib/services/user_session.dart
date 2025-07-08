class UserSession {
  static String currentRole = 'Admin'; // Default or initial

  static void setRole(String role) {
    currentRole = role;
  }

  static void toggleRole() {
    if (currentRole.toLowerCase() == 'admin') {
      currentRole = 'Leader';
    } else {
      currentRole = 'Admin';
    }
  }
}
