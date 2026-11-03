String friendlyErrorMessage(Object error) {
  final msg = error.toString();
  if (msg.contains('SocketException') ||
      msg.contains('NetworkException') ||
      msg.contains('Failed host lookup') ||
      msg.contains('Connection refused')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (msg.contains('AuthException') ||
      msg.contains('Invalid login credentials') ||
      msg.contains('invalid_grant')) {
    return 'Sign-in failed. Check your email and password.';
  }
  if (msg.contains('401') || msg.contains('403')) {
    return 'Access denied. Please sign in again.';
  }
  if (msg.contains('PostgrestException') || msg.contains('500')) {
    return 'Server error. Please try again in a moment.';
  }
  if (msg.contains('Cloud payload format is invalid')) {
    return 'Cloud backup is unreadable. It may have been created with a different password.';
  }
  if (msg.contains('SQLCipher') ||
      msg.contains('Refusing to open local vault')) {
    return 'Vault could not be opened. The master password may be incorrect.';
  }
  if (msg.contains('Location permission not granted')) {
    return 'Location permission required for GPS tracking.';
  }
  if (msg.contains('TimeoutException') || msg.contains('timed out')) {
    return 'Request timed out. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
