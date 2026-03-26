class InputValidationService {
  InputValidationService._();

  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (email.length > 254) return 'Email is too long';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 10) return 'Password must be at least 10 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include a number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must include a special character';
    }
    return null;
  }
}
