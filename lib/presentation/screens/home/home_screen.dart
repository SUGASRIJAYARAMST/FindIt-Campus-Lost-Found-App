import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/favorite_provider.dart';
import '../../../core/providers/item_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/archive_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../domain/models/item_model.dart';
import '../../../domain/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../items/item_list_screen.dart';
import '../profile/profile_screen.dart';
import '../rewards/rewards_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _itemListTabIndex = 0;
  bool _itemListAutoFocus = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _referralDialogShown = false;
  bool _referralMinimized = false;
  int _referralRemaining = 300;

  late final UserProvider _userProvider;
  late final FavoriteProvider _favoriteProvider;
  late final ItemProvider _itemProvider;
  late final NotificationProvider _notificationProvider;

  @override
  void initState() {
    super.initState();
    _userProvider = context.read<UserProvider>();
    _favoriteProvider = context.read<FavoriteProvider>();
    _itemProvider = context.read<ItemProvider>();
    _notificationProvider = context.read<NotificationProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _userProvider.stopListening();
    _favoriteProvider.stopListening();
    _itemProvider.stopListening();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();
    final archiveService = context.read<ArchiveService>();
    final chatProvider = context.read<ChatProvider>();
    if (authProvider.user != null) {
      _userProvider.startListening(authProvider.user!.uid);
      _favoriteProvider.startListening(authProvider.user!.uid);
      _itemProvider.startListening(currentUid: authProvider.user!.uid);
      _notificationProvider.initialize(authProvider.user!.uid);
      chatProvider.startListeningUnread(authProvider.user!.uid);
      await _userProvider.fetchUserData(authProvider.user!.uid);
      try {
        archiveService.autoArchiveOldItems();
      } catch (_) {}
      try {
        _itemProvider.migrateStatuses();
      } catch (_) {}
      _checkIncompleteProfile();
      _showReferralPrompt();
    }
  }

  void _checkIncompleteProfile() {
    final userModel = _userProvider.userModel;
    if (userModel == null) {
      // User doc may not be ready yet after registration — retry after delay
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        final retryModel = _userProvider.userModel;
        if (retryModel == null) return;
        final hasName = retryModel.name.trim().isNotEmpty && retryModel.name.trim() != 'Student';
        final hasDept = retryModel.department.trim().isNotEmpty;
        final hasPhone = retryModel.phone.trim().isNotEmpty;
        if (!hasName || !hasDept || !hasPhone) {
          _showCompleteProfileDialog(hasName, hasDept, hasPhone);
        }
      });
      return;
    }
    final hasName = userModel.name.trim().isNotEmpty && userModel.name.trim() != 'Student';
    final hasDept = userModel.department.trim().isNotEmpty;
    final hasPhone = userModel.phone.trim().isNotEmpty;
    if (!hasName || !hasDept || !hasPhone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCompleteProfileDialog(hasName, hasDept, hasPhone);
      });
    }
  }

  void _showCompleteProfileDialog(bool hasName, bool hasDept, bool hasPhone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: hasName ? '' : (auth.user?.displayName ?? ''));
    final deptController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_rounded, color: Color(0xFFFFA726), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Complete Your Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Please fill in the missing details to continue.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(height: 20),
                if (!hasName)
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. John Doe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                if (!hasName && !hasDept) const SizedBox(height: 12),
                if (!hasDept)
                  TextField(
                    controller: deptController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g. Computer Science',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                  ),
                if ((!hasName || !hasDept) && !hasPhone) const SizedBox(height: 12),
                if (!hasPhone)
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g. 9876543210',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!hasName) return;
              Navigator.pop(ctx);
            },
            child: Text(
              hasName ? 'Skip' : 'Name required',
              style: TextStyle(color: hasName ? (isDark ? Colors.white38 : Colors.black38) : const Color(0xFFE53935)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = auth.user?.uid;
              if (uid == null) return;
              final fixData = <String, dynamic>{};
              if (!hasName && nameController.text.trim().isNotEmpty) {
                fixData['name'] = nameController.text.trim();
              }
              if (!hasDept && deptController.text.trim().isNotEmpty) {
                fixData['department'] = deptController.text.trim();
              }
              if (!hasPhone && phoneController.text.trim().isNotEmpty) {
                fixData['phone'] = phoneController.text.trim();
              }
              if (fixData.isNotEmpty) {
                await context.read<FirestoreService>().setData('users', uid, fixData, merge: true);
                await _userProvider.fetchUserData(uid);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReferralPrompt() {
    if (_referralDialogShown) return;
    final userModel = _userProvider.userModel;
    if (userModel == null) return;
    if (userModel.referredBy.isNotEmpty) return;

    _referralDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 18));
      if (!mounted) return;
      _showReferralCodeSheet();
    });
  }

  Timer? _referralTimer;
  VoidCallback? _setReferralSheetState;

  void _showReferralCodeSheet() {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final referralController = TextEditingController();
    bool isSubmitting = false;

    _referralTimer?.cancel();
    _referralTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_referralRemaining <= 0) {
        timer.cancel();
        _referralRemaining = 300;
        _referralMinimized = false;
        _setReferralSheetState?.call();
        return;
      }
      _referralRemaining--;
      _setReferralSheetState?.call();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            _setReferralSheetState = () {
              if (ctx.mounted) setSheetState(() {});
            };
            final minutes = _referralRemaining ~/ 60;
            final seconds = _referralRemaining % 60;

            if (_referralMinimized) return const SizedBox.shrink();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? const Color(0xFF1A2636) : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF43A047).withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF43A047), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Have a referral code?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enter a friend\'s code to earn bonus rewards!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _referralTimer?.cancel();
                            _referralRemaining = 300;
                            _referralMinimized = false;
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: referralController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          icon: Icon(Icons.redeem_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 20),
                          hintText: 'Enter code',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, size: 14, color: Color(0xFFFFA726)),
                          const SizedBox(width: 4),
                          Text(
                            '$minutes:${seconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFA726),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final code = referralController.text.trim();
                                if (code.isEmpty) return;
                                setSheetState(() => isSubmitting = true);
                                try {
                                  final auth = context.read<AuthProvider>();
                                  final referralService = context.read<ReferralService>();
                                  final uid = auth.user?.uid ?? '';
                                  if (uid.isEmpty) return;
                                  final result = await referralService.applyReferral(uid, code);
                                  _referralTimer?.cancel();
                                  _referralRemaining = 300;
                                  _referralMinimized = false;
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                result != null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  result != null
                                                      ? 'Referral applied! Bonus rewards added.'
                                                      : 'Invalid referral code. Please try again.',
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: result != null ? const Color(0xFF43A047) : const Color(0xFFE53935),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  _referralTimer?.cancel();
                                  _referralRemaining = 300;
                                  _referralMinimized = false;
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Something went wrong. Please try again.'),
                                          backgroundColor: const Color(0xFFE53935),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.colorScheme.primary.withAlpha(100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Apply Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _referralTimer?.cancel();
      _setReferralSheetState = null;
    });
  }

  void _handleAuthState(AuthProvider authProvider) {
    if (authProvider.user == null && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = authProvider.user;
    final userModel = userProvider.userModel;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuthState(authProvider));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final rawName = userModel?.name ?? '';
    final name = rawName.trim().isNotEmpty && rawName.trim() != 'Student'
        ? rawName.trim()
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email?.split('@').first ?? 'Student');
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    final photoUrl = userModel?.profileImage ?? user.photoURL;

    final pages = [
      _HomeBody(
        theme: theme,
        isDark: isDark,
        name: name,
        avatarLetter: avatarLetter,
        photoUrl: photoUrl,
        userModel: userModel,
        items: context.watch<ItemProvider>().items,
        onRefresh: _loadUserData,
        onViewAllItems: () => setState(() {
          _itemListTabIndex = 0;
          _itemListAutoFocus = true;
          _currentIndex = 1;
        }),
        onViewAllLost: () => setState(() {
          _itemListTabIndex = 1;
          _itemListAutoFocus = false;
          _currentIndex = 1;
        }),
        onViewAllFound: () => setState(() {
          _itemListTabIndex = 2;
          _itemListAutoFocus = false;
          _currentIndex = 1;
        }),
        onAvatarTap: () => setState(() => _currentIndex = 3),
        scaffoldKey: _scaffoldKey,
        isAdmin: authProvider.isAdmin,
      ),
      ItemListScreen(
        key: ValueKey('itemList$_itemListTabIndex$_itemListAutoFocus'),
        initialTabIndex: _itemListTabIndex,
        autoFocus: _itemListAutoFocus,
        onAutoFocusDone: () => _itemListAutoFocus = false,
      ),
      const RewardsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      drawer: const AppDrawer(),
      body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
      floatingActionButton: _currentIndex == 0 ? _buildFAB(theme) : null,
      bottomNavigationBar: _buildBottomNav(theme, isDark),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: () => Navigator.pushNamed(context, AppRouter.uploadLost),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(loc.report, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: loc.home),
          NavigationDestination(icon: const Icon(Icons.inventory_2_rounded), label: loc.items),
          NavigationDestination(icon: const Icon(Icons.redeem_rounded), label: loc.rewards),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: loc.profile),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final String name;
  final String avatarLetter;
  final String? photoUrl;
  final UserModel? userModel;
  final List<ItemModel> items;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAllItems;
  final VoidCallback onViewAllLost;
  final VoidCallback onViewAllFound;
  final VoidCallback onAvatarTap;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool isAdmin;

  const _HomeBody({
    required this.theme,
    required this.isDark,
    required this.name,
    required this.avatarLetter,
    this.photoUrl,
    this.userModel,
    required this.items,
    required this.onRefresh,
    required this.onViewAllItems,
    required this.onViewAllLost,
    required this.onViewAllFound,
    required this.onAvatarTap,
    required this.scaffoldKey,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, theme, isDark, name, avatarLetter, photoUrl, userModel),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSearchBar(context, theme, isDark),
                  const SizedBox(height: 28),
                  _buildQuickActions(context, theme, isDark),
                  const SizedBox(height: 20),
                  _buildSmartMatchesCard(context, theme, isDark),
                  const SizedBox(height: 28),
                  _buildRecentItems(context, theme, isDark),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark, String name, String avatarLetter, String? photoUrl, UserModel? userModel) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0B1929), const Color(0xFF111D2E)]
              : [const Color(0xFF0D47A1), const Color(0xFF1565C0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_rounded, color: Colors.white.withAlpha(200), size: 22),
                ),
              ),
              const Spacer(),
              Text(
                _getGreeting(loc),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(160),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRouter.notifications),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.notifications_outlined, color: Colors.white.withAlpha(200), size: 22),
                    ),
                    if (context.watch<NotificationProvider>().unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            context.watch<NotificationProvider>().unreadCount > 9 ? '9+' : '${context.watch<NotificationProvider>().unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRouter.adminDashboard),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFA726), size: 22),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAvatarTap,
                child: _buildAvatar(theme, photoUrl, avatarLetter),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            loc.helloName(name),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.findLostReport,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withAlpha(160),
            ),
          ),
          if (userModel != null) ...[
            const SizedBox(height: 16),
            _buildStatsRow(theme, userModel),
          ],
        ],
      ),
    );
  }

  String _getGreeting(AppLocalizations loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) return loc.goodMorning;
    if (hour < 17) return loc.goodAfternoon;
    return loc.goodEvening;
  }

  Widget _buildStatsRow(ThemeData theme, UserModel userModel) {
    return Row(
      children: [
        _buildStatBadge(Icons.star_rounded, '${userModel.rewardPoints} pts', const Color(0xFFFFD54F)),
        const SizedBox(width: 12),
        _buildStatBadge(Icons.emoji_events_rounded, userModel.badge, const Color(0xFF4FC3F7)),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, String? photoUrl, String letter) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(80), width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF42A5F5),
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
        onBackgroundImageError: (photoUrl != null && photoUrl.isNotEmpty) ? (_, _) {} : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))
            : null,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onViewAllItems,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2636) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.searchHint,
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black26, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;
    final actions = [
      _ActionData(Icons.report_problem_rounded, loc.reportLost, AppRouter.uploadLost, const Color(0xFFFF7043)),
      _ActionData(Icons.search_off_rounded, loc.reportFound, AppRouter.uploadFound, const Color(0xFF26A69A)),
      _ActionData(Icons.list_alt_rounded, loc.myReports, AppRouter.myReports, const Color(0xFF5C6BC0)),
      _ActionData(Icons.favorite_rounded, loc.favorites, AppRouter.favorites, const Color(0xFFE53935)),
      _ActionData(Icons.settings_rounded, loc.settings, AppRouter.settings, const Color(0xFF78909C)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            loc.quickActions,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: action.route != null ? () => Navigator.pushNamed(context, action.route!) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: action.accentColor.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: action.accentColor, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSmartMatchesCard(BuildContext context, ThemeData theme, bool isDark) {
    return _SmartMatchesCard(isDark: isDark, theme: theme);
  }

  Widget _buildRecentItems(BuildContext context, ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;

    final recentLost = items
        .where((i) => i.type == 'lost')
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.itemDate;
        final bDate = b.createdAt ?? b.itemDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final recentFound = items
        .where((i) => i.type == 'found')
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.itemDate;
        final bDate = b.createdAt ?? b.itemDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          theme,
          isDark,
          loc.recentLostItems,
          recentLost.take(5).toList(),
          const Color(0xFFE53935),
          onViewAllLost,
        ),
        const SizedBox(height: 24),
        _buildSection(
          context,
          theme,
          isDark,
          loc.recentFoundItems,
          recentFound.take(5).toList(),
          const Color(0xFF43A047),
          onViewAllFound,
        ),
      ],
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _buildSection(BuildContext context, ThemeData theme, bool isDark, String title, List<ItemModel> sectionItems, Color accentColor, VoidCallback onViewAll) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                loc.viewAll,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (sectionItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2636) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Icon(
                  accentColor == const Color(0xFFE53935)
                      ? Icons.search_off_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isDark ? Colors.white24 : Colors.black12,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  accentColor == const Color(0xFFE53935) ? loc.noLostItems : loc.noFoundItems,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ...sectionItems.map((item) => _buildItemCard(context, theme, isDark, item, accentColor)),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, ThemeData theme, bool isDark, ItemModel item, Color accentColor) {
    final timeStr = _timeAgo(item.createdAt ?? item.itemDate);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.itemDetail, arguments: item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2636) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 20 : 8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: accentColor.withAlpha(25)),
                        errorWidget: (_, _, _) => Icon(
                          item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
                          color: accentColor,
                          size: 26,
                        ),
                      )
                    : Icon(
                        item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
                        color: accentColor,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.statusDisplay,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.location,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final String? route;
  final Color accentColor;
  const _ActionData(this.icon, this.label, this.route, this.accentColor);
}

