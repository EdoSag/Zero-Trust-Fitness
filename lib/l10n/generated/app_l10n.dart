import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @couldntOpenYourFitnessData.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your fitness data on this device.'**
  String get couldntOpenYourFitnessData;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @openingYourFitnessData.
  ///
  /// In en, this message translates to:
  /// **'Opening your fitness data…'**
  String get openingYourFitnessData;

  /// No description provided for @connectYourHealthData.
  ///
  /// In en, this message translates to:
  /// **'Connect your health data?'**
  String get connectYourHealthData;

  /// No description provided for @fitnessCanReadStepsWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Fitness can read steps, workouts, heart rate, sleep and more from Health Connect. It stays encrypted on your phone and in your vault. You can change this any time in Settings.'**
  String get fitnessCanReadStepsWorkouts;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @choosePermissions.
  ///
  /// In en, this message translates to:
  /// **'Choose permissions'**
  String get choosePermissions;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @trends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trends;

  /// No description provided for @journal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journal;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @syncFromHealthConnectOr.
  ///
  /// In en, this message translates to:
  /// **'Sync from Health Connect or log an entry manually.'**
  String get syncFromHealthConnectOr;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionRequired;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get grantPermission;

  /// No description provided for @notTracked.
  ///
  /// In en, this message translates to:
  /// **'Not tracked'**
  String get notTracked;

  /// No description provided for @vaultLocked.
  ///
  /// In en, this message translates to:
  /// **'Vault locked'**
  String get vaultLocked;

  /// No description provided for @unlockYourVaultToSee.
  ///
  /// In en, this message translates to:
  /// **'Unlock your vault to see health data.'**
  String get unlockYourVaultToSee;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noPriorWeekData.
  ///
  /// In en, this message translates to:
  /// **'No prior week data'**
  String get noPriorWeekData;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get dayStreak;

  /// No description provided for @personalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best!'**
  String get personalBest;

  /// No description provided for @stepsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'steps this week'**
  String get stepsThisWeek;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @heartPoints.
  ///
  /// In en, this message translates to:
  /// **'Heart Points'**
  String get heartPoints;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @totalSleep.
  ///
  /// In en, this message translates to:
  /// **'Total Sleep'**
  String get totalSleep;

  /// No description provided for @lightSleep.
  ///
  /// In en, this message translates to:
  /// **'Light Sleep'**
  String get lightSleep;

  /// No description provided for @deepSleep.
  ///
  /// In en, this message translates to:
  /// **'Deep Sleep'**
  String get deepSleep;

  /// No description provided for @remSleep.
  ///
  /// In en, this message translates to:
  /// **'REM Sleep'**
  String get remSleep;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @restingHr.
  ///
  /// In en, this message translates to:
  /// **'Resting HR'**
  String get restingHr;

  /// No description provided for @respiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate'**
  String get respiratoryRate;

  /// No description provided for @bloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood Oxygen'**
  String get bloodOxygen;

  /// No description provided for @bpSystolic.
  ///
  /// In en, this message translates to:
  /// **'BP Systolic'**
  String get bpSystolic;

  /// No description provided for @bpDiastolic.
  ///
  /// In en, this message translates to:
  /// **'BP Diastolic'**
  String get bpDiastolic;

  /// No description provided for @bloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get bloodGlucose;

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get body;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body Fat'**
  String get bodyFat;

  /// No description provided for @lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get lifestyle;

  /// No description provided for @hydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get hydration;

  /// No description provided for @nutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get nutrition;

  /// No description provided for @noTemplatesYetCreateOne.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Create one in Profile → Workout Templates.'**
  String get noTemplatesYetCreateOne;

  /// No description provided for @chooseATemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose a template'**
  String get chooseATemplate;

  /// No description provided for @enterAtLeastOneWorkout.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one workout or metric to log.'**
  String get enterAtLeastOneWorkout;

  /// No description provided for @vaultIsLockedUnlockBefore.
  ///
  /// In en, this message translates to:
  /// **'Vault is locked. Unlock before saving data.'**
  String get vaultIsLockedUnlockBefore;

  /// No description provided for @logHealthData.
  ///
  /// In en, this message translates to:
  /// **'Log Health Data'**
  String get logHealthData;

  /// No description provided for @allDataIsEncryptedBefore.
  ///
  /// In en, this message translates to:
  /// **'All data is encrypted before leaving this device.'**
  String get allDataIsEncryptedBefore;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @healthMetrics.
  ///
  /// In en, this message translates to:
  /// **'Health Metrics'**
  String get healthMetrics;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get useTemplate;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Activity Type'**
  String get activityType;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @vigorous.
  ///
  /// In en, this message translates to:
  /// **'Vigorous'**
  String get vigorous;

  /// No description provided for @lightIntensityNoHeartPoints.
  ///
  /// In en, this message translates to:
  /// **'Light intensity — no heart points'**
  String get lightIntensityNoHeartPoints;

  /// No description provided for @addsToExisting.
  ///
  /// In en, this message translates to:
  /// **'Adds to existing'**
  String get addsToExisting;

  /// No description provided for @replacesExisting.
  ///
  /// In en, this message translates to:
  /// **'Replaces existing'**
  String get replacesExisting;

  /// No description provided for @encryptVaultData.
  ///
  /// In en, this message translates to:
  /// **'Encrypt & Vault Data'**
  String get encryptVaultData;

  /// No description provided for @targetHitTomorrowsTargetGrows.
  ///
  /// In en, this message translates to:
  /// **'Target hit! Tomorrow\'s target grows 5%.'**
  String get targetHitTomorrowsTargetGrows;

  /// No description provided for @momentum.
  ///
  /// In en, this message translates to:
  /// **'Momentum'**
  String get momentum;

  /// No description provided for @howMomentumWorks.
  ///
  /// In en, this message translates to:
  /// **'How Momentum works'**
  String get howMomentumWorks;

  /// No description provided for @todaysTarget.
  ///
  /// In en, this message translates to:
  /// **'Today\'s target'**
  String get todaysTarget;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @howZeroTrustWorks.
  ///
  /// In en, this message translates to:
  /// **'How Zero-Trust Works'**
  String get howZeroTrustWorks;

  /// No description provided for @localFirstStorage.
  ///
  /// In en, this message translates to:
  /// **'Local-first storage'**
  String get localFirstStorage;

  /// No description provided for @allYourHealthDataIs.
  ///
  /// In en, this message translates to:
  /// **'All your health data is encrypted with SQLCipher and stored only on your device. Nothing is uploaded unless you explicitly sync.'**
  String get allYourHealthDataIs;

  /// No description provided for @yourPasswordYourData.
  ///
  /// In en, this message translates to:
  /// **'Your password, your data'**
  String get yourPasswordYourData;

  /// No description provided for @yourMasterPasswordDerivesThe.
  ///
  /// In en, this message translates to:
  /// **'Your master password derives the encryption key on-device using key stretching (PBKDF2). The password and key never leave your device.'**
  String get yourMasterPasswordDerivesThe;

  /// No description provided for @endToEndEncryptedBackups.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted backups'**
  String get endToEndEncryptedBackups;

  /// No description provided for @ifYouChooseToSync.
  ///
  /// In en, this message translates to:
  /// **'If you choose to sync, data is encrypted client-side before uploading. The server stores only an encrypted blob it cannot read.'**
  String get ifYouChooseToSync;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get biometricUnlock;

  /// No description provided for @biometricUnlockStoresOnlyA.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock stores only a reference to your passphrase in the OS secure enclave. Your actual health data is never accessible to the biometrics system.'**
  String get biometricUnlockStoresOnlyA;

  /// No description provided for @optInPermissions.
  ///
  /// In en, this message translates to:
  /// **'Opt-in permissions'**
  String get optInPermissions;

  /// No description provided for @healthConnectAndLocationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Health Connect and location permissions are always opt-in and revocable. You control exactly which metrics are read.'**
  String get healthConnectAndLocationPermissions;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisWeekSoFar.
  ///
  /// In en, this message translates to:
  /// **'This week so far'**
  String get thisWeekSoFar;

  /// No description provided for @vsTheWeekBefore.
  ///
  /// In en, this message translates to:
  /// **'vs the week before'**
  String get vsTheWeekBefore;

  /// No description provided for @activeDays.
  ///
  /// In en, this message translates to:
  /// **'active days'**
  String get activeDays;

  /// No description provided for @timeToMove.
  ///
  /// In en, this message translates to:
  /// **'Time to move!'**
  String get timeToMove;

  /// No description provided for @movementReminders.
  ///
  /// In en, this message translates to:
  /// **'Movement Reminders'**
  String get movementReminders;

  /// No description provided for @stayHydrated.
  ///
  /// In en, this message translates to:
  /// **'Stay hydrated!'**
  String get stayHydrated;

  /// No description provided for @drinkAGlassOfWater.
  ///
  /// In en, this message translates to:
  /// **'Drink a glass of water to keep your hydration on track.'**
  String get drinkAGlassOfWater;

  /// No description provided for @hydrationReminders.
  ///
  /// In en, this message translates to:
  /// **'Hydration Reminders'**
  String get hydrationReminders;

  /// No description provided for @workoutTime.
  ///
  /// In en, this message translates to:
  /// **'Workout time!'**
  String get workoutTime;

  /// No description provided for @workoutReminders.
  ///
  /// In en, this message translates to:
  /// **'Workout Reminders'**
  String get workoutReminders;

  /// No description provided for @bedtimeSoon.
  ///
  /// In en, this message translates to:
  /// **'Bedtime soon'**
  String get bedtimeSoon;

  /// No description provided for @windingDownNowSupportsBetter.
  ///
  /// In en, this message translates to:
  /// **'Winding down now supports better sleep quality.'**
  String get windingDownNowSupportsBetter;

  /// No description provided for @sleepReminders.
  ///
  /// In en, this message translates to:
  /// **'Sleep Reminders'**
  String get sleepReminders;

  /// No description provided for @weeklyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Weekly check-in'**
  String get weeklyCheckIn;

  /// No description provided for @timeToLogYourWeight.
  ///
  /// In en, this message translates to:
  /// **'Time to log your weight or other measurements.'**
  String get timeToLogYourWeight;

  /// No description provided for @measurementReminders.
  ///
  /// In en, this message translates to:
  /// **'Measurement Reminders'**
  String get measurementReminders;

  /// No description provided for @weeklySummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get weeklySummary;

  /// No description provided for @yourWeekOfHeartPoints.
  ///
  /// In en, this message translates to:
  /// **'Your week of Heart Points and steps, Mondays'**
  String get yourWeekOfHeartPoints;

  /// No description provided for @youHaventBeenActiveIn.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t been active in a while. A short walk counts.'**
  String get youHaventBeenActiveIn;

  /// No description provided for @yourScheduledWorkoutIsToday.
  ///
  /// In en, this message translates to:
  /// **'Your scheduled workout is today. Let\'s get moving.'**
  String get yourScheduledWorkoutIsToday;

  /// No description provided for @noInternetConnectionCheckYour.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get noInternetConnectionCheckYour;

  /// No description provided for @signInFailedCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check your email and password.'**
  String get signInFailedCheckYour;

  /// No description provided for @accessDeniedPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Access denied. Please sign in again.'**
  String get accessDeniedPleaseSignIn;

  /// No description provided for @serverErrorPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again in a moment.'**
  String get serverErrorPleaseTryAgain;

  /// No description provided for @cloudBackupIsUnreadableIt.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is unreadable. It may have been created with a different password.'**
  String get cloudBackupIsUnreadableIt;

  /// No description provided for @vaultCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'Vault could not be opened. The master password may be incorrect.'**
  String get vaultCouldNotBeOpened;

  /// No description provided for @locationPermissionRequiredForGps.
  ///
  /// In en, this message translates to:
  /// **'Location permission required for GPS tracking.'**
  String get locationPermissionRequiredForGps;

  /// No description provided for @requestTimedOutCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Check your connection and try again.'**
  String get requestTimedOutCheckYour;

  /// No description provided for @somethingWentWrongPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongPleaseTry;

  /// No description provided for @fitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get fitness;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get keepGoing;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @sleepAsleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep Asleep'**
  String get sleepAsleep;

  /// No description provided for @sleepLight.
  ///
  /// In en, this message translates to:
  /// **'Sleep Light'**
  String get sleepLight;

  /// No description provided for @sleepDeep.
  ///
  /// In en, this message translates to:
  /// **'Sleep Deep'**
  String get sleepDeep;

  /// No description provided for @sleepRem.
  ///
  /// In en, this message translates to:
  /// **'Sleep REM'**
  String get sleepRem;

  /// No description provided for @respiratory.
  ///
  /// In en, this message translates to:
  /// **'Respiratory'**
  String get respiratory;

  /// No description provided for @glucose.
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get glucose;

  /// No description provided for @workoutPaused.
  ///
  /// In en, this message translates to:
  /// **'Workout paused.'**
  String get workoutPaused;

  /// No description provided for @workoutResumed.
  ///
  /// In en, this message translates to:
  /// **'Workout resumed.'**
  String get workoutResumed;

  /// No description provided for @gpsWorkout.
  ///
  /// In en, this message translates to:
  /// **'GPS workout'**
  String get gpsWorkout;

  /// No description provided for @timeDistanceAndControlsWhile.
  ///
  /// In en, this message translates to:
  /// **'Time, distance and controls while recording'**
  String get timeDistanceAndControlsWhile;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @unstoppable.
  ///
  /// In en, this message translates to:
  /// **'Unstoppable'**
  String get unstoppable;

  /// No description provided for @steady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get steady;

  /// No description provided for @building.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get building;

  /// No description provided for @gettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get gettingStarted;

  /// No description provided for @bringingOverYourDataFrom.
  ///
  /// In en, this message translates to:
  /// **'Bringing over your data from the previous version…'**
  String get bringingOverYourDataFrom;

  /// No description provided for @yourDataFromThePrevious.
  ///
  /// In en, this message translates to:
  /// **'Your data from the previous version hasn\'t been brought over yet: the server couldn\'t be reached. Check your connection and try again.'**
  String get yourDataFromThePrevious;

  /// No description provided for @thatPasswordDidntOpenYour.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t open your data from the previous version either. Try another password you used before, or skip it.'**
  String get thatPasswordDidntOpenYour;

  /// No description provided for @yourDataFromThePreviousX.
  ///
  /// In en, this message translates to:
  /// **'Your data from the previous version is locked with the password you used before this update. Enter it once to bring it over.'**
  String get yourDataFromThePreviousX;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @yourDataFromThePreviousXX.
  ///
  /// In en, this message translates to:
  /// **'Your data from the previous version hasn\'t been brought over yet. Something went wrong; try again.'**
  String get yourDataFromThePreviousXX;

  /// No description provided for @skipTheLockedData.
  ///
  /// In en, this message translates to:
  /// **'Skip the locked data?'**
  String get skipTheLockedData;

  /// No description provided for @whateverNoPasswordOpenedStays.
  ///
  /// In en, this message translates to:
  /// **'Whatever no password opened stays where it is (the old file is kept on this phone) but won\'t show in the app. Everything else from the previous version is brought over.'**
  String get whateverNoPasswordOpenedStays;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yourDataFromThePreviousXXX.
  ///
  /// In en, this message translates to:
  /// **'Your data from the previous version is here.'**
  String get yourDataFromThePreviousXXX;

  /// No description provided for @stillCouldntReachTheServer.
  ///
  /// In en, this message translates to:
  /// **'Still couldn\'t reach the server. Check your connection.'**
  String get stillCouldntReachTheServer;

  /// No description provided for @thatPasswordDidntOpenIt.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t open it. Try another one you used before.'**
  String get thatPasswordDidntOpenIt;

  /// No description provided for @thatDidntWorkTryAgain.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again in a moment.'**
  String get thatDidntWorkTryAgain;

  /// No description provided for @passwordFromBeforeTheUpdate.
  ///
  /// In en, this message translates to:
  /// **'Password from before the update'**
  String get passwordFromBeforeTheUpdate;

  /// No description provided for @thePasswordZeroTrustFitness.
  ///
  /// In en, this message translates to:
  /// **'The password Zero-Trust Fitness used before this update. It only unlocks your old data on this phone; it isn\'t sent anywhere and doesn\'t change your account.'**
  String get thePasswordZeroTrustFitness;

  /// No description provided for @oldPassword.
  ///
  /// In en, this message translates to:
  /// **'Old password'**
  String get oldPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @sameAsLastWeek.
  ///
  /// In en, this message translates to:
  /// **' (same as last week)'**
  String get sameAsLastWeek;

  /// No description provided for @yourWeekInFitness.
  ///
  /// In en, this message translates to:
  /// **'Your week in Fitness'**
  String get yourWeekInFitness;

  /// No description provided for @noActivityLoggedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No activity logged this week. A short walk is a good start.'**
  String get noActivityLoggedThisWeek;

  /// No description provided for @allMetrics.
  ///
  /// In en, this message translates to:
  /// **'All Metrics'**
  String get allMetrics;

  /// No description provided for @logAWorkoutOrHealth.
  ///
  /// In en, this message translates to:
  /// **'Log a workout or health metric'**
  String get logAWorkoutOrHealth;

  /// No description provided for @couldNotReadSelectedFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected file.'**
  String get couldNotReadSelectedFile;

  /// No description provided for @failedToReadFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file.'**
  String get failedToReadFile;

  /// No description provided for @invalidOrUnsupportedExportFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid or unsupported export file (version too new?).'**
  String get invalidOrUnsupportedExportFile;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup?'**
  String get restoreFromBackup;

  /// No description provided for @workoutsMissingHereAreAdded.
  ///
  /// In en, this message translates to:
  /// **'Workouts missing here are added, days in the file replace the same days here, and goals are set. It syncs to your other devices.'**
  String get workoutsMissingHereAreAdded;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exported;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @metricDays.
  ///
  /// In en, this message translates to:
  /// **'Metric days'**
  String get metricDays;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @exportRestore.
  ///
  /// In en, this message translates to:
  /// **'Export & Restore'**
  String get exportRestore;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @exportFullBackupJson.
  ///
  /// In en, this message translates to:
  /// **'Export full backup (JSON)'**
  String get exportFullBackupJson;

  /// No description provided for @allWorkoutsMetricsGoalsAnd.
  ///
  /// In en, this message translates to:
  /// **'All workouts, metrics, goals and medals. Not encrypted: keep it safe.'**
  String get allWorkoutsMetricsGoalsAnd;

  /// No description provided for @exportMetricsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export metrics (CSV)'**
  String get exportMetricsCsv;

  /// No description provided for @dailyHealthMetricsAsA.
  ///
  /// In en, this message translates to:
  /// **'Daily health metrics as a spreadsheet, for analysis'**
  String get dailyHealthMetricsAsA;

  /// No description provided for @restoreFromJson.
  ///
  /// In en, this message translates to:
  /// **'Restore from JSON'**
  String get restoreFromJson;

  /// No description provided for @bringAFullBackupBack.
  ///
  /// In en, this message translates to:
  /// **'Bring a full backup back in. Nothing here is deleted.'**
  String get bringAFullBackupBack;

  /// No description provided for @yourDataIsSyncedEnd.
  ///
  /// In en, this message translates to:
  /// **'Your data is synced, end-to-end encrypted, to your other devices as you go. To be able to get back in if you forget your password, keep your recovery key safe (Settings → New recovery key).'**
  String get yourDataIsSyncedEnd;

  /// No description provided for @enterAValidTargetValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid target value.'**
  String get enterAValidTargetValue;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noGoogleFitDataFound.
  ///
  /// In en, this message translates to:
  /// **'No Google Fit data found in that file. Choose the Takeout .zip, or the \"Daily activity metrics.csv\" file from its Fit folder.'**
  String get noGoogleFitDataFound;

  /// No description provided for @importFromGoogleFit.
  ///
  /// In en, this message translates to:
  /// **'Import from Google Fit'**
  String get importFromGoogleFit;

  /// No description provided for @bringYourGoogleFitHistory.
  ///
  /// In en, this message translates to:
  /// **'Bring your Google Fit history with you'**
  String get bringYourGoogleFitHistory;

  /// No description provided for @s1GoToTakeoutGoogle.
  ///
  /// In en, this message translates to:
  /// **'1. Go to takeout.google.com and choose only \"Fit\".\n2. Download the .zip Google emails you.\n3. Choose it here (or the \"Daily activity metrics.csv\" inside).'**
  String get s1GoToTakeoutGoogle;

  /// No description provided for @theFileIsReadOn.
  ///
  /// In en, this message translates to:
  /// **'The file is read on this phone. Your steps, Heart Points, weight and workouts are added to your encrypted vault, and days already counted aren\'t counted twice. Importing again adds nothing new.'**
  String get theFileIsReadOn;

  /// No description provided for @addingToYourVault.
  ///
  /// In en, this message translates to:
  /// **'Adding to your vault…'**
  String get addingToYourVault;

  /// No description provided for @readingTheExport.
  ///
  /// In en, this message translates to:
  /// **'Reading the export…'**
  String get readingTheExport;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @found.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get found;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @chooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFile;

  /// No description provided for @chooseTakeoutFile.
  ///
  /// In en, this message translates to:
  /// **'Choose Takeout file'**
  String get chooseTakeoutFile;

  /// No description provided for @fitnessNeedsLocationAccessTo.
  ///
  /// In en, this message translates to:
  /// **'Fitness needs location access to record a GPS workout. You can allow it in your phone\'s settings.'**
  String get fitnessNeedsLocationAccessTo;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout?'**
  String get finishWorkout;

  /// No description provided for @discardWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard workout?'**
  String get discardWorkout;

  /// No description provided for @itsSavedToYourJournal.
  ///
  /// In en, this message translates to:
  /// **'It\'s saved to your journal.'**
  String get itsSavedToYourJournal;

  /// No description provided for @thisWorkoutWontBeSaved.
  ///
  /// In en, this message translates to:
  /// **'This workout won\'t be saved.'**
  String get thisWorkoutWontBeSaved;

  /// No description provided for @keepGoingX.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoingX;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @vaultLockedWorkoutNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Vault locked, workout not saved.'**
  String get vaultLockedWorkoutNotSaved;

  /// No description provided for @voiceCuesOn.
  ///
  /// In en, this message translates to:
  /// **'Voice cues on'**
  String get voiceCuesOn;

  /// No description provided for @voiceCuesOff.
  ///
  /// In en, this message translates to:
  /// **'Voice cues off'**
  String get voiceCuesOff;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @autoPause.
  ///
  /// In en, this message translates to:
  /// **'Auto-pause'**
  String get autoPause;

  /// No description provided for @discardWorkoutX.
  ///
  /// In en, this message translates to:
  /// **'Discard workout'**
  String get discardWorkoutX;

  /// No description provided for @stopsTheClockWhenYou.
  ///
  /// In en, this message translates to:
  /// **'Stops the clock when you stop moving'**
  String get stopsTheClockWhenYou;

  /// No description provided for @voiceCues.
  ///
  /// In en, this message translates to:
  /// **'Voice cues'**
  String get voiceCues;

  /// No description provided for @yourRouteStaysEncryptedIn.
  ///
  /// In en, this message translates to:
  /// **'Your route stays encrypted in your vault. While you record, a notification shows time and distance, with Pause and Lap buttons on the lock screen.'**
  String get yourRouteStaysEncryptedIn;

  /// No description provided for @findingGps.
  ///
  /// In en, this message translates to:
  /// **'Finding GPS…'**
  String get findingGps;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @autoPaused.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PAUSED'**
  String get autoPaused;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get paused;

  /// No description provided for @avgPace.
  ///
  /// In en, this message translates to:
  /// **'avg pace'**
  String get avgPace;

  /// No description provided for @waitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS…'**
  String get waitingForGps;

  /// No description provided for @noTracksWithAtLeast.
  ///
  /// In en, this message translates to:
  /// **'No tracks with at least two points in that file.'**
  String get noTracksWithAtLeast;

  /// No description provided for @enterHowLongEachWorkout.
  ///
  /// In en, this message translates to:
  /// **'Enter how long each workout took.'**
  String get enterHowLongEachWorkout;

  /// No description provided for @importGpxRoutes.
  ///
  /// In en, this message translates to:
  /// **'Import GPX routes'**
  String get importGpxRoutes;

  /// No description provided for @bringInWorkoutsFromStrava.
  ///
  /// In en, this message translates to:
  /// **'Bring in workouts from Strava, Komoot, Garmin or any app that exports .gpx files. The file is read on this phone and saved encrypted, like everything else.'**
  String get bringInWorkoutsFromStrava;

  /// No description provided for @chooseGpxFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose GPX files'**
  String get chooseGpxFiles;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'already imported'**
  String get alreadyImported;

  /// No description provided for @thisFileHasNoTimes.
  ///
  /// In en, this message translates to:
  /// **'This file has no times. When was it, and how long did it take?'**
  String get thisFileHasNoTimes;

  /// No description provided for @countHeartPoints.
  ///
  /// In en, this message translates to:
  /// **'Count Heart Points'**
  String get countHeartPoints;

  /// No description provided for @turnOffIfTheseWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Turn off if these workouts are already in your health app, so they don\'t count twice'**
  String get turnOffIfTheseWorkouts;

  /// No description provided for @yourDataYourKeysYour.
  ///
  /// In en, this message translates to:
  /// **'Your data, your keys, your privacy. Track activity, workouts and health, encrypted on your phone before anything is synced.'**
  String get yourDataYourKeysYour;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @learnMoreAboutZeroTrust.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Zero-Trust'**
  String get learnMoreAboutZeroTrust;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get unknownDate;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @nothingLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get nothingLoggedYet;

  /// No description provided for @workoutsAndMeasurementsYouLog.
  ///
  /// In en, this message translates to:
  /// **'Workouts and measurements you log, record or import show up here.'**
  String get workoutsAndMeasurementsYouLog;

  /// No description provided for @logAWorkoutOrMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Log a workout or measurement'**
  String get logAWorkoutOrMeasurement;

  /// No description provided for @searchTheJournal.
  ///
  /// In en, this message translates to:
  /// **'Search the journal…'**
  String get searchTheJournal;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @measurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @thisDeletesItOnAll.
  ///
  /// In en, this message translates to:
  /// **'This deletes it on all your devices.'**
  String get thisDeletesItOnAll;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @avgPaceX.
  ///
  /// In en, this message translates to:
  /// **'Avg pace'**
  String get avgPaceX;

  /// No description provided for @splits.
  ///
  /// In en, this message translates to:
  /// **'Splits'**
  String get splits;

  /// No description provided for @laps.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get laps;

  /// No description provided for @exportRouteGpx.
  ///
  /// In en, this message translates to:
  /// **'Export route (GPX)'**
  String get exportRouteGpx;

  /// No description provided for @valuesFromHealthConnectFor.
  ///
  /// In en, this message translates to:
  /// **'Values from Health Connect for that day stay.'**
  String get valuesFromHealthConnectFor;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get last7Days;

  /// No description provided for @s7DayAverage.
  ///
  /// In en, this message translates to:
  /// **'7-day average'**
  String get s7DayAverage;

  /// No description provided for @s30DayAverage.
  ///
  /// In en, this message translates to:
  /// **'30-day average'**
  String get s30DayAverage;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @setGoal.
  ///
  /// In en, this message translates to:
  /// **'Set goal'**
  String get setGoal;

  /// No description provided for @sourceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Source Breakdown'**
  String get sourceBreakdown;

  /// No description provided for @manualEntries.
  ///
  /// In en, this message translates to:
  /// **'Manual entries'**
  String get manualEntries;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get last30Days;

  /// No description provided for @yourRoutesMapsWereAlready.
  ///
  /// In en, this message translates to:
  /// **'Your routes\' maps were already on this phone.'**
  String get yourRoutesMapsWereAlready;

  /// No description provided for @offlineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline maps'**
  String get offlineMaps;

  /// No description provided for @routeMapsComeFromOpenstreetmap.
  ///
  /// In en, this message translates to:
  /// **'Route maps come from OpenStreetMap. Each map tile is kept on this phone the first time it is shown, so the map server is asked once at most, not every time you open a workout.'**
  String get routeMapsComeFromOpenstreetmap;

  /// No description provided for @offlineMapsOnly.
  ///
  /// In en, this message translates to:
  /// **'Offline maps only'**
  String get offlineMapsOnly;

  /// No description provided for @neverContactTheMapServer.
  ///
  /// In en, this message translates to:
  /// **'Never contact the map server. Areas you haven\'t saved show the route on a blank background.'**
  String get neverContactTheMapServer;

  /// No description provided for @saveMapsOfMyRoutes.
  ///
  /// In en, this message translates to:
  /// **'Save maps of my routes'**
  String get saveMapsOfMyRoutes;

  /// No description provided for @noGpsRoutesYet.
  ///
  /// In en, this message translates to:
  /// **'No GPS routes yet'**
  String get noGpsRoutesYet;

  /// No description provided for @deleteSavedMaps.
  ///
  /// In en, this message translates to:
  /// **'Delete saved maps'**
  String get deleteSavedMaps;

  /// No description provided for @readDailyStepCounts.
  ///
  /// In en, this message translates to:
  /// **'Read daily step counts.'**
  String get readDailyStepCounts;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @readHeartRateSamples.
  ///
  /// In en, this message translates to:
  /// **'Read heart-rate samples.'**
  String get readHeartRateSamples;

  /// No description provided for @exerciseSessions.
  ///
  /// In en, this message translates to:
  /// **'Exercise Sessions'**
  String get exerciseSessions;

  /// No description provided for @readWorkoutsAndActiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'Read workouts and active minutes.'**
  String get readWorkoutsAndActiveMinutes;

  /// No description provided for @readSleepAsleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Read sleep-asleep duration.'**
  String get readSleepAsleepDuration;

  /// No description provided for @readLightSleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Read light sleep duration.'**
  String get readLightSleepDuration;

  /// No description provided for @readDeepSleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Read deep sleep duration.'**
  String get readDeepSleepDuration;

  /// No description provided for @readRemSleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Read REM sleep duration.'**
  String get readRemSleepDuration;

  /// No description provided for @restingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Resting Heart Rate'**
  String get restingHeartRate;

  /// No description provided for @readRestingBpm.
  ///
  /// In en, this message translates to:
  /// **'Read resting BPM.'**
  String get readRestingBpm;

  /// No description provided for @readRespirationsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'Read respirations per minute.'**
  String get readRespirationsPerMinute;

  /// No description provided for @readOxygenSaturationSpo2.
  ///
  /// In en, this message translates to:
  /// **'Read oxygen saturation (SpO2).'**
  String get readOxygenSaturationSpo2;

  /// No description provided for @readBodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Read body weight.'**
  String get readBodyWeight;

  /// No description provided for @bodyMassIndex.
  ///
  /// In en, this message translates to:
  /// **'Body Mass Index'**
  String get bodyMassIndex;

  /// No description provided for @readBmiValues.
  ///
  /// In en, this message translates to:
  /// **'Read BMI values.'**
  String get readBmiValues;

  /// No description provided for @bodyFatX.
  ///
  /// In en, this message translates to:
  /// **'Body Fat %'**
  String get bodyFatX;

  /// No description provided for @readBodyFatPercentage.
  ///
  /// In en, this message translates to:
  /// **'Read body fat percentage.'**
  String get readBodyFatPercentage;

  /// No description provided for @readWaterIntake.
  ///
  /// In en, this message translates to:
  /// **'Read water intake.'**
  String get readWaterIntake;

  /// No description provided for @readNutritionEntries.
  ///
  /// In en, this message translates to:
  /// **'Read nutrition entries.'**
  String get readNutritionEntries;

  /// No description provided for @bloodPressureSystolic.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure Systolic'**
  String get bloodPressureSystolic;

  /// No description provided for @readSystolicBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Read systolic blood pressure.'**
  String get readSystolicBloodPressure;

  /// No description provided for @bloodPressureDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure Diastolic'**
  String get bloodPressureDiastolic;

  /// No description provided for @readDiastolicBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Read diastolic blood pressure.'**
  String get readDiastolicBloodPressure;

  /// No description provided for @readBloodGlucoseSamples.
  ///
  /// In en, this message translates to:
  /// **'Read blood glucose samples.'**
  String get readBloodGlucoseSamples;

  /// No description provided for @permissionsCenter.
  ///
  /// In en, this message translates to:
  /// **'Permissions Center'**
  String get permissionsCenter;

  /// No description provided for @refreshPermissionStates.
  ///
  /// In en, this message translates to:
  /// **'Refresh permission states'**
  String get refreshPermissionStates;

  /// No description provided for @controlEachPermissionDirectlyFrom.
  ///
  /// In en, this message translates to:
  /// **'Control each permission directly from here.'**
  String get controlEachPermissionDirectlyFrom;

  /// No description provided for @installHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Install Health Connect'**
  String get installHealthConnect;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @enableRealTimeGpsRun.
  ///
  /// In en, this message translates to:
  /// **'Enable real-time GPS run/cycle tracking.'**
  String get enableRealTimeGpsRun;

  /// No description provided for @backgroundHealthSync.
  ///
  /// In en, this message translates to:
  /// **'Background Health Sync'**
  String get backgroundHealthSync;

  /// No description provided for @allowPeriodicBackgroundHealthData.
  ///
  /// In en, this message translates to:
  /// **'Allow periodic background health data reads.'**
  String get allowPeriodicBackgroundHealthData;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get granted;

  /// No description provided for @denied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get denied;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn On'**
  String get turnOn;

  /// No description provided for @turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get turnOff;

  /// No description provided for @medals.
  ///
  /// In en, this message translates to:
  /// **'Medals'**
  String get medals;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @privacyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Privacy Dashboard'**
  String get privacyDashboard;

  /// No description provided for @everythingIsEncryptedOnThis.
  ///
  /// In en, this message translates to:
  /// **'Everything is encrypted on this phone with a key only your password or recovery key can open. The server, and the developer, see only ciphertext.'**
  String get everythingIsEncryptedOnThis;

  /// No description provided for @storedInYourVault.
  ///
  /// In en, this message translates to:
  /// **'Stored in your vault'**
  String get storedInYourVault;

  /// No description provided for @howYourDataIsProtected.
  ///
  /// In en, this message translates to:
  /// **'How your data is protected'**
  String get howYourDataIsProtected;

  /// No description provided for @encryptionSyncAndWhatThe.
  ///
  /// In en, this message translates to:
  /// **'Encryption, sync and what the server sees'**
  String get encryptionSyncAndWhatThe;

  /// No description provided for @yourDataRights.
  ///
  /// In en, this message translates to:
  /// **'Your Data Rights'**
  String get yourDataRights;

  /// No description provided for @youOwnAllYourData.
  ///
  /// In en, this message translates to:
  /// **'You own all your data. Only your devices can read it.'**
  String get youOwnAllYourData;

  /// No description provided for @exportAFullBackupAt.
  ///
  /// In en, this message translates to:
  /// **'Export a full backup at any time from Export & Restore.'**
  String get exportAFullBackupAt;

  /// No description provided for @deleteActivityDataFromSettings.
  ///
  /// In en, this message translates to:
  /// **'Delete activity data from Settings → Delete activity data.'**
  String get deleteActivityDataFromSettings;

  /// No description provided for @deletingYourAccountRemovesEverything.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes everything from the server.'**
  String get deletingYourAccountRemovesEverything;

  /// No description provided for @notificationPermissionRequiredForReminders.
  ///
  /// In en, this message translates to:
  /// **'Notification permission required for reminders.'**
  String get notificationPermissionRequiredForReminders;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @weeklySummaryX.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get weeklySummaryX;

  /// No description provided for @mondaysAt900Heart.
  ///
  /// In en, this message translates to:
  /// **'Mondays at 9:00: Heart Points, steps and workouts, compared with the week before'**
  String get mondaysAt900Heart;

  /// No description provided for @movementNudge.
  ///
  /// In en, this message translates to:
  /// **'Movement nudge'**
  String get movementNudge;

  /// No description provided for @hourlyReminderToStayActive.
  ///
  /// In en, this message translates to:
  /// **'Hourly reminder to stay active'**
  String get hourlyReminderToStayActive;

  /// No description provided for @hydrationReminder.
  ///
  /// In en, this message translates to:
  /// **'Hydration reminder'**
  String get hydrationReminder;

  /// No description provided for @hourlyPromptToDrinkWater.
  ///
  /// In en, this message translates to:
  /// **'Hourly prompt to drink water'**
  String get hourlyPromptToDrinkWater;

  /// No description provided for @workoutReminder.
  ///
  /// In en, this message translates to:
  /// **'Workout reminder'**
  String get workoutReminder;

  /// No description provided for @chooseDaysAndTime.
  ///
  /// In en, this message translates to:
  /// **'Choose days and time'**
  String get chooseDaysAndTime;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @bedtimeReminder.
  ///
  /// In en, this message translates to:
  /// **'Bedtime reminder'**
  String get bedtimeReminder;

  /// No description provided for @dailyWindDownPrompt.
  ///
  /// In en, this message translates to:
  /// **'Daily wind-down prompt'**
  String get dailyWindDownPrompt;

  /// No description provided for @bedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get bedtime;

  /// No description provided for @bodyMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Body Measurements'**
  String get bodyMeasurements;

  /// No description provided for @weeklyReminderToLogWeight.
  ///
  /// In en, this message translates to:
  /// **'Weekly reminder to log weight or measurements'**
  String get weeklyReminderToLogWeight;

  /// No description provided for @allRemindersAreLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'All reminders are local-only and never leave your device. Your data is locked while Fitness is closed, so the weekly summary is prepared each time you open the app.'**
  String get allRemindersAreLocalOnly;

  /// No description provided for @copyPastWorkoutsToo.
  ///
  /// In en, this message translates to:
  /// **'Copy past workouts too?'**
  String get copyPastWorkoutsToo;

  /// No description provided for @onlyNewOnes.
  ///
  /// In en, this message translates to:
  /// **'Only new ones'**
  String get onlyNewOnes;

  /// No description provided for @copyThem.
  ///
  /// In en, this message translates to:
  /// **'Copy them'**
  String get copyThem;

  /// No description provided for @unitsFormat.
  ///
  /// In en, this message translates to:
  /// **'Units & Format'**
  String get unitsFormat;

  /// No description provided for @metricKmKg.
  ///
  /// In en, this message translates to:
  /// **'Metric (km, kg)'**
  String get metricKmKg;

  /// No description provided for @imperialMiLbs.
  ///
  /// In en, this message translates to:
  /// **'Imperial (mi, lbs)'**
  String get imperialMiLbs;

  /// No description provided for @timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get timeFormat;

  /// No description provided for @s12HourAmPm.
  ///
  /// In en, this message translates to:
  /// **'12-hour (AM/PM)'**
  String get s12HourAmPm;

  /// No description provided for @noMedalsYetKeepMoving.
  ///
  /// In en, this message translates to:
  /// **'No medals yet — keep moving!'**
  String get noMedalsYetKeepMoving;

  /// No description provided for @deleteActivityData.
  ///
  /// In en, this message translates to:
  /// **'Delete activity data?'**
  String get deleteActivityData;

  /// No description provided for @deletesYourWorkoutsDailyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Deletes your workouts, daily metrics and medals on every device signed in to this account. Goals and templates stay. Health Connect data on the phone is not touched. This can\'t be undone.'**
  String get deletesYourWorkoutsDailyMetrics;

  /// No description provided for @activityDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity data deleted.'**
  String get activityDataDeleted;

  /// No description provided for @setDailyAndWeeklyTargets.
  ///
  /// In en, this message translates to:
  /// **'Set daily and weekly targets'**
  String get setDailyAndWeeklyTargets;

  /// No description provided for @weeklySummaryMovementWaterWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary, movement, water, workouts & sleep'**
  String get weeklySummaryMovementWaterWorkouts;

  /// No description provided for @workoutTemplates.
  ///
  /// In en, this message translates to:
  /// **'Workout templates'**
  String get workoutTemplates;

  /// No description provided for @createAndReuseWorkoutRoutines.
  ///
  /// In en, this message translates to:
  /// **'Create and reuse workout routines'**
  String get createAndReuseWorkoutRoutines;

  /// No description provided for @healthPermissions.
  ///
  /// In en, this message translates to:
  /// **'Health permissions'**
  String get healthPermissions;

  /// No description provided for @chooseWhatFitnessMayRead.
  ///
  /// In en, this message translates to:
  /// **'Choose what Fitness may read'**
  String get chooseWhatFitnessMayRead;

  /// No description provided for @saveWorkoutsToAppleHealth.
  ///
  /// In en, this message translates to:
  /// **'Save workouts to Apple Health'**
  String get saveWorkoutsToAppleHealth;

  /// No description provided for @saveWorkoutsToHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Save workouts to Health Connect'**
  String get saveWorkoutsToHealthConnect;

  /// No description provided for @workoutsYouLogOrRecord.
  ///
  /// In en, this message translates to:
  /// **'Workouts you log or record here show up in your other apps'**
  String get workoutsYouLogOrRecord;

  /// No description provided for @showOnWearOsWatch.
  ///
  /// In en, this message translates to:
  /// **'Show on Wear OS watch'**
  String get showOnWearOsWatch;

  /// No description provided for @todaysHeartPointsStepsAnd.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Heart Points, steps and water on your paired watch, and add water from it. Sent only to the watch.'**
  String get todaysHeartPointsStepsAnd;

  /// No description provided for @unitsFormatX.
  ///
  /// In en, this message translates to:
  /// **'Units & format'**
  String get unitsFormatX;

  /// No description provided for @keepRouteMapsOnThis.
  ///
  /// In en, this message translates to:
  /// **'Keep route maps on this phone'**
  String get keepRouteMapsOnThis;

  /// No description provided for @privacyDashboardX.
  ///
  /// In en, this message translates to:
  /// **'Privacy dashboard'**
  String get privacyDashboardX;

  /// No description provided for @whatYourVaultHoldsAnd.
  ///
  /// In en, this message translates to:
  /// **'What your vault holds and how it is protected'**
  String get whatYourVaultHoldsAnd;

  /// No description provided for @exportRestoreX.
  ///
  /// In en, this message translates to:
  /// **'Export & restore'**
  String get exportRestoreX;

  /// No description provided for @backUpToAFile.
  ///
  /// In en, this message translates to:
  /// **'Back up to a file or bring a backup back in'**
  String get backUpToAFile;

  /// No description provided for @yourHistoryFromAGoogle.
  ///
  /// In en, this message translates to:
  /// **'Your history from a Google Takeout export'**
  String get yourHistoryFromAGoogle;

  /// No description provided for @fromStravaKomootGarminAnd.
  ///
  /// In en, this message translates to:
  /// **'From Strava, Komoot, Garmin and others'**
  String get fromStravaKomootGarminAnd;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get shareReport;

  /// No description provided for @aScopedHealthReportTo.
  ///
  /// In en, this message translates to:
  /// **'A scoped health report to share'**
  String get aScopedHealthReportTo;

  /// No description provided for @deleteActivityDataX.
  ///
  /// In en, this message translates to:
  /// **'Delete activity data'**
  String get deleteActivityDataX;

  /// No description provided for @workoutsMetricsAndMedalsOn.
  ///
  /// In en, this message translates to:
  /// **'Workouts, metrics and medals, on every device'**
  String get workoutsMetricsAndMedalsOn;

  /// No description provided for @selectAtLeastOneMetric.
  ///
  /// In en, this message translates to:
  /// **'Select at least one metric.'**
  String get selectAtLeastOneMetric;

  /// No description provided for @shareReportX.
  ///
  /// In en, this message translates to:
  /// **'Share Report'**
  String get shareReportX;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @metricsToInclude.
  ///
  /// In en, this message translates to:
  /// **'Metrics to include'**
  String get metricsToInclude;

  /// No description provided for @theReportIsAPlain.
  ///
  /// In en, this message translates to:
  /// **'The report is a plain-text file — not encrypted. Only share with people you trust. Informational only — not medical advice.'**
  String get theReportIsAPlain;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @generateShare.
  ///
  /// In en, this message translates to:
  /// **'Generate & Share'**
  String get generateShare;

  /// No description provided for @newTemplate.
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get newTemplate;

  /// No description provided for @editTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get editTemplate;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @activityTypeX.
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get activityTypeX;

  /// No description provided for @durationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration (min):'**
  String get durationMin;

  /// No description provided for @intensity110.
  ///
  /// In en, this message translates to:
  /// **'Intensity (1–10):'**
  String get intensity110;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplate;

  /// No description provided for @workoutTemplatesX.
  ///
  /// In en, this message translates to:
  /// **'Workout Templates'**
  String get workoutTemplatesX;

  /// No description provided for @newTemplateX.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplateX;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get noTemplatesYet;

  /// No description provided for @createYourFirstTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create your first template'**
  String get createYourFirstTemplate;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get notSynced;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get syncPending;

  /// No description provided for @vaultUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Vault unlocked'**
  String get vaultUnlocked;

  /// No description provided for @vaultIsUnlockedAndData.
  ///
  /// In en, this message translates to:
  /// **'Vault is unlocked and data is accessible'**
  String get vaultIsUnlockedAndData;

  /// No description provided for @vaultIsLockedTapUnlock.
  ///
  /// In en, this message translates to:
  /// **'Vault is locked — tap Unlock to access data'**
  String get vaultIsLockedTapUnlock;

  /// No description provided for @gpsActive.
  ///
  /// In en, this message translates to:
  /// **'GPS active'**
  String get gpsActive;

  /// No description provided for @gpsTrackingIsActive.
  ///
  /// In en, this message translates to:
  /// **'GPS tracking is active'**
  String get gpsTrackingIsActive;

  /// No description provided for @stepsToday.
  ///
  /// In en, this message translates to:
  /// **'Steps Today'**
  String get stepsToday;

  /// No description provided for @heartToday.
  ///
  /// In en, this message translates to:
  /// **'Heart Today'**
  String get heartToday;

  /// No description provided for @keyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Key Metrics'**
  String get keyMetrics;

  /// No description provided for @moreMetrics.
  ///
  /// In en, this message translates to:
  /// **'More metrics'**
  String get moreMetrics;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @foodEntry.
  ///
  /// In en, this message translates to:
  /// **'Food entry'**
  String get foodEntry;

  /// No description provided for @foodEntries.
  ///
  /// In en, this message translates to:
  /// **'Food entries'**
  String get foodEntries;

  /// No description provided for @gpsWorkoutActive.
  ///
  /// In en, this message translates to:
  /// **'GPS Workout Active'**
  String get gpsWorkoutActive;

  /// No description provided for @startGpsWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start GPS Workout'**
  String get startGpsWorkout;

  /// No description provided for @trackRoutePaceDistance.
  ///
  /// In en, this message translates to:
  /// **'Track route, pace & distance'**
  String get trackRoutePaceDistance;

  /// No description provided for @lockVault.
  ///
  /// In en, this message translates to:
  /// **'Lock vault'**
  String get lockVault;

  /// No description provided for @trendData.
  ///
  /// In en, this message translates to:
  /// **'trend data'**
  String get trendData;

  /// No description provided for @s30DayBaselines.
  ///
  /// In en, this message translates to:
  /// **'30-Day Baselines'**
  String get s30DayBaselines;

  /// No description provided for @sleepSteps.
  ///
  /// In en, this message translates to:
  /// **'Sleep & Steps'**
  String get sleepSteps;

  /// No description provided for @stepsHeartPointsTodayHourly.
  ///
  /// In en, this message translates to:
  /// **'Steps & Heart Points (Today, Hourly)'**
  String get stepsHeartPointsTodayHourly;

  /// No description provided for @stepsHeartPointsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Steps & Heart Points (This Week)'**
  String get stepsHeartPointsThisWeek;

  /// No description provided for @stepsHeartPointsLast30.
  ///
  /// In en, this message translates to:
  /// **'Steps & Heart Points (Last 30 Days)'**
  String get stepsHeartPointsLast30;

  /// No description provided for @selectedMetricWeek.
  ///
  /// In en, this message translates to:
  /// **'Selected Metric (Week)'**
  String get selectedMetricWeek;

  /// No description provided for @selectedMetricMonth.
  ///
  /// In en, this message translates to:
  /// **'Selected Metric (Month)'**
  String get selectedMetricMonth;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @informational.
  ///
  /// In en, this message translates to:
  /// **'Informational'**
  String get informational;

  /// No description provided for @notMedicalAdviceBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Not medical advice · based on your logged data'**
  String get notMedicalAdviceBasedOn;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get snacks;

  /// No description provided for @addWater.
  ///
  /// In en, this message translates to:
  /// **'Add water'**
  String get addWater;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @waterFood.
  ///
  /// In en, this message translates to:
  /// **'Water & food'**
  String get waterFood;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @unlockToLogWaterAnd.
  ///
  /// In en, this message translates to:
  /// **'Unlock to log water and food.'**
  String get unlockToLogWaterAnd;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @last7DaysX.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7DaysX;

  /// No description provided for @logAgain.
  ///
  /// In en, this message translates to:
  /// **'Log again'**
  String get logAgain;

  /// No description provided for @logFood.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get logFood;

  /// No description provided for @nothingLogged.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged'**
  String get nothingLogged;

  /// No description provided for @editFood.
  ///
  /// In en, this message translates to:
  /// **'Edit food'**
  String get editFood;

  /// No description provided for @whatDidYouEat.
  ///
  /// In en, this message translates to:
  /// **'What did you eat?'**
  String get whatDidYouEat;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @caloriesAndMacrosAreOptional.
  ///
  /// In en, this message translates to:
  /// **'Calories and macros are optional.'**
  String get caloriesAndMacrosAreOptional;

  /// No description provided for @actRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get actRunning;

  /// No description provided for @actCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get actCycling;

  /// No description provided for @actSwimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get actSwimming;

  /// No description provided for @actWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get actWalking;

  /// No description provided for @actHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get actHiking;

  /// No description provided for @actStrengthTraining.
  ///
  /// In en, this message translates to:
  /// **'Strength Training'**
  String get actStrengthTraining;

  /// No description provided for @actYogaStretching.
  ///
  /// In en, this message translates to:
  /// **'Yoga/Stretching'**
  String get actYogaStretching;

  /// No description provided for @actOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get actOther;

  /// No description provided for @actStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get actStrength;

  /// No description provided for @actHiit.
  ///
  /// In en, this message translates to:
  /// **'HIIT'**
  String get actHiit;

  /// No description provided for @actYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get actYoga;

  /// No description provided for @srcManual.
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get srcManual;

  /// No description provided for @srcHealth.
  ///
  /// In en, this message translates to:
  /// **'HEALTH'**
  String get srcHealth;

  /// No description provided for @srcGoogleFit.
  ///
  /// In en, this message translates to:
  /// **'GOOGLE FIT'**
  String get srcGoogleFit;

  /// No description provided for @medalUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Medal unlocked: {name}!'**
  String medalUnlocked(String name);

  /// No description provided for @percentOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of goal'**
  String percentOfGoal(int percent);

  /// No description provided for @noMetricData.
  ///
  /// In en, this message translates to:
  /// **'No {metric} data'**
  String noMetricData(String metric);

  /// No description provided for @metricAccessNotGranted.
  ///
  /// In en, this message translates to:
  /// **'{metric} access is not granted. Enable it in Permissions.'**
  String metricAccessNotGranted(String metric);

  /// No description provided for @metricNotSupported.
  ///
  /// In en, this message translates to:
  /// **'{metric} is not supported on this device.'**
  String metricNotSupported(String metric);

  /// No description provided for @vsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'{change} vs last week'**
  String vsLastWeek(String change);

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {count}'**
  String bestStreak(int count);

  /// No description provided for @templateSummary.
  ///
  /// In en, this message translates to:
  /// **'{activity} · {minutes} min · intensity {intensity}/10'**
  String templateSummary(String activity, int minutes, int intensity);

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSave(String error);

  /// No description provided for @heartPointsEarnedPreview.
  ///
  /// In en, this message translates to:
  /// **'≈ {count} heart points earned'**
  String heartPointsEarnedPreview(int count);

  /// No description provided for @morePointsToTarget.
  ///
  /// In en, this message translates to:
  /// **'{count} more Heart Points to hit today\'s target.'**
  String morePointsToTarget(int count);

  /// No description provided for @momentumExplained.
  ///
  /// In en, this message translates to:
  /// **'Your daily target starts at {target} Heart Points (about 150 a week, the WHO activity guideline) and adapts to you: hit it and it grows 5%; fall below half of it and it eases 3%.\n\nMomentum (0-100) is how close you came to your target over the last 7 days, with recent days counting most. Missing a day lowers it a little instead of resetting it, and today can only push it up.\n\nEverything is calculated on this device.'**
  String momentumExplained(int target);

  /// No description provided for @gainedToday.
  ///
  /// In en, this message translates to:
  /// **'+{count} today'**
  String gainedToday(int count);

  /// No description provided for @pointsOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{points} / {target} pts'**
  String pointsOfTarget(int points, int target);

  /// No description provided for @changeUp.
  ///
  /// In en, this message translates to:
  /// **' (up {percent}%)'**
  String changeUp(int percent);

  /// No description provided for @changeDown.
  ///
  /// In en, this message translates to:
  /// **' (down {percent}%)'**
  String changeDown(int percent);

  /// No description provided for @yourWeekActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your week: 1 active day} other{Your week: {count} active days}}'**
  String yourWeekActiveDays(int count);

  /// No description provided for @nHeartPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} Heart Points'**
  String nHeartPoints(String count);

  /// No description provided for @nSteps.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String nSteps(String count);

  /// No description provided for @nWorkouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout} other{{count} workouts}}'**
  String nWorkouts(int count);

  /// No description provided for @throughDay.
  ///
  /// In en, this message translates to:
  /// **' (through {day})'**
  String throughDay(String day);

  /// No description provided for @cueSplitKm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 kilometre} other{{count} kilometres}}. Time {total}. Split {split} per kilometre.'**
  String cueSplitKm(int count, String total, String split);

  /// No description provided for @cueSplitMile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mile} other{{count} miles}}. Time {total}. Split {split} per mile.'**
  String cueSplitMile(int count, String total, String split);

  /// No description provided for @cueLap.
  ///
  /// In en, this message translates to:
  /// **'Lap {index}. {time}.'**
  String cueLap(int index, String time);

  /// No description provided for @spokenHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String spokenHours(int count);

  /// No description provided for @spokenMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String spokenMinutes(int count);

  /// No description provided for @spokenSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String spokenSeconds(int count);

  /// No description provided for @activityAutoPaused.
  ///
  /// In en, this message translates to:
  /// **'{activity} · auto-paused'**
  String activityAutoPaused(String activity);

  /// No description provided for @activityPaused.
  ///
  /// In en, this message translates to:
  /// **'{activity} · paused'**
  String activityPaused(String activity);

  /// No description provided for @unlockedOn.
  ///
  /// In en, this message translates to:
  /// **'Unlocked on {date}'**
  String unlockedOn(String date);

  /// No description provided for @percentToward.
  ///
  /// In en, this message translates to:
  /// **'{percent}% toward {name}'**
  String percentToward(int percent, String name);

  /// No description provided for @restoredSummary.
  ///
  /// In en, this message translates to:
  /// **'Restored {workouts} workouts, {days} days of metrics, {goals} goals.'**
  String restoredSummary(int workouts, int days, int goals);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @goalSavedFor.
  ///
  /// In en, this message translates to:
  /// **'Goal saved for {metric}'**
  String goalSavedFor(String metric);

  /// No description provided for @failedToLoadGoals.
  ///
  /// In en, this message translates to:
  /// **'Failed to load goals: {error}'**
  String failedToLoadGoals(String error);

  /// No description provided for @targetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetLabel;

  /// No description provided for @couldntReadThatFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that file ({error}).'**
  String couldntReadThatFile(String error);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @addedWorkoutsAndDays.
  ///
  /// In en, this message translates to:
  /// **'Added {workouts} workouts and {days} days'**
  String addedWorkoutsAndDays(int workouts, int days);

  /// No description provided for @workoutsAlreadyHere.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts were already here'**
  String workoutsAlreadyHere(int count);

  /// No description provided for @daysOfStepsAndPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} days of steps and Heart Points'**
  String daysOfStepsAndPoints(int count);

  /// No description provided for @dateRangeTo.
  ///
  /// In en, this message translates to:
  /// **' ({from} to {to})'**
  String dateRangeTo(String from, String to);

  /// No description provided for @couldntStart.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start: {error}'**
  String couldntStart(String error);

  /// No description provided for @workoutSavedDistance.
  ///
  /// In en, this message translates to:
  /// **'Workout saved: {distance} in {time}'**
  String workoutSavedDistance(String distance, String time);

  /// No description provided for @cuesEveryKm.
  ///
  /// In en, this message translates to:
  /// **'Time and pace every kilometre'**
  String get cuesEveryKm;

  /// No description provided for @cuesEveryMile.
  ///
  /// In en, this message translates to:
  /// **'Time and pace every mile'**
  String get cuesEveryMile;

  /// No description provided for @lastSplit.
  ///
  /// In en, this message translates to:
  /// **'Last {unit}: {time}'**
  String lastSplit(String unit, String time);

  /// No description provided for @couldntReadAsGpx.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read {files} as GPX.'**
  String couldntReadAsGpx(String files);

  /// No description provided for @skippedNotGpx.
  ///
  /// In en, this message translates to:
  /// **'Skipped {files}: not GPX.'**
  String skippedNotGpx(String files);

  /// No description provided for @importedWorkouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 workout. You\'ll find it in your Journal.} other{Imported {count} workouts. You\'ll find them in your Journal.}}'**
  String importedWorkouts(int count);

  /// No description provided for @nPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} points'**
  String nPoints(int count);

  /// No description provided for @nMin.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String nMin(int count);

  /// No description provided for @importNWorkouts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 workout} other{Import {count} workouts}}'**
  String importNWorkouts(int count);

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\"'**
  String nothingMatches(String query);

  /// No description provided for @nPts.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String nPts(int count);

  /// No description provided for @deleteThisItem.
  ///
  /// In en, this message translates to:
  /// **'Delete this {name}?'**
  String deleteThisItem(String name);

  /// No description provided for @itsPointsComeOff.
  ///
  /// In en, this message translates to:
  /// **'Its {count} Heart Points come off that day too. This deletes it on all your devices.'**
  String itsPointsComeOff(int count);

  /// No description provided for @lapN.
  ///
  /// In en, this message translates to:
  /// **'Lap {index}'**
  String lapN(int index);

  /// No description provided for @deleteThisEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete this {name} entry?'**
  String deleteThisEntry(String name);

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editItem(String name);

  /// No description provided for @goalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Goal ({period})'**
  String goalPeriod(String period);

  /// No description provided for @savedMapTiles.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} map tiles.'**
  String savedMapTiles(int count);

  /// No description provided for @mapTilesCapped.
  ///
  /// In en, this message translates to:
  /// **' That\'s the most at once; run it again later for the rest.'**
  String get mapTilesCapped;

  /// No description provided for @areasAroundRoutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The areas around your route, ready offline} other{The areas around your {count} routes, ready offline}}'**
  String areasAroundRoutes(int count);

  /// No description provided for @tilesAndSize.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles, {size}'**
  String tilesAndSize(int count, String size);

  /// No description provided for @permissionActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Permission action failed: {error}'**
  String permissionActionFailed(String error);

  /// No description provided for @nOfMGranted.
  ///
  /// In en, this message translates to:
  /// **'{granted} / {total} granted'**
  String nOfMGranted(int granted, int total);

  /// No description provided for @healthDidntAllow.
  ///
  /// In en, this message translates to:
  /// **'{health} didn\'t allow Fitness to save workouts.'**
  String healthDidntAllow(String health);

  /// No description provided for @newWorkoutsSavedTo.
  ///
  /// In en, this message translates to:
  /// **'New workouts are saved to {health} from now on. Fitness can also copy the workouts already in your journal.'**
  String newWorkoutsSavedTo(String health);

  /// No description provided for @copiedWorkoutsTo.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} workouts to {health}.'**
  String copiedWorkoutsTo(int count, String health);

  /// No description provided for @viewAllCount.
  ///
  /// In en, this message translates to:
  /// **'View All ({count})'**
  String viewAllCount(int count);

  /// No description provided for @unitMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get unitMetric;

  /// No description provided for @unitImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get unitImperial;

  /// No description provided for @failedError.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedError(String error);

  /// No description provided for @deleteNamedCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteNamedCannotUndo(String name);

  /// No description provided for @addWaterAmount.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} of water'**
  String addWaterAmount(String amount);

  /// No description provided for @restingHrAvg.
  ///
  /// In en, this message translates to:
  /// **'Resting HR avg: {bpm} bpm'**
  String restingHrAvg(String bpm);

  /// No description provided for @dailyStepsAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily steps avg: {steps}'**
  String dailyStepsAvg(String steps);

  /// No description provided for @sleepStepsCorrelation.
  ///
  /// In en, this message translates to:
  /// **'Your sleep duration shows a {strength, select, strong{strong} moderate{moderate} other{weak}} {direction, select, positive{positive} other{negative}} correlation with your daily step count.'**
  String sleepStepsCorrelation(String strength, String direction);

  /// No description provided for @loggedName.
  ///
  /// In en, this message translates to:
  /// **'Logged {name}'**
  String loggedName(String name);

  /// No description provided for @ofGoalAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String ofGoalAmount(String amount);

  /// No description provided for @waterLoggedHereAndHealth.
  ///
  /// In en, this message translates to:
  /// **'{here} logged here · {health} from your health app'**
  String waterLoggedHereAndHealth(String here, String health);

  /// No description provided for @takeOffAmount.
  ///
  /// In en, this message translates to:
  /// **'Take off {amount}'**
  String takeOffAmount(String amount);

  /// No description provided for @kcalUnit.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcalUnit;

  /// No description provided for @proteinShort.
  ///
  /// In en, this message translates to:
  /// **'protein'**
  String get proteinShort;

  /// No description provided for @carbsShort.
  ///
  /// In en, this message translates to:
  /// **'carbs'**
  String get carbsShort;

  /// No description provided for @fatShort.
  ///
  /// In en, this message translates to:
  /// **'fat'**
  String get fatShort;

  /// No description provided for @plusHealthEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Plus 1 entry from your health app.} other{Plus {count} entries from your health app.}}'**
  String plusHealthEntries(int count);

  /// No description provided for @medalFirstSteps.
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get medalFirstSteps;

  /// No description provided for @medalFirstStepsDesc.
  ///
  /// In en, this message translates to:
  /// **'Log your first steps data.'**
  String get medalFirstStepsDesc;

  /// No description provided for @medalStepSeeker.
  ///
  /// In en, this message translates to:
  /// **'Step Seeker'**
  String get medalStepSeeker;

  /// No description provided for @medalStepSeekerDesc.
  ///
  /// In en, this message translates to:
  /// **'Walk 5,000 steps in a single day.'**
  String get medalStepSeekerDesc;

  /// No description provided for @medalStepChampion.
  ///
  /// In en, this message translates to:
  /// **'Step Champion'**
  String get medalStepChampion;

  /// No description provided for @medalStepChampionDesc.
  ///
  /// In en, this message translates to:
  /// **'Walk 10,000 steps in a single day.'**
  String get medalStepChampionDesc;

  /// No description provided for @medalStepLegend.
  ///
  /// In en, this message translates to:
  /// **'Step Legend'**
  String get medalStepLegend;

  /// No description provided for @medalStepLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'Walk 20,000 steps in a single day.'**
  String get medalStepLegendDesc;

  /// No description provided for @medalHeartStarter.
  ///
  /// In en, this message translates to:
  /// **'Heart Starter'**
  String get medalHeartStarter;

  /// No description provided for @medalHeartStarterDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn 10 heart points in a single day.'**
  String get medalHeartStarterDesc;

  /// No description provided for @medalHeartWarrior.
  ///
  /// In en, this message translates to:
  /// **'Heart Warrior'**
  String get medalHeartWarrior;

  /// No description provided for @medalHeartWarriorDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn 25 heart points in a single day.'**
  String get medalHeartWarriorDesc;

  /// No description provided for @medalHeartLegend.
  ///
  /// In en, this message translates to:
  /// **'Heart Legend'**
  String get medalHeartLegend;

  /// No description provided for @medalHeartLegendDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn 50 heart points in a single day.'**
  String get medalHeartLegendDesc;

  /// No description provided for @medalActiveWeek.
  ///
  /// In en, this message translates to:
  /// **'Active Week'**
  String get medalActiveWeek;

  /// No description provided for @medalActiveWeekDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn 150 heart points across any 7-day period.'**
  String get medalActiveWeekDesc;

  /// No description provided for @medalOnTarget.
  ///
  /// In en, this message translates to:
  /// **'On Target'**
  String get medalOnTarget;

  /// No description provided for @medalOnTargetDesc.
  ///
  /// In en, this message translates to:
  /// **'Hit your daily Heart Points target for the first time.'**
  String get medalOnTargetDesc;

  /// No description provided for @medalTargetStreak3.
  ///
  /// In en, this message translates to:
  /// **'Hat Trick'**
  String get medalTargetStreak3;

  /// No description provided for @medalTargetStreak3Desc.
  ///
  /// In en, this message translates to:
  /// **'Hit your daily target 3 days in a row.'**
  String get medalTargetStreak3Desc;

  /// No description provided for @medalTargetStreak7.
  ///
  /// In en, this message translates to:
  /// **'Locked In'**
  String get medalTargetStreak7;

  /// No description provided for @medalTargetStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'Hit your daily target 7 days in a row.'**
  String get medalTargetStreak7Desc;

  /// No description provided for @medalComeback.
  ///
  /// In en, this message translates to:
  /// **'Comeback'**
  String get medalComeback;

  /// No description provided for @medalComebackDesc.
  ///
  /// In en, this message translates to:
  /// **'Hit your target after 3 or more days without hitting it.'**
  String get medalComebackDesc;

  /// No description provided for @medalTarget40.
  ///
  /// In en, this message translates to:
  /// **'Raising the Bar'**
  String get medalTarget40;

  /// No description provided for @medalTarget40Desc.
  ///
  /// In en, this message translates to:
  /// **'Grow your daily target to 40 Heart Points.'**
  String get medalTarget40Desc;

  /// No description provided for @medalMomentum50.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get medalMomentum50;

  /// No description provided for @medalMomentum50Desc.
  ///
  /// In en, this message translates to:
  /// **'Reach a Momentum score of 50.'**
  String get medalMomentum50Desc;

  /// No description provided for @medalMomentum75.
  ///
  /// In en, this message translates to:
  /// **'Unstoppable'**
  String get medalMomentum75;

  /// No description provided for @medalMomentum75Desc.
  ///
  /// In en, this message translates to:
  /// **'Reach a Momentum score of 75.'**
  String get medalMomentum75Desc;

  /// No description provided for @medalMomentumWeek75.
  ///
  /// In en, this message translates to:
  /// **'Perpetual Motion'**
  String get medalMomentumWeek75;

  /// No description provided for @medalMomentumWeek75Desc.
  ///
  /// In en, this message translates to:
  /// **'End 7 days in a row with Momentum of 75 or higher.'**
  String get medalMomentumWeek75Desc;

  /// No description provided for @medalNightLogged.
  ///
  /// In en, this message translates to:
  /// **'Night Logged'**
  String get medalNightLogged;

  /// No description provided for @medalNightLoggedDesc.
  ///
  /// In en, this message translates to:
  /// **'Log sleep data for the first time.'**
  String get medalNightLoggedDesc;

  /// No description provided for @medalWellRested.
  ///
  /// In en, this message translates to:
  /// **'Well Rested'**
  String get medalWellRested;

  /// No description provided for @medalWellRestedDesc.
  ///
  /// In en, this message translates to:
  /// **'Get 7+ hours of sleep in a single night.'**
  String get medalWellRestedDesc;

  /// No description provided for @medalDeepDreamer.
  ///
  /// In en, this message translates to:
  /// **'Deep Dreamer'**
  String get medalDeepDreamer;

  /// No description provided for @medalDeepDreamerDesc.
  ///
  /// In en, this message translates to:
  /// **'Get 1+ hour of deep sleep in a single night.'**
  String get medalDeepDreamerDesc;

  /// No description provided for @medalSleepChampion.
  ///
  /// In en, this message translates to:
  /// **'Sleep Champion'**
  String get medalSleepChampion;

  /// No description provided for @medalSleepChampionDesc.
  ///
  /// In en, this message translates to:
  /// **'Get 8+ hours of sleep in a single night.'**
  String get medalSleepChampionDesc;

  /// No description provided for @medalHydrated.
  ///
  /// In en, this message translates to:
  /// **'Hydrated'**
  String get medalHydrated;

  /// No description provided for @medalHydratedDesc.
  ///
  /// In en, this message translates to:
  /// **'Log 2+ litres of water in a single day.'**
  String get medalHydratedDesc;

  /// No description provided for @medalHealthyHeart.
  ///
  /// In en, this message translates to:
  /// **'Healthy Heart'**
  String get medalHealthyHeart;

  /// No description provided for @medalHealthyHeartDesc.
  ///
  /// In en, this message translates to:
  /// **'Record a resting heart rate of 60 bpm or lower.'**
  String get medalHealthyHeartDesc;

  /// No description provided for @medalOxygenCheck.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Check'**
  String get medalOxygenCheck;

  /// No description provided for @medalOxygenCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Log blood oxygen (SpO2) data.'**
  String get medalOxygenCheckDesc;

  /// No description provided for @medalFirstSync.
  ///
  /// In en, this message translates to:
  /// **'First Sync'**
  String get medalFirstSync;

  /// No description provided for @medalFirstSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync your health data for the first time.'**
  String get medalFirstSyncDesc;

  /// No description provided for @medalDedicated.
  ///
  /// In en, this message translates to:
  /// **'Dedicated'**
  String get medalDedicated;

  /// No description provided for @medalDedicatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync data on 7 different days.'**
  String get medalDedicatedDesc;

  /// No description provided for @medalCommitted.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get medalCommitted;

  /// No description provided for @medalCommittedDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync data on 30 different days.'**
  String get medalCommittedDesc;

  /// No description provided for @medalStepMillionaire.
  ///
  /// In en, this message translates to:
  /// **'Step Millionaire'**
  String get medalStepMillionaire;

  /// No description provided for @medalStepMillionaireDesc.
  ///
  /// In en, this message translates to:
  /// **'Walk a total of 1,000,000 steps.'**
  String get medalStepMillionaireDesc;

  /// No description provided for @medalElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get medalElite;

  /// No description provided for @medalEliteDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn a total of 1,000 heart points.'**
  String get medalEliteDesc;

  /// No description provided for @medalStreak3.
  ///
  /// In en, this message translates to:
  /// **'Consistent'**
  String get medalStreak3;

  /// No description provided for @medalStreak3Desc.
  ///
  /// In en, this message translates to:
  /// **'Log your health data 3 days in a row.'**
  String get medalStreak3Desc;

  /// No description provided for @medalStreak7.
  ///
  /// In en, this message translates to:
  /// **'Week Streak'**
  String get medalStreak7;

  /// No description provided for @medalStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'Log your health data every day for a week.'**
  String get medalStreak7Desc;

  /// No description provided for @medalStreak30.
  ///
  /// In en, this message translates to:
  /// **'Iron Habit'**
  String get medalStreak30;

  /// No description provided for @medalStreak30Desc.
  ///
  /// In en, this message translates to:
  /// **'Log your health data every day for 30 days.'**
  String get medalStreak30Desc;

  /// No description provided for @widgetHeartPts.
  ///
  /// In en, this message translates to:
  /// **'Heart Pts'**
  String get widgetHeartPts;

  /// No description provided for @widgetLocked.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Fitness to see today'**
  String get widgetLocked;

  /// No description provided for @widgetLockedShort.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get widgetLockedShort;

  /// No description provided for @widgetHpGoal.
  ///
  /// In en, this message translates to:
  /// **'of %1\$s Heart Pts'**
  String get widgetHpGoal;

  /// No description provided for @widgetStepsGoal.
  ///
  /// In en, this message translates to:
  /// **'of %1\$s steps'**
  String get widgetStepsGoal;

  /// No description provided for @widgetMomentum.
  ///
  /// In en, this message translates to:
  /// **'Momentum %1\$s'**
  String get widgetMomentum;

  /// No description provided for @widgetSummary.
  ///
  /// In en, this message translates to:
  /// **'%1\$s of %2\$s Heart Points, %3\$s of %4\$s steps'**
  String get widgetSummary;

  /// No description provided for @challenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challenges;

  /// No description provided for @challengesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compete with friends, end-to-end encrypted'**
  String get challengesSubtitle;

  /// No description provided for @challengeSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get challengeSyncNow;

  /// No description provided for @challengeNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get challengeNeedsInternet;

  /// No description provided for @challengeJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join {title}'**
  String challengeJoinRequest(String name, String title);

  /// No description provided for @challengeJoinRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to compare codes and let them in'**
  String get challengeJoinRequestHint;

  /// No description provided for @challengeActive.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get challengeActive;

  /// No description provided for @challengeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get challengeUpcoming;

  /// No description provided for @challengeFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get challengeFinished;

  /// No description provided for @challengeCreate.
  ///
  /// In en, this message translates to:
  /// **'Start a challenge'**
  String get challengeCreate;

  /// No description provided for @challengeJoin.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite'**
  String get challengeJoin;

  /// No description provided for @challengeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge your friends'**
  String get challengeEmptyTitle;

  /// No description provided for @challengeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Race friends on steps or Heart Points for a few days or a month, and see who\'s ahead.'**
  String get challengeEmptyBody;

  /// No description provided for @challengePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Friends see only one number per challenge: your total. It\'s encrypted for the people in the challenge, and the server can\'t read it.'**
  String get challengePrivacy;

  /// No description provided for @challengeWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the organiser'**
  String get challengeWaitingTitle;

  /// No description provided for @challengeWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see the challenge once they confirm your code.'**
  String get challengeWaitingBody;

  /// No description provided for @challengeYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your code:'**
  String get challengeYourCode;

  /// No description provided for @challengeGoalMostSummary.
  ///
  /// In en, this message translates to:
  /// **'Most {metric}'**
  String challengeGoalMostSummary(String metric);

  /// No description provided for @challengeGoalDaysSummary.
  ///
  /// In en, this message translates to:
  /// **'Days with {target} {metric}'**
  String challengeGoalDaysSummary(String target, String metric);

  /// No description provided for @challengeStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String challengeStarts(String date);

  /// No description provided for @challengeDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last day} other{{count} days left}}'**
  String challengeDaysLeft(int count);

  /// No description provided for @challengeEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String challengeEnded(String date);

  /// No description provided for @challengeYourRank.
  ///
  /// In en, this message translates to:
  /// **'#{rank} of {count}'**
  String challengeYourRank(int rank, int count);

  /// No description provided for @challengeGone.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in this challenge.'**
  String get challengeGone;

  /// No description provided for @challengeInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get challengeInvite;

  /// No description provided for @challengeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit challenge'**
  String get challengeEdit;

  /// No description provided for @challengeLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get challengeLeave;

  /// No description provided for @challengeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get challengeDelete;

  /// No description provided for @challengeDates.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String challengeDates(String start, String end);

  /// No description provided for @challengeLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get challengeLeaderboard;

  /// No description provided for @challengeDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String challengeDaysUnit(int count);

  /// No description provided for @challengeTotalDetail.
  ///
  /// In en, this message translates to:
  /// **'{total} {metric} in total'**
  String challengeTotalDetail(String total, String metric);

  /// No description provided for @challengeInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to see them here.'**
  String get challengeInviteHint;

  /// No description provided for @challengeWhatIsShared.
  ///
  /// In en, this message translates to:
  /// **'Shared with this challenge: only your {metric} total for its days (and how many days met the target). Your other data, workouts and locations stay private.'**
  String challengeWhatIsShared(String metric);

  /// No description provided for @challengeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this challenge?'**
  String get challengeDeleteTitle;

  /// No description provided for @challengeDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s removed for everyone in it, with all its results.'**
  String get challengeDeleteBody;

  /// No description provided for @challengeLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this challenge?'**
  String get challengeLeaveTitle;

  /// No description provided for @challengeLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your total is removed from the board and this phone stops sharing with it. You can rejoin with a new invite.'**
  String get challengeLeaveBody;

  /// No description provided for @challengeRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String challengeRemoveTitle(String name);

  /// No description provided for @challengeRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They leave the challenge and can\'t read anything shared from now on.'**
  String get challengeRemoveBody;

  /// No description provided for @challengeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get challengeRemove;

  /// No description provided for @challengeYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String challengeYou(String name);

  /// No description provided for @challengeNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get challengeNoDataYet;

  /// No description provided for @challengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get challengeTitle;

  /// No description provided for @challengeTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. November step-off'**
  String get challengeTitleHint;

  /// No description provided for @challengeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get challengeRequired;

  /// No description provided for @challengeMeasure.
  ///
  /// In en, this message translates to:
  /// **'What counts'**
  String get challengeMeasure;

  /// No description provided for @challengeWinBy.
  ///
  /// In en, this message translates to:
  /// **'How to win'**
  String get challengeWinBy;

  /// No description provided for @challengeGoalMost.
  ///
  /// In en, this message translates to:
  /// **'Highest total'**
  String get challengeGoalMost;

  /// No description provided for @challengeGoalDays.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get challengeGoalDays;

  /// No description provided for @challengeGoalMostHint.
  ///
  /// In en, this message translates to:
  /// **'Whoever has the most by the last day wins.'**
  String get challengeGoalMostHint;

  /// No description provided for @challengeGoalDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Whoever reaches the daily target on the most days wins. Ties go to the higher total.'**
  String get challengeGoalDaysHint;

  /// No description provided for @challengeDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target ({metric})'**
  String challengeDailyTarget(String metric);

  /// No description provided for @challengeStartDate.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get challengeStartDate;

  /// No description provided for @challengeLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get challengeLength;

  /// No description provided for @challengeLengthDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String challengeLengthDays(int count);

  /// No description provided for @challengeYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name in challenges'**
  String get challengeYourName;

  /// No description provided for @challengeYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'What friends in the challenge see'**
  String get challengeYourNameHint;

  /// No description provided for @challengeCreateAndInvite.
  ///
  /// In en, this message translates to:
  /// **'Create and invite friends'**
  String get challengeCreateAndInvite;

  /// No description provided for @challengeInviteTo.
  ///
  /// In en, this message translates to:
  /// **'Invite to {title}'**
  String challengeInviteTo(String title);

  /// No description provided for @challengeInviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Make a one-time invite: send the link, or let a friend scan the QR code. Each invite works for one person, for 7 days.'**
  String get challengeInviteIntro;

  /// No description provided for @challengeCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite'**
  String get challengeCreateInvite;

  /// No description provided for @challengeInviteReady.
  ///
  /// In en, this message translates to:
  /// **'Send this link, or let your friend scan the code with ZT Fitness.'**
  String get challengeInviteReady;

  /// No description provided for @challengeInviteQr.
  ///
  /// In en, this message translates to:
  /// **'Invite QR code'**
  String get challengeInviteQr;

  /// No description provided for @challengeLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get challengeLinkCopied;

  /// No description provided for @challengeCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get challengeCopyLink;

  /// No description provided for @challengeShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get challengeShareLink;

  /// No description provided for @challengeInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my fitness challenge \"{title}\" in ZT Fitness: {link}'**
  String challengeInviteMessage(String title, String link);

  /// No description provided for @challengeInviteNextSteps.
  ///
  /// In en, this message translates to:
  /// **'When your friend opens it, they\'ll see a code. Check it matches the code on your phone before letting them in: that\'s what keeps a stranger with the link out.'**
  String get challengeInviteNextSteps;

  /// No description provided for @challengeCheckAnswers.
  ///
  /// In en, this message translates to:
  /// **'Check for answers'**
  String get challengeCheckAnswers;

  /// No description provided for @challengeAnotherInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite someone else'**
  String get challengeAnotherInvite;

  /// No description provided for @challengeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Let {name} in?'**
  String challengeConfirmTitle(String name);

  /// No description provided for @challengeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Check this code matches the one on their phone.'**
  String get challengeConfirmBody;

  /// No description provided for @challengeCodesDiffer.
  ///
  /// In en, this message translates to:
  /// **'Codes differ'**
  String get challengeCodesDiffer;

  /// No description provided for @challengeLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get challengeLater;

  /// No description provided for @challengeCodesMatch.
  ///
  /// In en, this message translates to:
  /// **'Codes match'**
  String get challengeCodesMatch;

  /// No description provided for @challengeJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined'**
  String challengeJoined(String name);

  /// No description provided for @challengeInviteOtherApp.
  ///
  /// In en, this message translates to:
  /// **'This invite is for another Zero-Trust app.'**
  String get challengeInviteOtherApp;

  /// No description provided for @challengeInviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a challenge invite link.'**
  String get challengeInviteInvalid;

  /// No description provided for @challengeInviteUsed.
  ///
  /// In en, this message translates to:
  /// **'This invite was already used or has expired. Ask for a new one.'**
  String get challengeInviteUsed;

  /// No description provided for @challengeJoinCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Show this code to the organiser'**
  String get challengeJoinCodeTitle;

  /// No description provided for @challengeJoinCodeBody.
  ///
  /// In en, this message translates to:
  /// **'They\'ll see the same code on their phone. Once they confirm, the challenge appears here.'**
  String get challengeJoinCodeBody;

  /// No description provided for @challengeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get challengeDone;

  /// No description provided for @challengeJoinIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste the invite link a friend sent you, or scan their QR code.'**
  String get challengeJoinIntro;

  /// No description provided for @challengeInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get challengeInviteLink;

  /// No description provided for @challengeScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get challengeScanQr;

  /// No description provided for @challengeJoinPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Joining shares only your total for the challenge\'s measure and days. You can leave at any time.'**
  String get challengeJoinPrivacy;

  /// No description provided for @challengeJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get challengeJoinButton;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
