import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/providers/admin_provider.dart';
import 'core/providers/archive_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/favorite_provider.dart';
import 'core/providers/item_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/matching_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/reward_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/timeline_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/routes/app_router.dart';
import 'core/services/archive_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/chat_service.dart';
import 'core/services/cloudinary_service.dart';
import 'core/services/favorite_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/referral_service.dart';
import 'core/services/reward_service.dart';
import 'core/services/timeline_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleGlobalNotificationTap(Map<String, dynamic> data) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final type = data['type'] as String? ?? '';
  if (type == 'chat_message') {
    final chatId = data['chatId'] as String? ?? '';
    final senderId = data['senderId'] as String? ?? '';
    final itemName = data['itemName'] as String? ?? '';
    if (chatId.isNotEmpty) {
      nav.pushNamed(AppRouter.conversation, arguments: {
        'chatId': chatId,
        'otherUid': senderId,
        'itemName': itemName.isNotEmpty ? itemName : 'Chat',
      });
    }
  } else {
    nav.pushNamed(AppRouter.notifications);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } else {
    Firebase.app();
  }

  runApp(const FindItApp());
}

class FindItApp extends StatefulWidget {
  const FindItApp({super.key});

  @override
  State<FindItApp> createState() => _FindItAppState();
}

class _FindItAppState extends State<FindItApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => CloudinaryService()),
        Provider(
          create: (context) => RewardService(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        Provider(
          create: (context) => TimelineService(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        Provider(
          create: (context) => FavoriteService(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        Provider(
          create: (context) => ArchiveService(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        Provider(
          create: (context) => NotificationService(
            firestoreService: context.read<FirestoreService>(),
          )..onNotificationTapped = _handleGlobalNotificationTap,
        ),
        Provider(
          create: (context) => ChatService(
            firestoreService: context.read<FirestoreService>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        Provider(
          create: (context) => ReferralService(
            firestoreService: context.read<FirestoreService>(),
            rewardService: context.read<RewardService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            firestoreService: context.read<FirestoreService>(),
            referralService: context.read<ReferralService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider(
            firestoreService: context.read<FirestoreService>(),
            cloudinaryService: context.read<CloudinaryService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ItemProvider(
            firestoreService: context.read<FirestoreService>(),
            cloudinaryService: context.read<CloudinaryService>(),
            rewardService: context.read<RewardService>(),
            timelineService: context.read<TimelineService>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MatchingProvider(
            firestoreService: context.read<FirestoreService>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => RewardProvider(
            rewardService: context.read<RewardService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TimelineProvider(
            timelineService: context.read<TimelineService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => FavoriteProvider(
            favoriteService: context.read<FavoriteService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ArchiveProvider(
            archiveService: context.read<ArchiveService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(
            notificationService: context.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            chatService: context.read<ChatService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            title: 'FindIt',
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: AppRouter.splash,
          );
        },
      ),
    );
  }
}