class _SmartMatchesCard extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;

  const _SmartMatchesCard({required this.isDark, required this.theme});

  @override
  State<_SmartMatchesCard> createState() => _SmartMatchesCardState();
}

class _SmartMatchesCardState extends State<_SmartMatchesCard> with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _floatController;
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _floatController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final theme = widget.theme;

    return AnimatedBuilder(
      animation: Listenable.merge([_glowController, _floatController, _sparkleController]),
      builder: (context, child) {
        final glowValue = _glowController.value;
        final floatOffset = math.sin(_floatController.value * math.pi) * 4;
        final sparkleValue = _sparkleController.value;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRouter.matching),
          child: Transform.translate(
          offset: Offset(0, floatOffset),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
                    : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withAlpha((20 + glowValue * 40).round()),
                  blurRadius: 16 + glowValue * 12,
                  offset: const Offset(0, 8),
                  spreadRadius: glowValue * 2,
                ),
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha((10 + glowValue * 20).round()),
                  blurRadius: 24 + glowValue * 8,
                  offset: Offset(0, 4 + floatOffset),
                ),
              ],
            ),
            child: Row(
              children: [
                // AI icon with sparkle ring
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD54F), size: 28),
                    ),
                    // Orbiting sparkle dots
                    ...List.generate(3, (i) {
                      final angle = (sparkleValue * 2 * math.pi) + (i * 2 * math.pi / 3);
                      final radius = 32.0;
                      final dx = math.cos(angle) * radius;
                      final dy = math.sin(angle) * radius;
                      final opacity = (math.sin(sparkleValue * 2 * math.pi + i) * 0.5 + 0.5);
                      return Positioned(
                        left: 28 + dx,
                        top: 28 + dy,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Color(0xFFFFD54F).withAlpha((opacity * 200).round()),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFD54F).withAlpha((opacity * 100).round()),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI Smart Matches',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Subtle pulsing dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD54F).withAlpha((80 + glowValue * 100).round()),
                                  blurRadius: 4 + glowValue * 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find lost items faster with AI matching',
                        style: TextStyle(
                          color: Colors.white.withAlpha(160),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow with subtle pulse
                Transform.scale(
                  scale: 1.0 + glowValue * 0.08,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((20 + glowValue * 15).round()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
