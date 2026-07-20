String? validateRequiredFullName(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'Enter your full name.';
  }
  return null;
}

String? validateRequiredEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) {
    return 'Enter your email.';
  }
  if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateRequiredPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter your password.';
  }
  return null;
}

String? validateRegistrationPassword(String? value) {
  if ((value ?? '').length < 6) {
    return 'Use at least 6 characters.';
  }
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value != password) {
    return 'Passwords do not match.';
  }
  return null;
}
