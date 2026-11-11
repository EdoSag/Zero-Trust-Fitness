import 'package:zerotrust_fitness/l10n/l10n.dart';
String friendlyErrorMessage(Object error) {
  final msg = error.toString();
  if (msg.contains('SocketException') ||
      msg.contains('NetworkException') ||
      msg.contains('Failed host lookup') ||
      msg.contains('Connection refused')) {
    return currentL10n.noInternetConnectionCheckYour;
  }
  if (msg.contains('AuthException') ||
      msg.contains('Invalid login credentials') ||
      msg.contains('invalid_grant')) {
    return currentL10n.signInFailedCheckYour;
  }
  if (msg.contains('401') || msg.contains('403')) {
    return currentL10n.accessDeniedPleaseSignIn;
  }
  if (msg.contains('PostgrestException') || msg.contains('500')) {
    return currentL10n.serverErrorPleaseTryAgain;
  }
  if (msg.contains('Cloud payload format is invalid')) {
    return currentL10n.cloudBackupIsUnreadableIt;
  }
  if (msg.contains('SQLCipher') ||
      msg.contains('Refusing to open local vault')) {
    return currentL10n.vaultCouldNotBeOpened;
  }
  if (msg.contains('Location permission not granted')) {
    return currentL10n.locationPermissionRequiredForGps;
  }
  if (msg.contains('TimeoutException') || msg.contains('timed out')) {
    return currentL10n.requestTimedOutCheckYour;
  }
  return currentL10n.somethingWentWrongPleaseTry;
}
