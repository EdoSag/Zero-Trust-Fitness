// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get couldntOpenYourFitnessData =>
      'לא ניתן לפתוח את נתוני הכושר במכשיר הזה.';

  @override
  String get tryAgain => 'לנסות שוב';

  @override
  String get openingYourFitnessData => 'פותח את נתוני הכושר…';

  @override
  String get connectYourHealthData => 'לחבר את נתוני הבריאות?';

  @override
  String get fitnessCanReadStepsWorkouts =>
      'Fitness יכולה לקרוא צעדים, אימונים, דופק, שינה ועוד מ-Health Connect. הנתונים נשארים מוצפנים בטלפון ובכספת שלך. אפשר לשנות את זה בכל עת בהגדרות.';

  @override
  String get notNow => 'לא עכשיו';

  @override
  String get choosePermissions => 'בחירת הרשאות';

  @override
  String get today => 'היום';

  @override
  String get trends => 'מגמות';

  @override
  String get journal => 'יומן';

  @override
  String get settings => 'הגדרות';

  @override
  String get syncFromHealthConnectOr =>
      'אפשר לסנכרן מ-Health Connect או להזין רשומה ידנית.';

  @override
  String get permissionRequired => 'נדרשת הרשאה';

  @override
  String get grantPermission => 'מתן הרשאה';

  @override
  String get notTracked => 'לא נמדד';

  @override
  String get vaultLocked => 'הכספת נעולה';

  @override
  String get unlockYourVaultToSee =>
      'כדי לראות את נתוני הבריאות יש לפתוח את הכספת.';

  @override
  String get unlock => 'פתיחה';

  @override
  String get retry => 'לנסות שוב';

  @override
  String get noPriorWeekData => 'אין נתונים מהשבוע הקודם';

  @override
  String get dayStreak => 'ימים ברצף';

  @override
  String get personalBest => 'שיא אישי!';

  @override
  String get stepsThisWeek => 'צעדים השבוע';

  @override
  String get activity => 'פעילות';

  @override
  String get steps => 'צעדים';

  @override
  String get heartPoints => 'נקודות לב';

  @override
  String get sleep => 'שינה';

  @override
  String get totalSleep => 'סך השינה';

  @override
  String get lightSleep => 'שינה קלה';

  @override
  String get deepSleep => 'שינה עמוקה';

  @override
  String get remSleep => 'שינת REM';

  @override
  String get vitals => 'מדדים חיוניים';

  @override
  String get restingHr => 'דופק במנוחה';

  @override
  String get respiratoryRate => 'קצב נשימה';

  @override
  String get bloodOxygen => 'חמצן בדם';

  @override
  String get bpSystolic => 'לחץ דם סיסטולי';

  @override
  String get bpDiastolic => 'לחץ דם דיאסטולי';

  @override
  String get bloodGlucose => 'סוכר בדם';

  @override
  String get body => 'גוף';

  @override
  String get weight => 'משקל';

  @override
  String get bodyFat => 'אחוז שומן';

  @override
  String get lifestyle => 'אורח חיים';

  @override
  String get hydration => 'שתייה';

  @override
  String get nutrition => 'תזונה';

  @override
  String get noTemplatesYetCreateOne =>
      'אין עדיין תבניות. אפשר ליצור תבנית בהגדרות ← תבניות אימון.';

  @override
  String get chooseATemplate => 'בחירת תבנית';

  @override
  String get enterAtLeastOneWorkout => 'יש להזין לפחות אימון אחד או מדד אחד.';

  @override
  String get vaultIsLockedUnlockBefore =>
      'הכספת נעולה. יש לפתוח אותה לפני השמירה.';

  @override
  String get logHealthData => 'רישום נתוני בריאות';

  @override
  String get allDataIsEncryptedBefore =>
      'כל הנתונים מוצפנים לפני שהם יוצאים מהמכשיר.';

  @override
  String get workout => 'אימון';

  @override
  String get healthMetrics => 'מדדי בריאות';

  @override
  String get useTemplate => 'שימוש בתבנית';

  @override
  String get activityType => 'סוג פעילות';

  @override
  String get duration => 'משך';

  @override
  String get minutes => 'דקות';

  @override
  String get intensity => 'עצימות';

  @override
  String get light => 'קלה';

  @override
  String get moderate => 'בינונית';

  @override
  String get vigorous => 'גבוהה';

  @override
  String get lightIntensityNoHeartPoints => 'עצימות קלה, ללא נקודות לב';

  @override
  String get addsToExisting => 'מתווסף לקיים';

  @override
  String get replacesExisting => 'מחליף את הקיים';

  @override
  String get encryptVaultData => 'הצפנה ושמירה בכספת';

  @override
  String get targetHitTomorrowsTargetGrows =>
      'היעד הושג! היעד של מחר יגדל ב-5%.';

  @override
  String get momentum => 'מומנטום';

  @override
  String get howMomentumWorks => 'איך מומנטום עובד';

  @override
  String get todaysTarget => 'היעד של היום';

  @override
  String get gotIt => 'הבנתי';

  @override
  String get howZeroTrustWorks => 'איך Zero-Trust עובד';

  @override
  String get localFirstStorage => 'אחסון מקומי קודם כול';

  @override
  String get allYourHealthDataIs =>
      'כל נתוני הבריאות שלך מוצפנים עם SQLCipher ונשמרים רק במכשיר. שום דבר לא מועלה אלא אם בוחרים לסנכרן.';

  @override
  String get yourPasswordYourData => 'הסיסמה שלך, הנתונים שלך';

  @override
  String get yourMasterPasswordDerivesThe =>
      'מפתח ההצפנה נגזר מהסיסמה הראשית במכשיר עצמו (PBKDF2). הסיסמה והמפתח לעולם לא יוצאים מהמכשיר.';

  @override
  String get endToEndEncryptedBackups => 'גיבויים מוצפנים מקצה לקצה';

  @override
  String get ifYouChooseToSync =>
      'אם בוחרים לסנכרן, הנתונים מוצפנים במכשיר לפני ההעלאה. השרת שומר רק מידע מוצפן שהוא לא יכול לקרוא.';

  @override
  String get biometricUnlock => 'פתיחה ביומטרית';

  @override
  String get biometricUnlockStoresOnlyA =>
      'פתיחה ביומטרית שומרת רק הפניה לסיסמה באזור המאובטח של מערכת ההפעלה. מערכת הביומטריה אף פעם לא ניגשת לנתוני הבריאות עצמם.';

  @override
  String get optInPermissions => 'הרשאות לפי בחירה';

  @override
  String get healthConnectAndLocationPermissions =>
      'הרשאות Health Connect ומיקום הן תמיד לפי בחירה וניתנות לביטול. בידיים שלך אילו מדדים נקראים.';

  @override
  String get thisWeek => 'השבוע';

  @override
  String get thisWeekSoFar => 'השבוע עד עכשיו';

  @override
  String get vsTheWeekBefore => 'לעומת השבוע הקודם';

  @override
  String get activeDays => 'ימים פעילים';

  @override
  String get timeToMove => 'הגיע הזמן לזוז!';

  @override
  String get movementReminders => 'תזכורות תנועה';

  @override
  String get stayHydrated => 'לא לשכוח לשתות!';

  @override
  String get drinkAGlassOfWater => 'כוס מים תעזור לשמור על השתייה.';

  @override
  String get hydrationReminders => 'תזכורות שתייה';

  @override
  String get workoutTime => 'זמן אימון!';

  @override
  String get workoutReminders => 'תזכורות אימון';

  @override
  String get bedtimeSoon => 'עוד מעט שעת שינה';

  @override
  String get windingDownNowSupportsBetter =>
      'הירגעות עכשיו תורמת לשינה טובה יותר.';

  @override
  String get sleepReminders => 'תזכורות שינה';

  @override
  String get weeklyCheckIn => 'בדיקה שבועית';

  @override
  String get timeToLogYourWeight => 'הגיע הזמן לרשום משקל או מדידות אחרות.';

  @override
  String get measurementReminders => 'תזכורות מדידה';

  @override
  String get weeklySummary => 'סיכום שבועי';

  @override
  String get yourWeekOfHeartPoints => 'השבוע שלך בנקודות לב ובצעדים, בימי שני';

  @override
  String get youHaventBeenActiveIn => 'לא זזת כבר זמן מה. גם הליכה קצרה נחשבת.';

  @override
  String get yourScheduledWorkoutIsToday =>
      'האימון המתוכנן שלך היום. יוצאים לדרך.';

  @override
  String get noInternetConnectionCheckYour =>
      'אין חיבור לאינטרנט. כדאי לבדוק את הרשת ולנסות שוב.';

  @override
  String get signInFailedCheckYour =>
      'ההתחברות נכשלה. כדאי לבדוק את האימייל והסיסמה.';

  @override
  String get accessDeniedPleaseSignIn => 'הגישה נדחתה. יש להתחבר שוב.';

  @override
  String get serverErrorPleaseTryAgain => 'שגיאת שרת. כדאי לנסות שוב בעוד רגע.';

  @override
  String get cloudBackupIsUnreadableIt =>
      'לא ניתן לקרוא את הגיבוי בענן. ייתכן שנוצר עם סיסמה אחרת.';

  @override
  String get vaultCouldNotBeOpened =>
      'לא ניתן לפתוח את הכספת. ייתכן שהסיסמה הראשית שגויה.';

  @override
  String get locationPermissionRequiredForGps => 'מעקב GPS דורש הרשאת מיקום.';

  @override
  String get requestTimedOutCheckYour =>
      'הבקשה ארכה יותר מדי. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get somethingWentWrongPleaseTry => 'משהו השתבש. כדאי לנסות שוב.';

  @override
  String get fitness => 'כושר';

  @override
  String get health => 'בריאות';

  @override
  String get milestones => 'אבני דרך';

  @override
  String get unlocked => 'נפתחו';

  @override
  String get keepGoing => 'להמשיך כך!';

  @override
  String get achievements => 'הישגים';

  @override
  String get all => 'הכול';

  @override
  String get locked => 'נעולים';

  @override
  String get sleepAsleep => 'שינה';

  @override
  String get sleepLight => 'שינה קלה';

  @override
  String get sleepDeep => 'שינה עמוקה';

  @override
  String get sleepRem => 'שינת REM';

  @override
  String get respiratory => 'נשימה';

  @override
  String get glucose => 'סוכר';

  @override
  String get workoutPaused => 'האימון הושהה.';

  @override
  String get workoutResumed => 'האימון חודש.';

  @override
  String get gpsWorkout => 'אימון GPS';

  @override
  String get timeDistanceAndControlsWhile => 'זמן, מרחק ופקדים בזמן ההקלטה';

  @override
  String get resume => 'המשך';

  @override
  String get pause => 'השהיה';

  @override
  String get lap => 'הקפה';

  @override
  String get unstoppable => 'בלתי ניתן לעצירה';

  @override
  String get steady => 'יציב';

  @override
  String get building => 'בבנייה';

  @override
  String get gettingStarted => 'בהתחלה';

  @override
  String get bringingOverYourDataFrom => 'מעביר את הנתונים מהגרסה הקודמת…';

  @override
  String get yourDataFromThePrevious =>
      'הנתונים מהגרסה הקודמת עדיין לא הועברו: לא ניתן היה להגיע לשרת. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get thatPasswordDidntOpenYour =>
      'גם הסיסמה הזו לא פתחה את הנתונים מהגרסה הקודמת. אפשר לנסות סיסמה אחרת שהייתה בשימוש, או לדלג.';

  @override
  String get yourDataFromThePreviousX =>
      'הנתונים מהגרסה הקודמת נעולים בסיסמה שהייתה לך לפני העדכון. יש להזין אותה פעם אחת כדי להעביר אותם.';

  @override
  String get skip => 'דילוג';

  @override
  String get enterPassword => 'הזנת סיסמה';

  @override
  String get yourDataFromThePreviousXX =>
      'הנתונים מהגרסה הקודמת עדיין לא הועברו. משהו השתבש; כדאי לנסות שוב.';

  @override
  String get skipTheLockedData => 'לדלג על הנתונים הנעולים?';

  @override
  String get whateverNoPasswordOpenedStays =>
      'מה שאף סיסמה לא פתחה נשאר במקומו (הקובץ הישן נשמר בטלפון) אבל לא יוצג באפליקציה. כל השאר מהגרסה הקודמת מועבר.';

  @override
  String get cancel => 'ביטול';

  @override
  String get yourDataFromThePreviousXXX => 'הנתונים מהגרסה הקודמת כאן.';

  @override
  String get stillCouldntReachTheServer =>
      'עדיין אין גישה לשרת. כדאי לבדוק את החיבור.';

  @override
  String get thatPasswordDidntOpenIt =>
      'הסיסמה הזו לא פתחה אותם. אפשר לנסות סיסמה אחרת שהייתה בשימוש.';

  @override
  String get thatDidntWorkTryAgain => 'זה לא עבד. כדאי לנסות שוב בעוד רגע.';

  @override
  String get passwordFromBeforeTheUpdate => 'הסיסמה מלפני העדכון';

  @override
  String get thePasswordZeroTrustFitness =>
      'הסיסמה שהייתה ב-Zero-Trust Fitness לפני העדכון. היא רק פותחת את הנתונים הישנים בטלפון הזה; היא לא נשלחת לשום מקום ולא משנה את החשבון.';

  @override
  String get oldPassword => 'הסיסמה הישנה';

  @override
  String get showPassword => 'הצגת הסיסמה';

  @override
  String get hidePassword => 'הסתרת הסיסמה';

  @override
  String get sameAsLastWeek => ' (כמו בשבוע שעבר)';

  @override
  String get yourWeekInFitness => 'השבוע שלך ב-Fitness';

  @override
  String get noActivityLoggedThisWeek =>
      'לא נרשמה פעילות השבוע. הליכה קצרה היא התחלה טובה.';

  @override
  String get allMetrics => 'כל המדדים';

  @override
  String get logAWorkoutOrHealth => 'רישום אימון או מדד בריאות';

  @override
  String get couldNotReadSelectedFile => 'לא ניתן לקרוא את הקובץ שנבחר.';

  @override
  String get failedToReadFile => 'קריאת הקובץ נכשלה.';

  @override
  String get invalidOrUnsupportedExportFile =>
      'קובץ ייצוא לא תקין או לא נתמך (גרסה חדשה מדי?).';

  @override
  String get restoreFromBackup => 'לשחזר מהגיבוי?';

  @override
  String get workoutsMissingHereAreAdded =>
      'אימונים שחסרים כאן יתווספו, ימים בקובץ יחליפו את אותם ימים כאן, והיעדים יוגדרו. הכול יסונכרן למכשירים האחרים שלך.';

  @override
  String get exported => 'יוצא';

  @override
  String get workouts => 'אימונים';

  @override
  String get metricDays => 'ימי מדדים';

  @override
  String get goals => 'יעדים';

  @override
  String get restore => 'שחזור';

  @override
  String get exportRestore => 'ייצוא ושחזור';

  @override
  String get exportLabel => 'ייצוא';

  @override
  String get exportFullBackupJson => 'ייצוא גיבוי מלא (JSON)';

  @override
  String get allWorkoutsMetricsGoalsAnd =>
      'כל האימונים, המדדים, היעדים והמדליות. לא מוצפן: יש לשמור אותו במקום בטוח.';

  @override
  String get exportMetricsCsv => 'ייצוא מדדים (CSV)';

  @override
  String get dailyHealthMetricsAsA => 'מדדי בריאות יומיים כגיליון, לניתוח';

  @override
  String get restoreFromJson => 'שחזור מ-JSON';

  @override
  String get bringAFullBackupBack => 'החזרת גיבוי מלא. שום דבר כאן לא נמחק.';

  @override
  String get yourDataIsSyncedEnd =>
      'הנתונים מסונכרנים בהצפנה מקצה לקצה למכשירים האחרים שלך תוך כדי שימוש. כדי שתוכל/י להיכנס שוב אם הסיסמה תישכח, יש לשמור את מפתח השחזור במקום בטוח (הגדרות ← מפתח שחזור חדש).';

  @override
  String get enterAValidTargetValue => 'יש להזין ערך יעד תקין.';

  @override
  String get active => 'פעיל';

  @override
  String get period => 'תקופה';

  @override
  String get daily => 'יומי';

  @override
  String get weekly => 'שבועי';

  @override
  String get remove => 'הסרה';

  @override
  String get save => 'שמירה';

  @override
  String get noGoogleFitDataFound =>
      'לא נמצאו בקובץ נתוני Google Fit. יש לבחור את קובץ ה-ZIP של Takeout, או את הקובץ \"Daily activity metrics.csv\" מתיקיית Fit שבו.';

  @override
  String get importFromGoogleFit => 'ייבוא מ-Google Fit';

  @override
  String get bringYourGoogleFitHistory => 'העברת ההיסטוריה מ-Google Fit';

  @override
  String get s1GoToTakeoutGoogle =>
      '1. נכנסים ל-takeout.google.com ובוחרים רק את \"Fit\".\n2. מורידים את קובץ ה-ZIP ש-Google שולחת באימייל.\n3. בוחרים אותו כאן (או את \"Daily activity metrics.csv\" שבתוכו).';

  @override
  String get theFileIsReadOn =>
      'הקובץ נקרא בטלפון הזה. הצעדים, נקודות הלב, המשקל והאימונים נוספים לכספת המוצפנת, וימים שכבר נספרו לא נספרים פעמיים. ייבוא חוזר לא מוסיף דבר.';

  @override
  String get addingToYourVault => 'מוסיף לכספת…';

  @override
  String get readingTheExport => 'קורא את הקובץ…';

  @override
  String get done => 'סיום';

  @override
  String get found => 'נמצאו';

  @override
  String get importLabel => 'ייבוא';

  @override
  String get chooseAnotherFile => 'בחירת קובץ אחר';

  @override
  String get chooseTakeoutFile => 'בחירת קובץ Takeout';

  @override
  String get fitnessNeedsLocationAccessTo =>
      'כדי להקליט אימון GPS, Fitness צריכה גישה למיקום. אפשר לאשר אותה בהגדרות הטלפון.';

  @override
  String get finishWorkout => 'לסיים את האימון?';

  @override
  String get discardWorkout => 'למחוק את האימון?';

  @override
  String get itsSavedToYourJournal => 'הוא יישמר ביומן.';

  @override
  String get thisWorkoutWontBeSaved => 'האימון לא יישמר.';

  @override
  String get keepGoingX => 'להמשיך';

  @override
  String get finish => 'סיום';

  @override
  String get discard => 'מחיקה';

  @override
  String get vaultLockedWorkoutNotSaved => 'הכספת נעולה, האימון לא נשמר.';

  @override
  String get voiceCuesOn => 'הנחיות קוליות פועלות';

  @override
  String get voiceCuesOff => 'הנחיות קוליות כבויות';

  @override
  String get more => 'עוד';

  @override
  String get autoPause => 'השהיה אוטומטית';

  @override
  String get discardWorkoutX => 'מחיקת האימון';

  @override
  String get stopsTheClockWhenYou => 'עוצר את השעון כשמפסיקים לזוז';

  @override
  String get voiceCues => 'הנחיות קוליות';

  @override
  String get yourRouteStaysEncryptedIn =>
      'המסלול נשאר מוצפן בכספת. בזמן ההקלטה, התראה מציגה זמן ומרחק, עם כפתורי השהיה והקפה במסך הנעילה.';

  @override
  String get findingGps => 'מחפש GPS…';

  @override
  String get start => 'התחלה';

  @override
  String get autoPaused => 'הושהה אוטומטית';

  @override
  String get paused => 'מושהה';

  @override
  String get avgPace => 'קצב ממוצע';

  @override
  String get waitingForGps => 'ממתין ל-GPS…';

  @override
  String get noTracksWithAtLeast => 'אין בקובץ מסלולים עם שתי נקודות לפחות.';

  @override
  String get enterHowLongEachWorkout => 'יש להזין כמה זמן נמשך כל אימון.';

  @override
  String get importGpxRoutes => 'ייבוא מסלולי GPX';

  @override
  String get bringInWorkoutsFromStrava =>
      'ייבוא אימונים מ-Strava,‏ Komoot,‏ Garmin או כל אפליקציה שמייצאת קובצי GPX. הקובץ נקרא בטלפון הזה ונשמר מוצפן, כמו כל השאר.';

  @override
  String get chooseGpxFiles => 'בחירת קובצי GPX';

  @override
  String get track => 'מסלול';

  @override
  String get alreadyImported => 'כבר יובא';

  @override
  String get thisFileHasNoTimes =>
      'בקובץ אין זמנים. מתי זה היה, וכמה זמן זה נמשך?';

  @override
  String get countHeartPoints => 'ספירת נקודות לב';

  @override
  String get turnOffIfTheseWorkouts =>
      'כדאי לכבות אם האימונים האלה כבר נמצאים באפליקציית הבריאות, כדי שלא ייספרו פעמיים';

  @override
  String get yourDataYourKeysYour =>
      'הנתונים שלך, המפתחות שלך, הפרטיות שלך. מעקב אחר פעילות, אימונים ובריאות, בהצפנה בטלפון לפני כל סנכרון.';

  @override
  String get getStarted => 'מתחילים';

  @override
  String get learnMoreAboutZeroTrust => 'עוד על Zero-Trust';

  @override
  String get unknownDate => 'תאריך לא ידוע';

  @override
  String get yesterday => 'אתמול';

  @override
  String get nothingLoggedYet => 'עדיין לא נרשם דבר';

  @override
  String get workoutsAndMeasurementsYouLog =>
      'אימונים ומדידות שנרשמים, מוקלטים או מיובאים יופיעו כאן.';

  @override
  String get logAWorkoutOrMeasurement => 'רישום אימון או מדידה';

  @override
  String get searchTheJournal => 'חיפוש ביומן…';

  @override
  String get clear => 'ניקוי';

  @override
  String get measurements => 'מדידות';

  @override
  String get edit => 'עריכה';

  @override
  String get delete => 'מחיקה';

  @override
  String get thisDeletesItOnAll => 'הפעולה מוחקת אותו בכל המכשירים שלך.';

  @override
  String get distance => 'מרחק';

  @override
  String get avgPaceX => 'קצב ממוצע';

  @override
  String get splits => 'מקטעים';

  @override
  String get laps => 'הקפות';

  @override
  String get exportRouteGpx => 'ייצוא המסלול (GPX)';

  @override
  String get valuesFromHealthConnectFor =>
      'ערכים מ-Health Connect לאותו יום יישארו.';

  @override
  String get last7Days => '7 הימים האחרונים';

  @override
  String get s7DayAverage => 'ממוצע 7 ימים';

  @override
  String get s30DayAverage => 'ממוצע 30 יום';

  @override
  String get goal => 'יעד';

  @override
  String get notSet => 'לא הוגדר';

  @override
  String get setGoal => 'הגדרת יעד';

  @override
  String get sourceBreakdown => 'פילוח לפי מקור';

  @override
  String get manualEntries => 'רשומות ידניות';

  @override
  String get last30Days => '30 הימים האחרונים';

  @override
  String get yourRoutesMapsWereAlready =>
      'המפות של המסלולים כבר נמצאות בטלפון.';

  @override
  String get offlineMaps => 'מפות אופליין';

  @override
  String get routeMapsComeFromOpenstreetmap =>
      'מפות המסלולים מגיעות מ-OpenStreetMap. כל אריח מפה נשמר בטלפון בפעם הראשונה שהוא מוצג, כך ששרת המפות נשאל פעם אחת לכל היותר ולא בכל פתיחה של אימון.';

  @override
  String get offlineMapsOnly => 'מפות אופליין בלבד';

  @override
  String get neverContactTheMapServer =>
      'לעולם לא לפנות לשרת המפות. באזורים שלא נשמרו, המסלול יוצג על רקע ריק.';

  @override
  String get saveMapsOfMyRoutes => 'שמירת מפות של המסלולים שלי';

  @override
  String get noGpsRoutesYet => 'אין עדיין מסלולי GPS';

  @override
  String get deleteSavedMaps => 'מחיקת המפות השמורות';

  @override
  String get readDailyStepCounts => 'קריאת ספירת הצעדים היומית.';

  @override
  String get heartRate => 'דופק';

  @override
  String get readHeartRateSamples => 'קריאת מדידות דופק.';

  @override
  String get exerciseSessions => 'אימונים';

  @override
  String get readWorkoutsAndActiveMinutes => 'קריאת אימונים ודקות פעילות.';

  @override
  String get readSleepAsleepDuration => 'קריאת משך השינה.';

  @override
  String get readLightSleepDuration => 'קריאת משך השינה הקלה.';

  @override
  String get readDeepSleepDuration => 'קריאת משך השינה העמוקה.';

  @override
  String get readRemSleepDuration => 'קריאת משך שינת REM.';

  @override
  String get restingHeartRate => 'דופק במנוחה';

  @override
  String get readRestingBpm => 'קריאת דופק במנוחה.';

  @override
  String get readRespirationsPerMinute => 'קריאת נשימות לדקה.';

  @override
  String get readOxygenSaturationSpo2 => 'קריאת רוויון חמצן (SpO2).';

  @override
  String get readBodyWeight => 'קריאת משקל הגוף.';

  @override
  String get bodyMassIndex => 'מדד מסת גוף';

  @override
  String get readBmiValues => 'קריאת ערכי BMI.';

  @override
  String get bodyFatX => 'אחוז שומן';

  @override
  String get readBodyFatPercentage => 'קריאת אחוז השומן.';

  @override
  String get readWaterIntake => 'קריאת צריכת המים.';

  @override
  String get readNutritionEntries => 'קריאת רשומות תזונה.';

  @override
  String get bloodPressureSystolic => 'לחץ דם סיסטולי';

  @override
  String get readSystolicBloodPressure => 'קריאת לחץ דם סיסטולי.';

  @override
  String get bloodPressureDiastolic => 'לחץ דם דיאסטולי';

  @override
  String get readDiastolicBloodPressure => 'קריאת לחץ דם דיאסטולי.';

  @override
  String get readBloodGlucoseSamples => 'קריאת מדידות סוכר בדם.';

  @override
  String get permissionsCenter => 'מרכז ההרשאות';

  @override
  String get refreshPermissionStates => 'רענון מצב ההרשאות';

  @override
  String get controlEachPermissionDirectlyFrom =>
      'שליטה בכל הרשאה ישירות מכאן.';

  @override
  String get installHealthConnect => 'התקנת Health Connect';

  @override
  String get location => 'מיקום';

  @override
  String get enableRealTimeGpsRun => 'הפעלת מעקב GPS בזמן אמת לריצה ורכיבה.';

  @override
  String get backgroundHealthSync => 'סנכרון בריאות ברקע';

  @override
  String get allowPeriodicBackgroundHealthData =>
      'אישור קריאה תקופתית של נתוני בריאות ברקע.';

  @override
  String get granted => 'אושרה';

  @override
  String get denied => 'נדחתה';

  @override
  String get unknown => 'לא ידוע';

  @override
  String get turnOn => 'הפעלה';

  @override
  String get turnOff => 'כיבוי';

  @override
  String get medals => 'מדליות';

  @override
  String get templates => 'תבניות';

  @override
  String get meals => 'ארוחות';

  @override
  String get privacyDashboard => 'לוח פרטיות';

  @override
  String get everythingIsEncryptedOnThis =>
      'הכול מוצפן בטלפון הזה במפתח שרק הסיסמה או מפתח השחזור שלך יכולים לפתוח. השרת והמפתח רואים רק מידע מוצפן.';

  @override
  String get storedInYourVault => 'שמור בכספת שלך';

  @override
  String get howYourDataIsProtected => 'איך הנתונים שלך מוגנים';

  @override
  String get encryptionSyncAndWhatThe => 'הצפנה, סנכרון ומה השרת רואה';

  @override
  String get yourDataRights => 'הזכויות שלך על הנתונים';

  @override
  String get youOwnAllYourData =>
      'כל הנתונים שייכים לך. רק המכשירים שלך יכולים לקרוא אותם.';

  @override
  String get exportAFullBackupAt =>
      'אפשר לייצא גיבוי מלא בכל עת מ\"ייצוא ושחזור\".';

  @override
  String get deleteActivityDataFromSettings =>
      'אפשר למחוק נתוני פעילות בהגדרות ← מחיקת נתוני פעילות.';

  @override
  String get deletingYourAccountRemovesEverything =>
      'מחיקת החשבון מסירה הכול מהשרת.';

  @override
  String get notificationPermissionRequiredForReminders =>
      'תזכורות דורשות הרשאת התראות.';

  @override
  String get reminders => 'תזכורות';

  @override
  String get summary => 'סיכום';

  @override
  String get weeklySummaryX => 'סיכום שבועי';

  @override
  String get mondaysAt900Heart =>
      'בימי שני ב-9:00: נקודות לב, צעדים ואימונים, בהשוואה לשבוע הקודם';

  @override
  String get movementNudge => 'תזכורת לזוז';

  @override
  String get hourlyReminderToStayActive => 'תזכורת שעתית להישאר בתנועה';

  @override
  String get hydrationReminder => 'תזכורת שתייה';

  @override
  String get hourlyPromptToDrinkWater => 'תזכורת שעתית לשתות מים';

  @override
  String get workoutReminder => 'תזכורת אימון';

  @override
  String get chooseDaysAndTime => 'בחירת ימים ושעה';

  @override
  String get reminderTime => 'שעת התזכורת';

  @override
  String get bedtimeReminder => 'תזכורת לשינה';

  @override
  String get dailyWindDownPrompt => 'תזכורת יומית להירגע';

  @override
  String get bedtime => 'שעת שינה';

  @override
  String get bodyMeasurements => 'מדידות גוף';

  @override
  String get weeklyReminderToLogWeight => 'תזכורת שבועית לרשום משקל או מדידות';

  @override
  String get allRemindersAreLocalOnly =>
      'כל התזכורות מקומיות ולא יוצאות מהמכשיר. הנתונים נעולים כש-Fitness סגורה, ולכן הסיכום השבועי מוכן בכל פתיחה של האפליקציה.';

  @override
  String get copyPastWorkoutsToo => 'להעתיק גם אימונים קודמים?';

  @override
  String get onlyNewOnes => 'רק חדשים';

  @override
  String get copyThem => 'להעתיק';

  @override
  String get unitsFormat => 'יחידות ותבנית';

  @override
  String get metricKmKg => 'מטרי (ק״מ, ק״ג)';

  @override
  String get imperialMiLbs => 'אימפריאלי (מייל, ליברות)';

  @override
  String get timeFormat => 'תבנית שעה';

  @override
  String get s12HourAmPm => '12 שעות (AM/PM)';

  @override
  String get noMedalsYetKeepMoving => 'אין עדיין מדליות. להמשיך לזוז!';

  @override
  String get deleteActivityData => 'למחוק את נתוני הפעילות?';

  @override
  String get deletesYourWorkoutsDailyMetrics =>
      'מוחק את האימונים, המדדים היומיים והמדליות בכל מכשיר שמחובר לחשבון. היעדים והתבניות נשארים. הנתונים ב-Health Connect בטלפון לא נפגעים. אי אפשר לבטל את זה.';

  @override
  String get activityDataDeleted => 'נתוני הפעילות נמחקו.';

  @override
  String get setDailyAndWeeklyTargets => 'הגדרת יעדים יומיים ושבועיים';

  @override
  String get weeklySummaryMovementWaterWorkouts =>
      'סיכום שבועי, תנועה, מים, אימונים ושינה';

  @override
  String get workoutTemplates => 'תבניות אימון';

  @override
  String get createAndReuseWorkoutRoutines => 'יצירה ושימוש חוזר בשגרות אימון';

  @override
  String get healthPermissions => 'הרשאות בריאות';

  @override
  String get chooseWhatFitnessMayRead => 'בחירה מה Fitness רשאית לקרוא';

  @override
  String get saveWorkoutsToAppleHealth => 'שמירת אימונים ב-Apple Health';

  @override
  String get saveWorkoutsToHealthConnect => 'שמירת אימונים ב-Health Connect';

  @override
  String get workoutsYouLogOrRecord =>
      'אימונים שנרשמים או מוקלטים כאן יופיעו באפליקציות האחרות';

  @override
  String get showOnWearOsWatch => 'הצגה בשעון Wear OS';

  @override
  String get todaysHeartPointsStepsAnd =>
      'נקודות הלב, הצעדים והמים של היום בשעון המחובר, ואפשר להוסיף ממנו מים. נשלח רק לשעון.';

  @override
  String get unitsFormatX => 'יחידות ותבנית';

  @override
  String get keepRouteMapsOnThis => 'שמירת מפות מסלולים בטלפון';

  @override
  String get privacyDashboardX => 'לוח פרטיות';

  @override
  String get whatYourVaultHoldsAnd => 'מה יש בכספת ואיך היא מוגנת';

  @override
  String get exportRestoreX => 'ייצוא ושחזור';

  @override
  String get backUpToAFile => 'גיבוי לקובץ או החזרת גיבוי';

  @override
  String get yourHistoryFromAGoogle => 'ההיסטוריה שלך מייצוא Google Takeout';

  @override
  String get fromStravaKomootGarminAnd => 'מ-Strava,‏ Komoot,‏ Garmin ועוד';

  @override
  String get shareReport => 'שיתוף דוח';

  @override
  String get aScopedHealthReportTo => 'דוח בריאות ממוקד לשיתוף';

  @override
  String get deleteActivityDataX => 'מחיקת נתוני פעילות';

  @override
  String get workoutsMetricsAndMedalsOn =>
      'אימונים, מדדים ומדליות, בכל המכשירים';

  @override
  String get selectAtLeastOneMetric => 'יש לבחור לפחות מדד אחד.';

  @override
  String get shareReportX => 'שיתוף דוח';

  @override
  String get dateRange => 'טווח תאריכים';

  @override
  String get change => 'שינוי';

  @override
  String get metricsToInclude => 'מדדים לכלול';

  @override
  String get theReportIsAPlain =>
      'הדוח הוא קובץ טקסט רגיל, לא מוצפן. כדאי לשתף רק עם אנשים שסומכים עליהם. למידע בלבד, לא ייעוץ רפואי.';

  @override
  String get generating => 'יוצר…';

  @override
  String get generateShare => 'יצירה ושיתוף';

  @override
  String get newTemplate => 'תבנית חדשה';

  @override
  String get editTemplate => 'עריכת תבנית';

  @override
  String get templateName => 'שם התבנית';

  @override
  String get activityTypeX => 'סוג פעילות';

  @override
  String get durationMin => 'משך (דקות):';

  @override
  String get intensity110 => 'עצימות (1–10):';

  @override
  String get notesOptional => 'הערות (רשות)';

  @override
  String get create => 'יצירה';

  @override
  String get deleteTemplate => 'למחוק את התבנית?';

  @override
  String get workoutTemplatesX => 'תבניות אימון';

  @override
  String get newTemplateX => 'תבנית חדשה';

  @override
  String get noTemplatesYet => 'אין עדיין תבניות';

  @override
  String get createYourFirstTemplate => 'יצירת התבנית הראשונה';

  @override
  String get syncing => 'מסנכרן…';

  @override
  String get notSynced => 'לא מסונכרן';

  @override
  String get synced => 'מסונכרן';

  @override
  String get syncPending => 'ממתין לסנכרון';

  @override
  String get vaultUnlocked => 'הכספת פתוחה';

  @override
  String get vaultIsUnlockedAndData => 'הכספת פתוחה והנתונים נגישים';

  @override
  String get vaultIsLockedTapUnlock =>
      'הכספת נעולה. כדי לגשת לנתונים יש להקיש על פתיחה';

  @override
  String get gpsActive => 'GPS פעיל';

  @override
  String get gpsTrackingIsActive => 'מעקב GPS פעיל';

  @override
  String get stepsToday => 'צעדים היום';

  @override
  String get heartToday => 'לב היום';

  @override
  String get keyMetrics => 'מדדים עיקריים';

  @override
  String get moreMetrics => 'מדדים נוספים';

  @override
  String get water => 'מים';

  @override
  String get foodEntry => 'רשומת מזון';

  @override
  String get foodEntries => 'רשומות מזון';

  @override
  String get gpsWorkoutActive => 'אימון GPS פעיל';

  @override
  String get startGpsWorkout => 'התחלת אימון GPS';

  @override
  String get trackRoutePaceDistance => 'מעקב אחר מסלול, קצב ומרחק';

  @override
  String get lockVault => 'נעילת הכספת';

  @override
  String get trendData => 'נתוני מגמה';

  @override
  String get s30DayBaselines => 'בסיס 30 יום';

  @override
  String get sleepSteps => 'שינה וצעדים';

  @override
  String get stepsHeartPointsTodayHourly => 'צעדים ונקודות לב (היום, לפי שעה)';

  @override
  String get stepsHeartPointsThisWeek => 'צעדים ונקודות לב (השבוע)';

  @override
  String get stepsHeartPointsLast30 => 'צעדים ונקודות לב (30 הימים האחרונים)';

  @override
  String get selectedMetricWeek => 'המדד שנבחר (שבוע)';

  @override
  String get selectedMetricMonth => 'המדד שנבחר (חודש)';

  @override
  String get analytics => 'ניתוח';

  @override
  String get day => 'יום';

  @override
  String get week => 'שבוע';

  @override
  String get month => 'חודש';

  @override
  String get informational => 'למידע';

  @override
  String get notMedicalAdviceBasedOn =>
      'לא ייעוץ רפואי · על סמך הנתונים שנרשמו';

  @override
  String get dismiss => 'סגירה';

  @override
  String get breakfast => 'ארוחת בוקר';

  @override
  String get lunch => 'ארוחת צהריים';

  @override
  String get dinner => 'ארוחת ערב';

  @override
  String get snacks => 'נשנושים';

  @override
  String get addWater => 'הוספת מים';

  @override
  String get add => 'הוספה';

  @override
  String get waterFood => 'מים ומזון';

  @override
  String get food => 'מזון';

  @override
  String get unlockToLogWaterAnd => 'כדי לרשום מים ומזון יש לפתוח את הכספת.';

  @override
  String get previousDay => 'היום הקודם';

  @override
  String get nextDay => 'היום הבא';

  @override
  String get last7DaysX => '7 הימים האחרונים';

  @override
  String get logAgain => 'רישום שוב';

  @override
  String get logFood => 'רישום מזון';

  @override
  String get nothingLogged => 'לא נרשם דבר';

  @override
  String get editFood => 'עריכת מזון';

  @override
  String get whatDidYouEat => 'מה אכלת?';

  @override
  String get calories => 'קלוריות';

  @override
  String get protein => 'חלבון';

  @override
  String get carbs => 'פחמימות';

  @override
  String get fat => 'שומן';

  @override
  String get caloriesAndMacrosAreOptional => 'קלוריות ורכיבי תזונה הם רשות.';

  @override
  String get actRunning => 'ריצה';

  @override
  String get actCycling => 'רכיבה על אופניים';

  @override
  String get actSwimming => 'שחייה';

  @override
  String get actWalking => 'הליכה';

  @override
  String get actHiking => 'טיול רגלי';

  @override
  String get actStrengthTraining => 'אימון כוח';

  @override
  String get actYogaStretching => 'יוגה/מתיחות';

  @override
  String get actOther => 'אחר';

  @override
  String get actStrength => 'כוח';

  @override
  String get actHiit => 'HIIT';

  @override
  String get actYoga => 'יוגה';

  @override
  String get srcManual => 'ידני';

  @override
  String get srcHealth => 'בריאות';

  @override
  String get srcGoogleFit => 'GOOGLE FIT';

  @override
  String medalUnlocked(String name) {
    return 'קיבלת מדליה: $name!';
  }

  @override
  String percentOfGoal(int percent) {
    return '$percent% מהיעד';
  }

  @override
  String noMetricData(String metric) {
    return 'אין נתוני $metric';
  }

  @override
  String metricAccessNotGranted(String metric) {
    return 'אין גישה ל$metric. אפשר להפעיל אותה בהרשאות.';
  }

  @override
  String metricNotSupported(String metric) {
    return '$metric לא נתמך במכשיר הזה.';
  }

  @override
  String vsLastWeek(String change) {
    return '$change לעומת שבוע שעבר';
  }

  @override
  String bestStreak(int count) {
    return 'שיא: $count';
  }

  @override
  String templateSummary(String activity, int minutes, int intensity) {
    return '$activity · $minutes דק׳ · עצימות $intensity/10';
  }

  @override
  String failedToSave(String error) {
    return 'השמירה נכשלה: $error';
  }

  @override
  String heartPointsEarnedPreview(int count) {
    return '≈ $count נקודות לב';
  }

  @override
  String morePointsToTarget(int count) {
    return 'עוד $count נקודות לב כדי להגיע ליעד של היום.';
  }

  @override
  String momentumExplained(int target) {
    return 'היעד היומי מתחיל ב-$target נקודות לב (כ-150 בשבוע, לפי המלצת ארגון הבריאות העולמי) ומתאים את עצמו אליך: עמידה ביעד מגדילה אותו ב-5%, וירידה מתחת לחציו מקטינה אותו ב-3%.\n\nמומנטום (0-100) מראה כמה התקרבת ליעד ב-7 הימים האחרונים, כשלימים האחרונים משקל גבוה יותר. יום שהוחמץ מוריד אותו מעט במקום לאפס אותו, והיום יכול רק להעלות אותו.\n\nהכול מחושב במכשיר הזה.';
  }

  @override
  String gainedToday(int count) {
    return '‎+$count היום';
  }

  @override
  String pointsOfTarget(int points, int target) {
    return '$points / $target נק׳';
  }

  @override
  String changeUp(int percent) {
    return ' (עלייה של $percent%)';
  }

  @override
  String changeDown(int percent) {
    return ' (ירידה של $percent%)';
  }

  @override
  String yourWeekActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'השבוע שלך: $count ימים פעילים',
      two: 'השבוע שלך: יומיים פעילים',
      one: 'השבוע שלך: יום פעיל אחד',
    );
    return '$_temp0';
  }

  @override
  String nHeartPoints(String count) {
    return '$count נקודות לב';
  }

  @override
  String nSteps(String count) {
    return '$count צעדים';
  }

  @override
  String nWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אימונים',
      two: 'שני אימונים',
      one: 'אימון אחד',
    );
    return '$_temp0';
  }

  @override
  String throughDay(String day) {
    return ' (עד יום $day)';
  }

  @override
  String cueSplitKm(int count, String total, String split) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קילומטרים',
      one: 'קילומטר אחד',
    );
    return '$_temp0. זמן $total. מקטע $split לקילומטר.';
  }

  @override
  String cueSplitMile(int count, String total, String split) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מייל',
      one: 'מייל אחד',
    );
    return '$_temp0. זמן $total. מקטע $split למייל.';
  }

  @override
  String cueLap(int index, String time) {
    return 'הקפה $index. $time.';
  }

  @override
  String spokenHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שעות',
      two: 'שעתיים',
      one: 'שעה',
    );
    return '$_temp0';
  }

  @override
  String spokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דקות',
      two: 'שתי דקות',
      one: 'דקה',
    );
    return '$_temp0';
  }

  @override
  String spokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שניות',
      two: 'שתי שניות',
      one: 'שנייה',
    );
    return '$_temp0';
  }

  @override
  String activityAutoPaused(String activity) {
    return '$activity · השהיה אוטומטית';
  }

  @override
  String activityPaused(String activity) {
    return '$activity · מושהה';
  }

  @override
  String unlockedOn(String date) {
    return 'הושגה ב-$date';
  }

  @override
  String percentToward(int percent, String name) {
    return '$percent% לקראת $name';
  }

  @override
  String restoredSummary(int workouts, int days, int goals) {
    return 'שוחזרו $workouts אימונים, $days ימי מדדים ו-$goals יעדים.';
  }

  @override
  String exportFailed(String error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String restoreFailed(String error) {
    return 'השחזור נכשל: $error';
  }

  @override
  String goalSavedFor(String metric) {
    return 'היעד נשמר עבור $metric';
  }

  @override
  String failedToLoadGoals(String error) {
    return 'טעינת היעדים נכשלה: $error';
  }

  @override
  String get targetLabel => 'יעד';

  @override
  String couldntReadThatFile(String error) {
    return 'לא ניתן לקרוא את הקובץ ($error).';
  }

  @override
  String importFailed(String error) {
    return 'הייבוא נכשל: $error';
  }

  @override
  String addedWorkoutsAndDays(int workouts, int days) {
    return 'נוספו $workouts אימונים ו-$days ימים';
  }

  @override
  String workoutsAlreadyHere(int count) {
    return '$count אימונים כבר היו כאן';
  }

  @override
  String daysOfStepsAndPoints(int count) {
    return '$count ימים של צעדים ונקודות לב';
  }

  @override
  String dateRangeTo(String from, String to) {
    return ' ($from עד $to)';
  }

  @override
  String couldntStart(String error) {
    return 'לא ניתן להתחיל: $error';
  }

  @override
  String workoutSavedDistance(String distance, String time) {
    return 'האימון נשמר: $distance ב-$time';
  }

  @override
  String get cuesEveryKm => 'זמן וקצב בכל קילומטר';

  @override
  String get cuesEveryMile => 'זמן וקצב בכל מייל';

  @override
  String lastSplit(String unit, String time) {
    return '$unit אחרון: $time';
  }

  @override
  String couldntReadAsGpx(String files) {
    return 'לא ניתן לקרוא את $files כקובצי GPX.';
  }

  @override
  String skippedNotGpx(String files) {
    return 'דילגנו על $files: לא GPX.';
  }

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יובאו $count אימונים. הם מופיעים ביומן.',
      one: 'יובא אימון אחד. הוא מופיע ביומן.',
    );
    return '$_temp0';
  }

  @override
  String nPoints(int count) {
    return '$count נקודות';
  }

  @override
  String nMin(int count) {
    return '$count דק׳';
  }

  @override
  String importNWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ייבוא $count אימונים',
      one: 'ייבוא אימון אחד',
    );
    return '$_temp0';
  }

  @override
  String nothingMatches(String query) {
    return 'אין תוצאות עבור \"$query\"';
  }

  @override
  String nPts(int count) {
    return '$count נק׳';
  }

  @override
  String deleteThisItem(String name) {
    return 'למחוק את ה$name?';
  }

  @override
  String itsPointsComeOff(int count) {
    return 'גם $count נקודות הלב שלו יורדו מאותו יום. הוא יימחק בכל המכשירים שלך.';
  }

  @override
  String lapN(int index) {
    return 'הקפה $index';
  }

  @override
  String deleteThisEntry(String name) {
    return 'למחוק את רשומת ה$name?';
  }

  @override
  String editItem(String name) {
    return 'עריכת $name';
  }

  @override
  String goalPeriod(String period) {
    return 'יעד ($period)';
  }

  @override
  String savedMapTiles(int count) {
    return 'נשמרו $count אריחי מפה.';
  }

  @override
  String get mapTilesCapped =>
      ' זה המקסימום בפעם אחת; אפשר להריץ שוב מאוחר יותר בשביל השאר.';

  @override
  String areasAroundRoutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'האזורים סביב $count המסלולים שלך, זמינים בלי חיבור',
      one: 'האזורים סביב המסלול שלך, זמינים בלי חיבור',
    );
    return '$_temp0';
  }

  @override
  String tilesAndSize(int count, String size) {
    return '$count אריחים, $size';
  }

  @override
  String permissionActionFailed(String error) {
    return 'פעולת ההרשאה נכשלה: $error';
  }

  @override
  String nOfMGranted(int granted, int total) {
    return '$granted / $total אושרו';
  }

  @override
  String healthDidntAllow(String health) {
    return '$health לא אישר ל-Fitness לשמור אימונים.';
  }

  @override
  String newWorkoutsSavedTo(String health) {
    return 'מעכשיו אימונים חדשים נשמרים ב-$health. Fitness יכולה גם להעתיק את האימונים שכבר ביומן שלך.';
  }

  @override
  String copiedWorkoutsTo(int count, String health) {
    return 'הועתקו $count אימונים ל-$health.';
  }

  @override
  String viewAllCount(int count) {
    return 'הצגת הכול ($count)';
  }

  @override
  String get unitMetric => 'מטרי';

  @override
  String get unitImperial => 'אימפריאלי';

  @override
  String failedError(String error) {
    return 'נכשל: $error';
  }

  @override
  String deleteNamedCannotUndo(String name) {
    return 'למחוק את \"$name\"? אי אפשר לבטל את הפעולה.';
  }

  @override
  String addWaterAmount(String amount) {
    return 'הוספת $amount מים';
  }

  @override
  String restingHrAvg(String bpm) {
    return 'דופק במנוחה בממוצע: $bpm פעימות לדקה';
  }

  @override
  String dailyStepsAvg(String steps) {
    return 'ממוצע צעדים יומי: $steps';
  }

  @override
  String sleepStepsCorrelation(String strength, String direction) {
    String _temp0 = intl.Intl.selectLogic(direction, {
      'positive': 'חיובי',
      'other': 'שלילי',
    });
    String _temp1 = intl.Intl.selectLogic(strength, {
      'strong': 'חזק',
      'moderate': 'בינוני',
      'other': 'חלש',
    });
    return 'משך השינה שלך מראה מתאם $_temp0 $_temp1 עם מספר הצעדים היומי.';
  }

  @override
  String loggedName(String name) {
    return '$name נרשם';
  }

  @override
  String ofGoalAmount(String amount) {
    return 'מתוך $amount';
  }

  @override
  String waterLoggedHereAndHealth(String here, String health) {
    return '$here נרשמו כאן · $health מאפליקציית הבריאות';
  }

  @override
  String takeOffAmount(String amount) {
    return 'הסרת $amount';
  }

  @override
  String get kcalUnit => 'קלוריות';

  @override
  String get proteinShort => 'חלבון';

  @override
  String get carbsShort => 'פחמימות';

  @override
  String get fatShort => 'שומן';

  @override
  String plusHealthEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ועוד $count רשומות מאפליקציית הבריאות.',
      one: 'ועוד רשומה אחת מאפליקציית הבריאות.',
    );
    return '$_temp0';
  }

  @override
  String get medalFirstSteps => 'צעדים ראשונים';

  @override
  String get medalFirstStepsDesc => 'רישום נתוני הצעדים הראשונים שלך.';

  @override
  String get medalStepSeeker => 'מחפש צעדים';

  @override
  String get medalStepSeekerDesc => 'הליכה של 5,000 צעדים ביום אחד.';

  @override
  String get medalStepChampion => 'אלוף הצעדים';

  @override
  String get medalStepChampionDesc => 'הליכה של 10,000 צעדים ביום אחד.';

  @override
  String get medalStepLegend => 'אגדת צעדים';

  @override
  String get medalStepLegendDesc => 'הליכה של 20,000 צעדים ביום אחד.';

  @override
  String get medalHeartStarter => 'לב מתחיל';

  @override
  String get medalHeartStarterDesc => 'צבירת 10 נקודות לב ביום אחד.';

  @override
  String get medalHeartWarrior => 'לוחם לב';

  @override
  String get medalHeartWarriorDesc => 'צבירת 25 נקודות לב ביום אחד.';

  @override
  String get medalHeartLegend => 'אגדת לב';

  @override
  String get medalHeartLegendDesc => 'צבירת 50 נקודות לב ביום אחד.';

  @override
  String get medalActiveWeek => 'שבוע פעיל';

  @override
  String get medalActiveWeekDesc => 'צבירת 150 נקודות לב בכל תקופה של 7 ימים.';

  @override
  String get medalOnTarget => 'בול ביעד';

  @override
  String get medalOnTargetDesc => 'עמידה ביעד נקודות הלב היומי בפעם הראשונה.';

  @override
  String get medalTargetStreak3 => 'שלושער';

  @override
  String get medalTargetStreak3Desc => 'עמידה ביעד היומי 3 ימים ברצף.';

  @override
  String get medalTargetStreak7 => 'בפוקוס';

  @override
  String get medalTargetStreak7Desc => 'עמידה ביעד היומי 7 ימים ברצף.';

  @override
  String get medalComeback => 'קאמבק';

  @override
  String get medalComebackDesc =>
      'עמידה ביעד אחרי 3 ימים או יותר בלי לעמוד בו.';

  @override
  String get medalTarget40 => 'מעלים את הרף';

  @override
  String get medalTarget40Desc => 'הגדלת היעד היומי ל-40 נקודות לב.';

  @override
  String get medalMomentum50 => 'יציב';

  @override
  String get medalMomentum50Desc => 'הגעה לציון מומנטום 50.';

  @override
  String get medalMomentum75 => 'בלתי ניתן לעצירה';

  @override
  String get medalMomentum75Desc => 'הגעה לציון מומנטום 75.';

  @override
  String get medalMomentumWeek75 => 'תנועה מתמדת';

  @override
  String get medalMomentumWeek75Desc =>
      'סיום 7 ימים ברצף עם מומנטום של 75 ומעלה.';

  @override
  String get medalNightLogged => 'לילה מתועד';

  @override
  String get medalNightLoggedDesc => 'רישום נתוני שינה בפעם הראשונה.';

  @override
  String get medalWellRested => 'ישן היטב';

  @override
  String get medalWellRestedDesc => '7 שעות שינה ומעלה בלילה אחד.';

  @override
  String get medalDeepDreamer => 'חולם עמוק';

  @override
  String get medalDeepDreamerDesc => 'שעה ומעלה של שינה עמוקה בלילה אחד.';

  @override
  String get medalSleepChampion => 'אלוף השינה';

  @override
  String get medalSleepChampionDesc => '8 שעות שינה ומעלה בלילה אחד.';

  @override
  String get medalHydrated => 'רווי';

  @override
  String get medalHydratedDesc => 'רישום 2 ליטר מים ומעלה ביום אחד.';

  @override
  String get medalHealthyHeart => 'לב בריא';

  @override
  String get medalHealthyHeartDesc => 'דופק במנוחה של 60 פעימות לדקה או פחות.';

  @override
  String get medalOxygenCheck => 'בדיקת חמצן';

  @override
  String get medalOxygenCheckDesc => 'רישום נתוני ריווי חמצן (SpO2).';

  @override
  String get medalFirstSync => 'סנכרון ראשון';

  @override
  String get medalFirstSyncDesc => 'סנכרון נתוני הבריאות שלך בפעם הראשונה.';

  @override
  String get medalDedicated => 'מסור';

  @override
  String get medalDedicatedDesc => 'סנכרון נתונים ב-7 ימים שונים.';

  @override
  String get medalCommitted => 'מחויב';

  @override
  String get medalCommittedDesc => 'סנכרון נתונים ב-30 ימים שונים.';

  @override
  String get medalStepMillionaire => 'מיליונר הצעדים';

  @override
  String get medalStepMillionaireDesc => 'הליכה של 1,000,000 צעדים בסך הכול.';

  @override
  String get medalElite => 'עילית';

  @override
  String get medalEliteDesc => 'צבירת 1,000 נקודות לב בסך הכול.';

  @override
  String get medalStreak3 => 'עקבי';

  @override
  String get medalStreak3Desc => 'רישום נתוני בריאות 3 ימים ברצף.';

  @override
  String get medalStreak7 => 'רצף שבועי';

  @override
  String get medalStreak7Desc => 'רישום נתוני בריאות כל יום במשך שבוע.';

  @override
  String get medalStreak30 => 'הרגל ברזל';

  @override
  String get medalStreak30Desc => 'רישום נתוני בריאות כל יום במשך 30 ימים.';

  @override
  String get widgetHeartPts => 'נק׳ לב';

  @override
  String get widgetLocked => 'יש לפתוח את ZT Fitness כדי לראות את היום';

  @override
  String get widgetLockedShort => 'נעול';

  @override
  String get widgetHpGoal => 'מתוך %1\$s נק׳ לב';

  @override
  String get widgetStepsGoal => 'מתוך %1\$s צעדים';

  @override
  String get widgetMomentum => 'מומנטום %1\$s';

  @override
  String get widgetSummary =>
      '%1\$s מתוך %2\$s נקודות לב, %3\$s מתוך %4\$s צעדים';
}
