// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get couldntOpenYourFitnessData =>
      'Couldn\'t open your fitness data on this device.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get openingYourFitnessData => 'Opening your fitness data…';

  @override
  String get connectYourHealthData => 'Connect your health data?';

  @override
  String get fitnessCanReadStepsWorkouts =>
      'Fitness can read steps, workouts, heart rate, sleep and more from Health Connect. It stays encrypted on your phone and in your vault. You can change this any time in Settings.';

  @override
  String get notNow => 'Not now';

  @override
  String get choosePermissions => 'Choose permissions';

  @override
  String get today => 'Today';

  @override
  String get trends => 'Trends';

  @override
  String get journal => 'Journal';

  @override
  String get settings => 'Settings';

  @override
  String get syncFromHealthConnectOr =>
      'Sync from Health Connect or log an entry manually.';

  @override
  String get permissionRequired => 'Permission required';

  @override
  String get grantPermission => 'Grant permission';

  @override
  String get notTracked => 'Not tracked';

  @override
  String get vaultLocked => 'Vault locked';

  @override
  String get unlockYourVaultToSee => 'Unlock your vault to see health data.';

  @override
  String get unlock => 'Unlock';

  @override
  String get retry => 'Retry';

  @override
  String get noPriorWeekData => 'No prior week data';

  @override
  String get dayStreak => 'day streak';

  @override
  String get personalBest => 'Personal best!';

  @override
  String get stepsThisWeek => 'steps this week';

  @override
  String get activity => 'Activity';

  @override
  String get steps => 'Steps';

  @override
  String get heartPoints => 'Heart Points';

  @override
  String get sleep => 'Sleep';

  @override
  String get totalSleep => 'Total Sleep';

  @override
  String get lightSleep => 'Light Sleep';

  @override
  String get deepSleep => 'Deep Sleep';

  @override
  String get remSleep => 'REM Sleep';

  @override
  String get vitals => 'Vitals';

  @override
  String get restingHr => 'Resting HR';

  @override
  String get respiratoryRate => 'Respiratory Rate';

  @override
  String get bloodOxygen => 'Blood Oxygen';

  @override
  String get bpSystolic => 'BP Systolic';

  @override
  String get bpDiastolic => 'BP Diastolic';

  @override
  String get bloodGlucose => 'Blood Glucose';

  @override
  String get body => 'Body';

  @override
  String get weight => 'Weight';

  @override
  String get bodyFat => 'Body Fat';

  @override
  String get lifestyle => 'Lifestyle';

  @override
  String get hydration => 'Hydration';

  @override
  String get nutrition => 'Nutrition';

  @override
  String get noTemplatesYetCreateOne =>
      'No templates yet. Create one in Profile → Workout Templates.';

  @override
  String get chooseATemplate => 'Choose a template';

  @override
  String get enterAtLeastOneWorkout =>
      'Enter at least one workout or metric to log.';

  @override
  String get vaultIsLockedUnlockBefore =>
      'Vault is locked. Unlock before saving data.';

  @override
  String get logHealthData => 'Log Health Data';

  @override
  String get allDataIsEncryptedBefore =>
      'All data is encrypted before leaving this device.';

  @override
  String get workout => 'Workout';

  @override
  String get healthMetrics => 'Health Metrics';

  @override
  String get useTemplate => 'Use template';

  @override
  String get activityType => 'Activity Type';

  @override
  String get duration => 'Duration';

  @override
  String get minutes => 'Minutes';

  @override
  String get intensity => 'Intensity';

  @override
  String get light => 'Light';

  @override
  String get moderate => 'Moderate';

  @override
  String get vigorous => 'Vigorous';

  @override
  String get lightIntensityNoHeartPoints => 'Light intensity — no heart points';

  @override
  String get addsToExisting => 'Adds to existing';

  @override
  String get replacesExisting => 'Replaces existing';

  @override
  String get encryptVaultData => 'Encrypt & Vault Data';

  @override
  String get targetHitTomorrowsTargetGrows =>
      'Target hit! Tomorrow\'s target grows 5%.';

  @override
  String get momentum => 'Momentum';

  @override
  String get howMomentumWorks => 'How Momentum works';

  @override
  String get todaysTarget => 'Today\'s target';

  @override
  String get gotIt => 'Got it';

  @override
  String get howZeroTrustWorks => 'How Zero-Trust Works';

  @override
  String get localFirstStorage => 'Local-first storage';

  @override
  String get allYourHealthDataIs =>
      'All your health data is encrypted with SQLCipher and stored only on your device. Nothing is uploaded unless you explicitly sync.';

  @override
  String get yourPasswordYourData => 'Your password, your data';

  @override
  String get yourMasterPasswordDerivesThe =>
      'Your master password derives the encryption key on-device using key stretching (PBKDF2). The password and key never leave your device.';

  @override
  String get endToEndEncryptedBackups => 'End-to-end encrypted backups';

  @override
  String get ifYouChooseToSync =>
      'If you choose to sync, data is encrypted client-side before uploading. The server stores only an encrypted blob it cannot read.';

  @override
  String get biometricUnlock => 'Biometric unlock';

  @override
  String get biometricUnlockStoresOnlyA =>
      'Biometric unlock stores only a reference to your passphrase in the OS secure enclave. Your actual health data is never accessible to the biometrics system.';

  @override
  String get optInPermissions => 'Opt-in permissions';

  @override
  String get healthConnectAndLocationPermissions =>
      'Health Connect and location permissions are always opt-in and revocable. You control exactly which metrics are read.';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisWeekSoFar => 'This week so far';

  @override
  String get vsTheWeekBefore => 'vs the week before';

  @override
  String get activeDays => 'active days';

  @override
  String get timeToMove => 'Time to move!';

  @override
  String get movementReminders => 'Movement Reminders';

  @override
  String get stayHydrated => 'Stay hydrated!';

  @override
  String get drinkAGlassOfWater =>
      'Drink a glass of water to keep your hydration on track.';

  @override
  String get hydrationReminders => 'Hydration Reminders';

  @override
  String get workoutTime => 'Workout time!';

  @override
  String get workoutReminders => 'Workout Reminders';

  @override
  String get bedtimeSoon => 'Bedtime soon';

  @override
  String get windingDownNowSupportsBetter =>
      'Winding down now supports better sleep quality.';

  @override
  String get sleepReminders => 'Sleep Reminders';

  @override
  String get weeklyCheckIn => 'Weekly check-in';

  @override
  String get timeToLogYourWeight =>
      'Time to log your weight or other measurements.';

  @override
  String get measurementReminders => 'Measurement Reminders';

  @override
  String get weeklySummary => 'Weekly Summary';

  @override
  String get yourWeekOfHeartPoints =>
      'Your week of Heart Points and steps, Mondays';

  @override
  String get youHaventBeenActiveIn =>
      'You haven\'t been active in a while. A short walk counts.';

  @override
  String get yourScheduledWorkoutIsToday =>
      'Your scheduled workout is today. Let\'s get moving.';

  @override
  String get noInternetConnectionCheckYour =>
      'No internet connection. Check your network and try again.';

  @override
  String get signInFailedCheckYour =>
      'Sign-in failed. Check your email and password.';

  @override
  String get accessDeniedPleaseSignIn => 'Access denied. Please sign in again.';

  @override
  String get serverErrorPleaseTryAgain =>
      'Server error. Please try again in a moment.';

  @override
  String get cloudBackupIsUnreadableIt =>
      'Cloud backup is unreadable. It may have been created with a different password.';

  @override
  String get vaultCouldNotBeOpened =>
      'Vault could not be opened. The master password may be incorrect.';

  @override
  String get locationPermissionRequiredForGps =>
      'Location permission required for GPS tracking.';

  @override
  String get requestTimedOutCheckYour =>
      'Request timed out. Check your connection and try again.';

  @override
  String get somethingWentWrongPleaseTry =>
      'Something went wrong. Please try again.';

  @override
  String get fitness => 'Fitness';

  @override
  String get health => 'Health';

  @override
  String get milestones => 'Milestones';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get keepGoing => 'Keep going!';

  @override
  String get achievements => 'Achievements';

  @override
  String get all => 'All';

  @override
  String get locked => 'Locked';

  @override
  String get sleepAsleep => 'Sleep Asleep';

  @override
  String get sleepLight => 'Sleep Light';

  @override
  String get sleepDeep => 'Sleep Deep';

  @override
  String get sleepRem => 'Sleep REM';

  @override
  String get respiratory => 'Respiratory';

  @override
  String get glucose => 'Glucose';

  @override
  String get workoutPaused => 'Workout paused.';

  @override
  String get workoutResumed => 'Workout resumed.';

  @override
  String get gpsWorkout => 'GPS workout';

  @override
  String get timeDistanceAndControlsWhile =>
      'Time, distance and controls while recording';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get lap => 'Lap';

  @override
  String get unstoppable => 'Unstoppable';

  @override
  String get steady => 'Steady';

  @override
  String get building => 'Building';

  @override
  String get gettingStarted => 'Getting started';

  @override
  String get bringingOverYourDataFrom =>
      'Bringing over your data from the previous version…';

  @override
  String get yourDataFromThePrevious =>
      'Your data from the previous version hasn\'t been brought over yet: the server couldn\'t be reached. Check your connection and try again.';

  @override
  String get thatPasswordDidntOpenYour =>
      'That password didn\'t open your data from the previous version either. Try another password you used before, or skip it.';

  @override
  String get yourDataFromThePreviousX =>
      'Your data from the previous version is locked with the password you used before this update. Enter it once to bring it over.';

  @override
  String get skip => 'Skip';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get yourDataFromThePreviousXX =>
      'Your data from the previous version hasn\'t been brought over yet. Something went wrong; try again.';

  @override
  String get skipTheLockedData => 'Skip the locked data?';

  @override
  String get whateverNoPasswordOpenedStays =>
      'Whatever no password opened stays where it is (the old file is kept on this phone) but won\'t show in the app. Everything else from the previous version is brought over.';

  @override
  String get cancel => 'Cancel';

  @override
  String get yourDataFromThePreviousXXX =>
      'Your data from the previous version is here.';

  @override
  String get stillCouldntReachTheServer =>
      'Still couldn\'t reach the server. Check your connection.';

  @override
  String get thatPasswordDidntOpenIt =>
      'That password didn\'t open it. Try another one you used before.';

  @override
  String get thatDidntWorkTryAgain =>
      'That didn\'t work. Try again in a moment.';

  @override
  String get passwordFromBeforeTheUpdate => 'Password from before the update';

  @override
  String get thePasswordZeroTrustFitness =>
      'The password Zero-Trust Fitness used before this update. It only unlocks your old data on this phone; it isn\'t sent anywhere and doesn\'t change your account.';

  @override
  String get oldPassword => 'Old password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get sameAsLastWeek => ' (same as last week)';

  @override
  String get yourWeekInFitness => 'Your week in Fitness';

  @override
  String get noActivityLoggedThisWeek =>
      'No activity logged this week. A short walk is a good start.';

  @override
  String get allMetrics => 'All Metrics';

  @override
  String get logAWorkoutOrHealth => 'Log a workout or health metric';

  @override
  String get couldNotReadSelectedFile => 'Could not read selected file.';

  @override
  String get failedToReadFile => 'Failed to read file.';

  @override
  String get invalidOrUnsupportedExportFile =>
      'Invalid or unsupported export file (version too new?).';

  @override
  String get restoreFromBackup => 'Restore from backup?';

  @override
  String get workoutsMissingHereAreAdded =>
      'Workouts missing here are added, days in the file replace the same days here, and goals are set. It syncs to your other devices.';

  @override
  String get exported => 'Exported';

  @override
  String get workouts => 'Workouts';

  @override
  String get metricDays => 'Metric days';

  @override
  String get goals => 'Goals';

  @override
  String get restore => 'Restore';

  @override
  String get exportRestore => 'Export & Restore';

  @override
  String get exportLabel => 'Export';

  @override
  String get exportFullBackupJson => 'Export full backup (JSON)';

  @override
  String get allWorkoutsMetricsGoalsAnd =>
      'All workouts, metrics, goals and medals. Not encrypted: keep it safe.';

  @override
  String get exportMetricsCsv => 'Export metrics (CSV)';

  @override
  String get dailyHealthMetricsAsA =>
      'Daily health metrics as a spreadsheet, for analysis';

  @override
  String get restoreFromJson => 'Restore from JSON';

  @override
  String get bringAFullBackupBack =>
      'Bring a full backup back in. Nothing here is deleted.';

  @override
  String get yourDataIsSyncedEnd =>
      'Your data is synced, end-to-end encrypted, to your other devices as you go. To be able to get back in if you forget your password, keep your recovery key safe (Settings → New recovery key).';

  @override
  String get enterAValidTargetValue => 'Enter a valid target value.';

  @override
  String get active => 'Active';

  @override
  String get period => 'Period';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get remove => 'Remove';

  @override
  String get save => 'Save';

  @override
  String get noGoogleFitDataFound =>
      'No Google Fit data found in that file. Choose the Takeout .zip, or the \"Daily activity metrics.csv\" file from its Fit folder.';

  @override
  String get importFromGoogleFit => 'Import from Google Fit';

  @override
  String get bringYourGoogleFitHistory =>
      'Bring your Google Fit history with you';

  @override
  String get s1GoToTakeoutGoogle =>
      '1. Go to takeout.google.com and choose only \"Fit\".\n2. Download the .zip Google emails you.\n3. Choose it here (or the \"Daily activity metrics.csv\" inside).';

  @override
  String get theFileIsReadOn =>
      'The file is read on this phone. Your steps, Heart Points, weight and workouts are added to your encrypted vault, and days already counted aren\'t counted twice. Importing again adds nothing new.';

  @override
  String get addingToYourVault => 'Adding to your vault…';

  @override
  String get readingTheExport => 'Reading the export…';

  @override
  String get done => 'Done';

  @override
  String get found => 'Found';

  @override
  String get importLabel => 'Import';

  @override
  String get chooseAnotherFile => 'Choose another file';

  @override
  String get chooseTakeoutFile => 'Choose Takeout file';

  @override
  String get fitnessNeedsLocationAccessTo =>
      'Fitness needs location access to record a GPS workout. You can allow it in your phone\'s settings.';

  @override
  String get finishWorkout => 'Finish workout?';

  @override
  String get discardWorkout => 'Discard workout?';

  @override
  String get itsSavedToYourJournal => 'It\'s saved to your journal.';

  @override
  String get thisWorkoutWontBeSaved => 'This workout won\'t be saved.';

  @override
  String get keepGoingX => 'Keep going';

  @override
  String get finish => 'Finish';

  @override
  String get discard => 'Discard';

  @override
  String get vaultLockedWorkoutNotSaved => 'Vault locked, workout not saved.';

  @override
  String get voiceCuesOn => 'Voice cues on';

  @override
  String get voiceCuesOff => 'Voice cues off';

  @override
  String get more => 'More';

  @override
  String get autoPause => 'Auto-pause';

  @override
  String get discardWorkoutX => 'Discard workout';

  @override
  String get stopsTheClockWhenYou => 'Stops the clock when you stop moving';

  @override
  String get voiceCues => 'Voice cues';

  @override
  String get yourRouteStaysEncryptedIn =>
      'Your route stays encrypted in your vault. While you record, a notification shows time and distance, with Pause and Lap buttons on the lock screen.';

  @override
  String get findingGps => 'Finding GPS…';

  @override
  String get start => 'Start';

  @override
  String get autoPaused => 'AUTO-PAUSED';

  @override
  String get paused => 'PAUSED';

  @override
  String get avgPace => 'avg pace';

  @override
  String get waitingForGps => 'Waiting for GPS…';

  @override
  String get noTracksWithAtLeast =>
      'No tracks with at least two points in that file.';

  @override
  String get enterHowLongEachWorkout => 'Enter how long each workout took.';

  @override
  String get importGpxRoutes => 'Import GPX routes';

  @override
  String get bringInWorkoutsFromStrava =>
      'Bring in workouts from Strava, Komoot, Garmin or any app that exports .gpx files. The file is read on this phone and saved encrypted, like everything else.';

  @override
  String get chooseGpxFiles => 'Choose GPX files';

  @override
  String get track => 'Track';

  @override
  String get alreadyImported => 'already imported';

  @override
  String get thisFileHasNoTimes =>
      'This file has no times. When was it, and how long did it take?';

  @override
  String get countHeartPoints => 'Count Heart Points';

  @override
  String get turnOffIfTheseWorkouts =>
      'Turn off if these workouts are already in your health app, so they don\'t count twice';

  @override
  String get yourDataYourKeysYour =>
      'Your data, your keys, your privacy. Track activity, workouts and health, encrypted on your phone before anything is synced.';

  @override
  String get getStarted => 'Get started';

  @override
  String get learnMoreAboutZeroTrust => 'Learn more about Zero-Trust';

  @override
  String get unknownDate => 'Unknown date';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get nothingLoggedYet => 'Nothing logged yet';

  @override
  String get workoutsAndMeasurementsYouLog =>
      'Workouts and measurements you log, record or import show up here.';

  @override
  String get logAWorkoutOrMeasurement => 'Log a workout or measurement';

  @override
  String get searchTheJournal => 'Search the journal…';

  @override
  String get clear => 'Clear';

  @override
  String get measurements => 'Measurements';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get thisDeletesItOnAll => 'This deletes it on all your devices.';

  @override
  String get distance => 'Distance';

  @override
  String get avgPaceX => 'Avg pace';

  @override
  String get splits => 'Splits';

  @override
  String get laps => 'Laps';

  @override
  String get exportRouteGpx => 'Export route (GPX)';

  @override
  String get valuesFromHealthConnectFor =>
      'Values from Health Connect for that day stay.';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get s7DayAverage => '7-day average';

  @override
  String get s30DayAverage => '30-day average';

  @override
  String get goal => 'Goal';

  @override
  String get notSet => 'Not set';

  @override
  String get setGoal => 'Set goal';

  @override
  String get sourceBreakdown => 'Source Breakdown';

  @override
  String get manualEntries => 'Manual entries';

  @override
  String get last30Days => 'Last 30 Days';

  @override
  String get yourRoutesMapsWereAlready =>
      'Your routes\' maps were already on this phone.';

  @override
  String get offlineMaps => 'Offline maps';

  @override
  String get routeMapsComeFromOpenstreetmap =>
      'Route maps come from OpenStreetMap. Each map tile is kept on this phone the first time it is shown, so the map server is asked once at most, not every time you open a workout.';

  @override
  String get offlineMapsOnly => 'Offline maps only';

  @override
  String get neverContactTheMapServer =>
      'Never contact the map server. Areas you haven\'t saved show the route on a blank background.';

  @override
  String get saveMapsOfMyRoutes => 'Save maps of my routes';

  @override
  String get noGpsRoutesYet => 'No GPS routes yet';

  @override
  String get deleteSavedMaps => 'Delete saved maps';

  @override
  String get readDailyStepCounts => 'Read daily step counts.';

  @override
  String get heartRate => 'Heart Rate';

  @override
  String get readHeartRateSamples => 'Read heart-rate samples.';

  @override
  String get exerciseSessions => 'Exercise Sessions';

  @override
  String get readWorkoutsAndActiveMinutes =>
      'Read workouts and active minutes.';

  @override
  String get readSleepAsleepDuration => 'Read sleep-asleep duration.';

  @override
  String get readLightSleepDuration => 'Read light sleep duration.';

  @override
  String get readDeepSleepDuration => 'Read deep sleep duration.';

  @override
  String get readRemSleepDuration => 'Read REM sleep duration.';

  @override
  String get restingHeartRate => 'Resting Heart Rate';

  @override
  String get readRestingBpm => 'Read resting BPM.';

  @override
  String get readRespirationsPerMinute => 'Read respirations per minute.';

  @override
  String get readOxygenSaturationSpo2 => 'Read oxygen saturation (SpO2).';

  @override
  String get readBodyWeight => 'Read body weight.';

  @override
  String get bodyMassIndex => 'Body Mass Index';

  @override
  String get readBmiValues => 'Read BMI values.';

  @override
  String get bodyFatX => 'Body Fat %';

  @override
  String get readBodyFatPercentage => 'Read body fat percentage.';

  @override
  String get readWaterIntake => 'Read water intake.';

  @override
  String get readNutritionEntries => 'Read nutrition entries.';

  @override
  String get bloodPressureSystolic => 'Blood Pressure Systolic';

  @override
  String get readSystolicBloodPressure => 'Read systolic blood pressure.';

  @override
  String get bloodPressureDiastolic => 'Blood Pressure Diastolic';

  @override
  String get readDiastolicBloodPressure => 'Read diastolic blood pressure.';

  @override
  String get readBloodGlucoseSamples => 'Read blood glucose samples.';

  @override
  String get permissionsCenter => 'Permissions Center';

  @override
  String get refreshPermissionStates => 'Refresh permission states';

  @override
  String get controlEachPermissionDirectlyFrom =>
      'Control each permission directly from here.';

  @override
  String get installHealthConnect => 'Install Health Connect';

  @override
  String get location => 'Location';

  @override
  String get enableRealTimeGpsRun => 'Enable real-time GPS run/cycle tracking.';

  @override
  String get backgroundHealthSync => 'Background Health Sync';

  @override
  String get allowPeriodicBackgroundHealthData =>
      'Allow periodic background health data reads.';

  @override
  String get granted => 'Granted';

  @override
  String get denied => 'Denied';

  @override
  String get unknown => 'Unknown';

  @override
  String get turnOn => 'Turn On';

  @override
  String get turnOff => 'Turn Off';

  @override
  String get medals => 'Medals';

  @override
  String get templates => 'Templates';

  @override
  String get meals => 'Meals';

  @override
  String get privacyDashboard => 'Privacy Dashboard';

  @override
  String get everythingIsEncryptedOnThis =>
      'Everything is encrypted on this phone with a key only your password or recovery key can open. The server, and the developer, see only ciphertext.';

  @override
  String get storedInYourVault => 'Stored in your vault';

  @override
  String get howYourDataIsProtected => 'How your data is protected';

  @override
  String get encryptionSyncAndWhatThe =>
      'Encryption, sync and what the server sees';

  @override
  String get yourDataRights => 'Your Data Rights';

  @override
  String get youOwnAllYourData =>
      'You own all your data. Only your devices can read it.';

  @override
  String get exportAFullBackupAt =>
      'Export a full backup at any time from Export & Restore.';

  @override
  String get deleteActivityDataFromSettings =>
      'Delete activity data from Settings → Delete activity data.';

  @override
  String get deletingYourAccountRemovesEverything =>
      'Deleting your account removes everything from the server.';

  @override
  String get notificationPermissionRequiredForReminders =>
      'Notification permission required for reminders.';

  @override
  String get reminders => 'Reminders';

  @override
  String get summary => 'Summary';

  @override
  String get weeklySummaryX => 'Weekly summary';

  @override
  String get mondaysAt900Heart =>
      'Mondays at 9:00: Heart Points, steps and workouts, compared with the week before';

  @override
  String get movementNudge => 'Movement nudge';

  @override
  String get hourlyReminderToStayActive => 'Hourly reminder to stay active';

  @override
  String get hydrationReminder => 'Hydration reminder';

  @override
  String get hourlyPromptToDrinkWater => 'Hourly prompt to drink water';

  @override
  String get workoutReminder => 'Workout reminder';

  @override
  String get chooseDaysAndTime => 'Choose days and time';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get bedtimeReminder => 'Bedtime reminder';

  @override
  String get dailyWindDownPrompt => 'Daily wind-down prompt';

  @override
  String get bedtime => 'Bedtime';

  @override
  String get bodyMeasurements => 'Body Measurements';

  @override
  String get weeklyReminderToLogWeight =>
      'Weekly reminder to log weight or measurements';

  @override
  String get allRemindersAreLocalOnly =>
      'All reminders are local-only and never leave your device. Your data is locked while Fitness is closed, so the weekly summary is prepared each time you open the app.';

  @override
  String get copyPastWorkoutsToo => 'Copy past workouts too?';

  @override
  String get onlyNewOnes => 'Only new ones';

  @override
  String get copyThem => 'Copy them';

  @override
  String get unitsFormat => 'Units & Format';

  @override
  String get metricKmKg => 'Metric (km, kg)';

  @override
  String get imperialMiLbs => 'Imperial (mi, lbs)';

  @override
  String get timeFormat => 'Time format';

  @override
  String get s12HourAmPm => '12-hour (AM/PM)';

  @override
  String get noMedalsYetKeepMoving => 'No medals yet — keep moving!';

  @override
  String get deleteActivityData => 'Delete activity data?';

  @override
  String get deletesYourWorkoutsDailyMetrics =>
      'Deletes your workouts, daily metrics and medals on every device signed in to this account. Goals and templates stay. Health Connect data on the phone is not touched. This can\'t be undone.';

  @override
  String get activityDataDeleted => 'Activity data deleted.';

  @override
  String get setDailyAndWeeklyTargets => 'Set daily and weekly targets';

  @override
  String get weeklySummaryMovementWaterWorkouts =>
      'Weekly summary, movement, water, workouts & sleep';

  @override
  String get workoutTemplates => 'Workout templates';

  @override
  String get createAndReuseWorkoutRoutines =>
      'Create and reuse workout routines';

  @override
  String get healthPermissions => 'Health permissions';

  @override
  String get chooseWhatFitnessMayRead => 'Choose what Fitness may read';

  @override
  String get saveWorkoutsToAppleHealth => 'Save workouts to Apple Health';

  @override
  String get saveWorkoutsToHealthConnect => 'Save workouts to Health Connect';

  @override
  String get workoutsYouLogOrRecord =>
      'Workouts you log or record here show up in your other apps';

  @override
  String get showOnWearOsWatch => 'Show on Wear OS watch';

  @override
  String get todaysHeartPointsStepsAnd =>
      'Today\'s Heart Points, steps and water on your paired watch, and add water from it. Sent only to the watch.';

  @override
  String get unitsFormatX => 'Units & format';

  @override
  String get keepRouteMapsOnThis => 'Keep route maps on this phone';

  @override
  String get privacyDashboardX => 'Privacy dashboard';

  @override
  String get whatYourVaultHoldsAnd =>
      'What your vault holds and how it is protected';

  @override
  String get exportRestoreX => 'Export & restore';

  @override
  String get backUpToAFile => 'Back up to a file or bring a backup back in';

  @override
  String get yourHistoryFromAGoogle =>
      'Your history from a Google Takeout export';

  @override
  String get fromStravaKomootGarminAnd =>
      'From Strava, Komoot, Garmin and others';

  @override
  String get shareReport => 'Share report';

  @override
  String get aScopedHealthReportTo => 'A scoped health report to share';

  @override
  String get deleteActivityDataX => 'Delete activity data';

  @override
  String get workoutsMetricsAndMedalsOn =>
      'Workouts, metrics and medals, on every device';

  @override
  String get selectAtLeastOneMetric => 'Select at least one metric.';

  @override
  String get shareReportX => 'Share Report';

  @override
  String get dateRange => 'Date range';

  @override
  String get change => 'Change';

  @override
  String get metricsToInclude => 'Metrics to include';

  @override
  String get theReportIsAPlain =>
      'The report is a plain-text file — not encrypted. Only share with people you trust. Informational only — not medical advice.';

  @override
  String get generating => 'Generating…';

  @override
  String get generateShare => 'Generate & Share';

  @override
  String get newTemplate => 'New Template';

  @override
  String get editTemplate => 'Edit Template';

  @override
  String get templateName => 'Template name';

  @override
  String get activityTypeX => 'Activity type';

  @override
  String get durationMin => 'Duration (min):';

  @override
  String get intensity110 => 'Intensity (1–10):';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get create => 'Create';

  @override
  String get deleteTemplate => 'Delete template?';

  @override
  String get workoutTemplatesX => 'Workout Templates';

  @override
  String get newTemplateX => 'New template';

  @override
  String get noTemplatesYet => 'No templates yet';

  @override
  String get createYourFirstTemplate => 'Create your first template';

  @override
  String get syncing => 'Syncing…';

  @override
  String get notSynced => 'Not synced';

  @override
  String get synced => 'Synced';

  @override
  String get syncPending => 'Sync pending';

  @override
  String get vaultUnlocked => 'Vault unlocked';

  @override
  String get vaultIsUnlockedAndData =>
      'Vault is unlocked and data is accessible';

  @override
  String get vaultIsLockedTapUnlock =>
      'Vault is locked — tap Unlock to access data';

  @override
  String get gpsActive => 'GPS active';

  @override
  String get gpsTrackingIsActive => 'GPS tracking is active';

  @override
  String get stepsToday => 'Steps Today';

  @override
  String get heartToday => 'Heart Today';

  @override
  String get keyMetrics => 'Key Metrics';

  @override
  String get moreMetrics => 'More metrics';

  @override
  String get water => 'Water';

  @override
  String get foodEntry => 'Food entry';

  @override
  String get foodEntries => 'Food entries';

  @override
  String get gpsWorkoutActive => 'GPS Workout Active';

  @override
  String get startGpsWorkout => 'Start GPS Workout';

  @override
  String get trackRoutePaceDistance => 'Track route, pace & distance';

  @override
  String get lockVault => 'Lock vault';

  @override
  String get trendData => 'trend data';

  @override
  String get s30DayBaselines => '30-Day Baselines';

  @override
  String get sleepSteps => 'Sleep & Steps';

  @override
  String get stepsHeartPointsTodayHourly =>
      'Steps & Heart Points (Today, Hourly)';

  @override
  String get stepsHeartPointsThisWeek => 'Steps & Heart Points (This Week)';

  @override
  String get stepsHeartPointsLast30 => 'Steps & Heart Points (Last 30 Days)';

  @override
  String get selectedMetricWeek => 'Selected Metric (Week)';

  @override
  String get selectedMetricMonth => 'Selected Metric (Month)';

  @override
  String get analytics => 'Analytics';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get informational => 'Informational';

  @override
  String get notMedicalAdviceBasedOn =>
      'Not medical advice · based on your logged data';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get snacks => 'Snacks';

  @override
  String get addWater => 'Add water';

  @override
  String get add => 'Add';

  @override
  String get waterFood => 'Water & food';

  @override
  String get food => 'Food';

  @override
  String get unlockToLogWaterAnd => 'Unlock to log water and food.';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get last7DaysX => 'Last 7 days';

  @override
  String get logAgain => 'Log again';

  @override
  String get logFood => 'Log food';

  @override
  String get nothingLogged => 'Nothing logged';

  @override
  String get editFood => 'Edit food';

  @override
  String get whatDidYouEat => 'What did you eat?';

  @override
  String get calories => 'Calories';

  @override
  String get protein => 'Protein';

  @override
  String get carbs => 'Carbs';

  @override
  String get fat => 'Fat';

  @override
  String get caloriesAndMacrosAreOptional =>
      'Calories and macros are optional.';

  @override
  String get actRunning => 'Running';

  @override
  String get actCycling => 'Cycling';

  @override
  String get actSwimming => 'Swimming';

  @override
  String get actWalking => 'Walking';

  @override
  String get actHiking => 'Hiking';

  @override
  String get actStrengthTraining => 'Strength Training';

  @override
  String get actYogaStretching => 'Yoga/Stretching';

  @override
  String get actOther => 'Other';

  @override
  String get actStrength => 'Strength';

  @override
  String get actHiit => 'HIIT';

  @override
  String get actYoga => 'Yoga';

  @override
  String get srcManual => 'MANUAL';

  @override
  String get srcHealth => 'HEALTH';

  @override
  String get srcGoogleFit => 'GOOGLE FIT';

  @override
  String medalUnlocked(String name) {
    return 'Medal unlocked: $name!';
  }

  @override
  String percentOfGoal(int percent) {
    return '$percent% of goal';
  }

  @override
  String noMetricData(String metric) {
    return 'No $metric data';
  }

  @override
  String metricAccessNotGranted(String metric) {
    return '$metric access is not granted. Enable it in Permissions.';
  }

  @override
  String metricNotSupported(String metric) {
    return '$metric is not supported on this device.';
  }

  @override
  String vsLastWeek(String change) {
    return '$change vs last week';
  }

  @override
  String bestStreak(int count) {
    return 'Best: $count';
  }

  @override
  String templateSummary(String activity, int minutes, int intensity) {
    return '$activity · $minutes min · intensity $intensity/10';
  }

  @override
  String failedToSave(String error) {
    return 'Failed to save: $error';
  }

  @override
  String heartPointsEarnedPreview(int count) {
    return '≈ $count heart points earned';
  }

  @override
  String morePointsToTarget(int count) {
    return '$count more Heart Points to hit today\'s target.';
  }

  @override
  String momentumExplained(int target) {
    return 'Your daily target starts at $target Heart Points (about 150 a week, the WHO activity guideline) and adapts to you: hit it and it grows 5%; fall below half of it and it eases 3%.\n\nMomentum (0-100) is how close you came to your target over the last 7 days, with recent days counting most. Missing a day lowers it a little instead of resetting it, and today can only push it up.\n\nEverything is calculated on this device.';
  }

  @override
  String gainedToday(int count) {
    return '+$count today';
  }

  @override
  String pointsOfTarget(int points, int target) {
    return '$points / $target pts';
  }

  @override
  String changeUp(int percent) {
    return ' (up $percent%)';
  }

  @override
  String changeDown(int percent) {
    return ' (down $percent%)';
  }

  @override
  String yourWeekActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your week: $count active days',
      one: 'Your week: 1 active day',
    );
    return '$_temp0';
  }

  @override
  String nHeartPoints(String count) {
    return '$count Heart Points';
  }

  @override
  String nSteps(String count) {
    return '$count steps';
  }

  @override
  String nWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts',
      one: '1 workout',
    );
    return '$_temp0';
  }

  @override
  String throughDay(String day) {
    return ' (through $day)';
  }

  @override
  String cueSplitKm(int count, String total, String split) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kilometres',
      one: '1 kilometre',
    );
    return '$_temp0. Time $total. Split $split per kilometre.';
  }

  @override
  String cueSplitMile(int count, String total, String split) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miles',
      one: '1 mile',
    );
    return '$_temp0. Time $total. Split $split per mile.';
  }

  @override
  String cueLap(int index, String time) {
    return 'Lap $index. $time.';
  }

  @override
  String spokenHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String spokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String spokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String activityAutoPaused(String activity) {
    return '$activity · auto-paused';
  }

  @override
  String activityPaused(String activity) {
    return '$activity · paused';
  }

  @override
  String unlockedOn(String date) {
    return 'Unlocked on $date';
  }

  @override
  String percentToward(int percent, String name) {
    return '$percent% toward $name';
  }

  @override
  String restoredSummary(int workouts, int days, int goals) {
    return 'Restored $workouts workouts, $days days of metrics, $goals goals.';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String goalSavedFor(String metric) {
    return 'Goal saved for $metric';
  }

  @override
  String failedToLoadGoals(String error) {
    return 'Failed to load goals: $error';
  }

  @override
  String get targetLabel => 'Target';

  @override
  String couldntReadThatFile(String error) {
    return 'Couldn\'t read that file ($error).';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String addedWorkoutsAndDays(int workouts, int days) {
    return 'Added $workouts workouts and $days days';
  }

  @override
  String workoutsAlreadyHere(int count) {
    return '$count workouts were already here';
  }

  @override
  String daysOfStepsAndPoints(int count) {
    return '$count days of steps and Heart Points';
  }

  @override
  String dateRangeTo(String from, String to) {
    return ' ($from to $to)';
  }

  @override
  String couldntStart(String error) {
    return 'Couldn\'t start: $error';
  }

  @override
  String workoutSavedDistance(String distance, String time) {
    return 'Workout saved: $distance in $time';
  }

  @override
  String get cuesEveryKm => 'Time and pace every kilometre';

  @override
  String get cuesEveryMile => 'Time and pace every mile';

  @override
  String lastSplit(String unit, String time) {
    return 'Last $unit: $time';
  }

  @override
  String couldntReadAsGpx(String files) {
    return 'Couldn\'t read $files as GPX.';
  }

  @override
  String skippedNotGpx(String files) {
    return 'Skipped $files: not GPX.';
  }

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count workouts. You\'ll find them in your Journal.',
      one: 'Imported 1 workout. You\'ll find it in your Journal.',
    );
    return '$_temp0';
  }

  @override
  String nPoints(int count) {
    return '$count points';
  }

  @override
  String nMin(int count) {
    return '$count min';
  }

  @override
  String importNWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count workouts',
      one: 'Import 1 workout',
    );
    return '$_temp0';
  }

  @override
  String nothingMatches(String query) {
    return 'Nothing matches \"$query\"';
  }

  @override
  String nPts(int count) {
    return '$count pts';
  }

  @override
  String deleteThisItem(String name) {
    return 'Delete this $name?';
  }

  @override
  String itsPointsComeOff(int count) {
    return 'Its $count Heart Points come off that day too. This deletes it on all your devices.';
  }

  @override
  String lapN(int index) {
    return 'Lap $index';
  }

  @override
  String deleteThisEntry(String name) {
    return 'Delete this $name entry?';
  }

  @override
  String editItem(String name) {
    return 'Edit $name';
  }

  @override
  String goalPeriod(String period) {
    return 'Goal ($period)';
  }

  @override
  String savedMapTiles(int count) {
    return 'Saved $count map tiles.';
  }

  @override
  String get mapTilesCapped =>
      ' That\'s the most at once; run it again later for the rest.';

  @override
  String areasAroundRoutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The areas around your $count routes, ready offline',
      one: 'The areas around your route, ready offline',
    );
    return '$_temp0';
  }

  @override
  String tilesAndSize(int count, String size) {
    return '$count tiles, $size';
  }

  @override
  String permissionActionFailed(String error) {
    return 'Permission action failed: $error';
  }

  @override
  String nOfMGranted(int granted, int total) {
    return '$granted / $total granted';
  }

  @override
  String healthDidntAllow(String health) {
    return '$health didn\'t allow Fitness to save workouts.';
  }

  @override
  String newWorkoutsSavedTo(String health) {
    return 'New workouts are saved to $health from now on. Fitness can also copy the workouts already in your journal.';
  }

  @override
  String copiedWorkoutsTo(int count, String health) {
    return 'Copied $count workouts to $health.';
  }

  @override
  String viewAllCount(int count) {
    return 'View All ($count)';
  }

  @override
  String get unitMetric => 'Metric';

  @override
  String get unitImperial => 'Imperial';

  @override
  String failedError(String error) {
    return 'Failed: $error';
  }

  @override
  String deleteNamedCannotUndo(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String addWaterAmount(String amount) {
    return 'Add $amount of water';
  }

  @override
  String restingHrAvg(String bpm) {
    return 'Resting HR avg: $bpm bpm';
  }

  @override
  String dailyStepsAvg(String steps) {
    return 'Daily steps avg: $steps';
  }

  @override
  String sleepStepsCorrelation(String strength, String direction) {
    String _temp0 = intl.Intl.selectLogic(strength, {
      'strong': 'strong',
      'moderate': 'moderate',
      'other': 'weak',
    });
    String _temp1 = intl.Intl.selectLogic(direction, {
      'positive': 'positive',
      'other': 'negative',
    });
    return 'Your sleep duration shows a $_temp0 $_temp1 correlation with your daily step count.';
  }

  @override
  String loggedName(String name) {
    return 'Logged $name';
  }

  @override
  String ofGoalAmount(String amount) {
    return 'of $amount';
  }

  @override
  String waterLoggedHereAndHealth(String here, String health) {
    return '$here logged here · $health from your health app';
  }

  @override
  String takeOffAmount(String amount) {
    return 'Take off $amount';
  }

  @override
  String get kcalUnit => 'kcal';

  @override
  String get proteinShort => 'protein';

  @override
  String get carbsShort => 'carbs';

  @override
  String get fatShort => 'fat';

  @override
  String plusHealthEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Plus $count entries from your health app.',
      one: 'Plus 1 entry from your health app.',
    );
    return '$_temp0';
  }

  @override
  String get medalFirstSteps => 'First Steps';

  @override
  String get medalFirstStepsDesc => 'Log your first steps data.';

  @override
  String get medalStepSeeker => 'Step Seeker';

  @override
  String get medalStepSeekerDesc => 'Walk 5,000 steps in a single day.';

  @override
  String get medalStepChampion => 'Step Champion';

  @override
  String get medalStepChampionDesc => 'Walk 10,000 steps in a single day.';

  @override
  String get medalStepLegend => 'Step Legend';

  @override
  String get medalStepLegendDesc => 'Walk 20,000 steps in a single day.';

  @override
  String get medalHeartStarter => 'Heart Starter';

  @override
  String get medalHeartStarterDesc => 'Earn 10 heart points in a single day.';

  @override
  String get medalHeartWarrior => 'Heart Warrior';

  @override
  String get medalHeartWarriorDesc => 'Earn 25 heart points in a single day.';

  @override
  String get medalHeartLegend => 'Heart Legend';

  @override
  String get medalHeartLegendDesc => 'Earn 50 heart points in a single day.';

  @override
  String get medalActiveWeek => 'Active Week';

  @override
  String get medalActiveWeekDesc =>
      'Earn 150 heart points across any 7-day period.';

  @override
  String get medalOnTarget => 'On Target';

  @override
  String get medalOnTargetDesc =>
      'Hit your daily Heart Points target for the first time.';

  @override
  String get medalTargetStreak3 => 'Hat Trick';

  @override
  String get medalTargetStreak3Desc => 'Hit your daily target 3 days in a row.';

  @override
  String get medalTargetStreak7 => 'Locked In';

  @override
  String get medalTargetStreak7Desc => 'Hit your daily target 7 days in a row.';

  @override
  String get medalComeback => 'Comeback';

  @override
  String get medalComebackDesc =>
      'Hit your target after 3 or more days without hitting it.';

  @override
  String get medalTarget40 => 'Raising the Bar';

  @override
  String get medalTarget40Desc => 'Grow your daily target to 40 Heart Points.';

  @override
  String get medalMomentum50 => 'Steady';

  @override
  String get medalMomentum50Desc => 'Reach a Momentum score of 50.';

  @override
  String get medalMomentum75 => 'Unstoppable';

  @override
  String get medalMomentum75Desc => 'Reach a Momentum score of 75.';

  @override
  String get medalMomentumWeek75 => 'Perpetual Motion';

  @override
  String get medalMomentumWeek75Desc =>
      'End 7 days in a row with Momentum of 75 or higher.';

  @override
  String get medalNightLogged => 'Night Logged';

  @override
  String get medalNightLoggedDesc => 'Log sleep data for the first time.';

  @override
  String get medalWellRested => 'Well Rested';

  @override
  String get medalWellRestedDesc => 'Get 7+ hours of sleep in a single night.';

  @override
  String get medalDeepDreamer => 'Deep Dreamer';

  @override
  String get medalDeepDreamerDesc =>
      'Get 1+ hour of deep sleep in a single night.';

  @override
  String get medalSleepChampion => 'Sleep Champion';

  @override
  String get medalSleepChampionDesc =>
      'Get 8+ hours of sleep in a single night.';

  @override
  String get medalHydrated => 'Hydrated';

  @override
  String get medalHydratedDesc => 'Log 2+ litres of water in a single day.';

  @override
  String get medalHealthyHeart => 'Healthy Heart';

  @override
  String get medalHealthyHeartDesc =>
      'Record a resting heart rate of 60 bpm or lower.';

  @override
  String get medalOxygenCheck => 'Oxygen Check';

  @override
  String get medalOxygenCheckDesc => 'Log blood oxygen (SpO2) data.';

  @override
  String get medalFirstSync => 'First Sync';

  @override
  String get medalFirstSyncDesc => 'Sync your health data for the first time.';

  @override
  String get medalDedicated => 'Dedicated';

  @override
  String get medalDedicatedDesc => 'Sync data on 7 different days.';

  @override
  String get medalCommitted => 'Committed';

  @override
  String get medalCommittedDesc => 'Sync data on 30 different days.';

  @override
  String get medalStepMillionaire => 'Step Millionaire';

  @override
  String get medalStepMillionaireDesc => 'Walk a total of 1,000,000 steps.';

  @override
  String get medalElite => 'Elite';

  @override
  String get medalEliteDesc => 'Earn a total of 1,000 heart points.';

  @override
  String get medalStreak3 => 'Consistent';

  @override
  String get medalStreak3Desc => 'Log your health data 3 days in a row.';

  @override
  String get medalStreak7 => 'Week Streak';

  @override
  String get medalStreak7Desc => 'Log your health data every day for a week.';

  @override
  String get medalStreak30 => 'Iron Habit';

  @override
  String get medalStreak30Desc => 'Log your health data every day for 30 days.';

  @override
  String get widgetHeartPts => 'Heart Pts';

  @override
  String get widgetLocked => 'Open ZT Fitness to see today';

  @override
  String get widgetLockedShort => 'Locked';

  @override
  String get widgetHpGoal => 'of %1\$s Heart Pts';

  @override
  String get widgetStepsGoal => 'of %1\$s steps';

  @override
  String get widgetMomentum => 'Momentum %1\$s';

  @override
  String get widgetSummary =>
      '%1\$s of %2\$s Heart Points, %3\$s of %4\$s steps';

  @override
  String get challenges => 'Challenges';

  @override
  String get challengesSubtitle => 'Compete with friends, end-to-end encrypted';

  @override
  String get challengeSyncNow => 'Sync now';

  @override
  String get challengeNeedsInternet =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String challengeJoinRequest(String name, String title) {
    return '$name wants to join $title';
  }

  @override
  String get challengeJoinRequestHint => 'Tap to compare codes and let them in';

  @override
  String get challengeActive => 'Running now';

  @override
  String get challengeUpcoming => 'Starting soon';

  @override
  String get challengeFinished => 'Finished';

  @override
  String get challengeCreate => 'Start a challenge';

  @override
  String get challengeJoin => 'Join with an invite';

  @override
  String get challengeEmptyTitle => 'Challenge your friends';

  @override
  String get challengeEmptyBody =>
      'Race friends on steps or Heart Points for a few days or a month, and see who\'s ahead.';

  @override
  String get challengePrivacy =>
      'Friends see only one number per challenge: your total. It\'s encrypted for the people in the challenge, and the server can\'t read it.';

  @override
  String get challengeWaitingTitle => 'Waiting for the organiser';

  @override
  String get challengeWaitingBody =>
      'You\'ll see the challenge once they confirm your code.';

  @override
  String get challengeYourCode => 'Your code:';

  @override
  String challengeGoalMostSummary(String metric) {
    return 'Most $metric';
  }

  @override
  String challengeGoalDaysSummary(String target, String metric) {
    return 'Days with $target $metric';
  }

  @override
  String challengeStarts(String date) {
    return 'Starts $date';
  }

  @override
  String challengeDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String challengeEnded(String date) {
    return 'Ended $date';
  }

  @override
  String challengeYourRank(int rank, int count) {
    return '#$rank of $count';
  }

  @override
  String get challengeGone => 'You\'re no longer in this challenge.';

  @override
  String get challengeInvite => 'Invite a friend';

  @override
  String get challengeEdit => 'Edit challenge';

  @override
  String get challengeLeave => 'Leave';

  @override
  String get challengeDelete => 'Delete';

  @override
  String challengeDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String get challengeLeaderboard => 'Leaderboard';

  @override
  String challengeDaysUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String challengeTotalDetail(String total, String metric) {
    return '$total $metric in total';
  }

  @override
  String get challengeInviteHint => 'Invite friends to see them here.';

  @override
  String challengeWhatIsShared(String metric) {
    return 'Shared with this challenge: only your $metric total for its days (and how many days met the target). Your other data, workouts and locations stay private.';
  }

  @override
  String get challengeDeleteTitle => 'Delete this challenge?';

  @override
  String get challengeDeleteBody =>
      'It\'s removed for everyone in it, with all its results.';

  @override
  String get challengeLeaveTitle => 'Leave this challenge?';

  @override
  String get challengeLeaveBody =>
      'Your total is removed from the board and this phone stops sharing with it. You can rejoin with a new invite.';

  @override
  String challengeRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get challengeRemoveBody =>
      'They leave the challenge and can\'t read anything shared from now on.';

  @override
  String get challengeRemove => 'Remove';

  @override
  String challengeYou(String name) {
    return '$name (you)';
  }

  @override
  String get challengeNoDataYet => 'No data yet';

  @override
  String get challengeTitle => 'Name';

  @override
  String get challengeTitleHint => 'e.g. November step-off';

  @override
  String get challengeRequired => 'Required';

  @override
  String get challengeMeasure => 'What counts';

  @override
  String get challengeWinBy => 'How to win';

  @override
  String get challengeGoalMost => 'Highest total';

  @override
  String get challengeGoalDays => 'Daily target';

  @override
  String get challengeGoalMostHint =>
      'Whoever has the most by the last day wins.';

  @override
  String get challengeGoalDaysHint =>
      'Whoever reaches the daily target on the most days wins. Ties go to the higher total.';

  @override
  String challengeDailyTarget(String metric) {
    return 'Daily target ($metric)';
  }

  @override
  String get challengeStartDate => 'Starts';

  @override
  String get challengeLength => 'Length';

  @override
  String challengeLengthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get challengeYourName => 'Your name in challenges';

  @override
  String get challengeYourNameHint => 'What friends in the challenge see';

  @override
  String get challengeCreateAndInvite => 'Create and invite friends';

  @override
  String challengeInviteTo(String title) {
    return 'Invite to $title';
  }

  @override
  String get challengeInviteIntro =>
      'Make a one-time invite: send the link, or let a friend scan the QR code. Each invite works for one person, for 7 days.';

  @override
  String get challengeCreateInvite => 'Create invite';

  @override
  String get challengeInviteReady =>
      'Send this link, or let your friend scan the code with ZT Fitness.';

  @override
  String get challengeInviteQr => 'Invite QR code';

  @override
  String get challengeLinkCopied => 'Link copied';

  @override
  String get challengeCopyLink => 'Copy link';

  @override
  String get challengeShareLink => 'Share';

  @override
  String challengeInviteMessage(String title, String link) {
    return 'Join my fitness challenge \"$title\" in ZT Fitness: $link';
  }

  @override
  String get challengeInviteNextSteps =>
      'When your friend opens it, they\'ll see a code. Check it matches the code on your phone before letting them in: that\'s what keeps a stranger with the link out.';

  @override
  String get challengeCheckAnswers => 'Check for answers';

  @override
  String get challengeAnotherInvite => 'Invite someone else';

  @override
  String challengeConfirmTitle(String name) {
    return 'Let $name in?';
  }

  @override
  String get challengeConfirmBody =>
      'Check this code matches the one on their phone.';

  @override
  String get challengeCodesDiffer => 'Codes differ';

  @override
  String get challengeLater => 'Later';

  @override
  String get challengeCodesMatch => 'Codes match';

  @override
  String challengeJoined(String name) {
    return '$name joined';
  }

  @override
  String get challengeInviteOtherApp =>
      'This invite is for another Zero-Trust app.';

  @override
  String get challengeInviteInvalid => 'That isn\'t a challenge invite link.';

  @override
  String get challengeInviteUsed =>
      'This invite was already used or has expired. Ask for a new one.';

  @override
  String get challengeJoinCodeTitle => 'Show this code to the organiser';

  @override
  String get challengeJoinCodeBody =>
      'They\'ll see the same code on their phone. Once they confirm, the challenge appears here.';

  @override
  String get challengeDone => 'Done';

  @override
  String get challengeJoinIntro =>
      'Paste the invite link a friend sent you, or scan their QR code.';

  @override
  String get challengeInviteLink => 'Invite link';

  @override
  String get challengeScanQr => 'Scan QR code';

  @override
  String get challengeJoinPrivacy =>
      'Joining shares only your total for the challenge\'s measure and days. You can leave at any time.';

  @override
  String get challengeJoinButton => 'Join';
}
