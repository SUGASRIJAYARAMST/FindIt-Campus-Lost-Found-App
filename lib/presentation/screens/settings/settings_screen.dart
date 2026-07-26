import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(loc.settings),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(theme, isDark, loc.account),
            _buildSettingsCard(
              theme: theme,
              isDark: isDark,
              items: [
                //_SettingsItem(Icons.person_outline_rounded, loc.editProfile, () => Navigator.pushNamed(context, AppRouter.profile)),
                _SettingsItem(Icons.lock_outline_rounded, loc.changePassword, () => _handleChangePassword(context)),
                _SettingsItem(Icons.notifications_outlined, loc.notifications, () => Navigator.pushNamed(context, AppRouter.notifications)),
              ],
            ),
            const SizedBox(height: 12),
            _buildNotificationToggle(theme, isDark, context),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, isDark, loc.app),
            _buildSettingsCard(
              theme: theme,
              isDark: isDark,
              items: [
                _SettingsItem(themeProvider.themeModeIcon, '${loc.theme} (${themeProvider.themeModeLabel})', () => _showThemeDialog(context, themeProvider)),
                _SettingsItem(Icons.language_rounded, '${loc.language} (${langProvider.languageName})', () => _showLanguageDialog(context)),
                _SettingsItem(Icons.info_outline_rounded, loc.about, () => _showAboutDialog(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, isDark, loc.support),
            _buildSettingsCard(
              theme: theme,
              isDark: isDark,
              items: [
                _SettingsItem(Icons.help_outline_rounded, 'Help Desk', () => _showHelpDeskDialog(context)),
                _SettingsItem(Icons.feedback_outlined, loc.sendFeedback, () => _showFeedbackDialog(context)),
                _SettingsItem(Icons.description_outlined, loc.termsOfService, () => _showTermsOfService(context)),
                _SettingsItem(Icons.privacy_tip_outlined, loc.privacyPolicy, () => _showPrivacyPolicy(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildLogoutButton(context, theme, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(ThemeData theme, bool isDark, BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final isEnabled = notificationProvider.isEnabled;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          isEnabled ? 'Notifications Enabled' : 'Notifications Disabled',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        subtitle: Text(
          isEnabled ? 'You will receive push notifications' : 'No push notifications',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (value) async {
            await notificationProvider.toggleNotifications(value);
          },
          activeThumbColor: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required ThemeData theme,
    required bool isDark,
    required List<_SettingsItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: theme.colorScheme.primary, size: 20),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.black26,
                  size: 20,
                ),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 72,
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.chooseTheme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context: context,
              icon: Icons.light_mode_rounded,
              title: loc.light,
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context: context,
              icon: Icons.dark_mode_rounded,
              title: loc.dark,
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context: context,
              icon: Icons.brightness_auto_rounded,
              title: loc.system,
              isSelected: themeProvider.themeMode == ThemeMode.system,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? theme.colorScheme.primary.withAlpha(20) : null,
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final langProvider = context.read<LanguageProvider>();
    final languages = [
      (loc.english, 'en'),
      (loc.tamil, 'ta'),
      (loc.hindi, 'hi'),
      (loc.malayalam, 'ml'),
      (loc.telugu, 'te'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            final isSelected = langProvider.locale.languageCode == lang.$2;
            return ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: isSelected ? Theme.of(context).colorScheme.primary.withAlpha(20) : null,
              leading: Icon(
                Icons.language_rounded,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                lang.$1,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                final locale = LanguageProvider.supportedLocales.values.firstWhere(
                  (l) => l.languageCode == lang.$2,
                );
                langProvider.setLocale(locale);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AboutScreen(loc: loc, isDark: isDark),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final authProvider = context.read<AuthProvider>();

    _cleanupOldFeedback();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.sendFeedback),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.feedbackPrompt,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: loc.feedbackHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.enterFeedback)),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('feedback').add({
                  'uid': authProvider.user?.uid ?? '',
                  'email': authProvider.user?.email ?? '',
                  'message': text,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.thankFeedback),
                      backgroundColor: const Color(0xFF43A047),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send feedback. Try again.')),
                  );
                }
              }
            },
            child: Text(loc.submit, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupOldFeedback() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 15));
      final oldDocs = await FirebaseFirestore.instance
          .collection('feedback')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      for (final doc in oldDocs.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  void _showTermsOfService(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _TermsOfServiceScreen()),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _PrivacyPolicyScreen()),
    );
  }

  void _showHelpDeskDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Help Desk'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContactTile(
              context,
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: '9043035295',
              onTap: () {},
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              context,
              icon: Icons.email_rounded,
              label: 'Email',
              value: 'sugasrijayaramst@gmail.com',
              onTap: () {},
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              context,
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: 'Rajalakshmi Engineering College, Chennai',
              onTap: () {},
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF42A5F5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChangePassword(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    final email = authProvider.user?.email ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: email);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.changePassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.passwordResetContent,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.email,
                  hintText: loc.emailHint2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () async {
                final resetEmail = controller.text.trim();
                if (resetEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.enterEmail)),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await authProvider.resetPassword(resetEmail);
                if (!context.mounted) return;
                if (authProvider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(authProvider.errorMessage!)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.passwordResetSent),
                      backgroundColor: const Color(0xFF43A047),
                    ),
                  );
                }
              },
              child: Text(loc.sendLink, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(loc.signOut),
              content: Text(loc.areYouSureSignOut),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.signOut, style: const TextStyle(color: Color(0xFFE53935))),
                ),
              ],
            ),
          );
          if (!context.mounted) return;
          if (confirmed == true) {
            context.read<UserProvider>().clearUserData();
            await context.read<AuthProvider>().signOut();
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE53935),
          side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          minimumSize: const Size.fromHeight(54),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(loc.logout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingsItem(this.icon, this.title, this.onTap);
}

class _AboutScreen extends StatelessWidget {
  final AppLocalizations loc;
  final bool isDark;
  const _AboutScreen({required this.loc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(loc.about),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withAlpha(80),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              loc.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                loc.version,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                loc.aboutDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2636) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 20 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Features',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFeature(Icons.search_rounded, 'AI-powered item matching', theme.colorScheme.primary),
                    _buildFeature(Icons.location_on_outlined, 'Campus-wide lost & found', const Color(0xFF43A047)),
                    _buildFeature(Icons.notifications_outlined, 'Real-time push notifications', const Color(0xFFFFA726)),
                    _buildFeature(Icons.star_rounded, 'Reward & badge system', const Color(0xFFFFD54F)),
                    _buildFeature(Icons.language_rounded, 'Multi-language support (5 languages)', const Color(0xFF5C6BC0)),
                    _buildFeature(Icons.lock_outline_rounded, 'Secure Firebase authentication', const Color(0xFF26A69A)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2636) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 20 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Built With',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTech('Flutter', 'Cross-platform UI framework'),
                    _buildTech('Firebase', 'Authentication, Firestore, FCM'),
                    _buildTech('Cloudinary', 'Image upload & management'),
                    _buildTech('Provider', 'State management'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              loc.builtWith,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTech(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF42A5F5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$name  ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsOfServiceScreen extends StatelessWidget {
  const _TermsOfServiceScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text('Terms of Service'), centerTitle: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTosHeader(primary),
            const SizedBox(height: 24),
            _buildPolicySection(
              isDark,
              '1. Acceptance of Terms',
              'By accessing and using the FindIt application ("App"), you agree to be bound by these Terms of Service. If you do not agree with any part of these terms, please do not use the App. FindIt is a campus lost and found platform designed for students, faculty, and staff of educational institutions.',
            ),
            _buildPolicySection(
              isDark,
              '2. User Accounts',
              'You must create an account using your valid institutional email address. You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate and complete information during registration and to update it as necessary. One account per user is permitted. Sharing accounts is strictly prohibited.',
            ),
            _buildPolicySection(
              isDark,
              '3. Acceptable Use',
              'You agree to use FindIt only for its intended purpose — reporting and recovering lost or found items on campus. You must not post false, misleading, or fraudulent reports. You must not use the App to harass, threaten, or harm others. Posting offensive, inappropriate, or illegal content is prohibited. Automated access or scraping of the App is not allowed.',
            ),
            _buildPolicySection(
              isDark,
              '4. Item Reports & Claims',
              'When reporting a lost or found item, you must provide accurate and truthful information. False or misleading reports may result in account suspension. When claiming an item, you must be the legitimate owner or an authorized representative. FindIt reserves the right to verify ownership before releasing items. The App facilitates connections between reporters and claimants but is not a party to any item transfer.',
            ),
            _buildPolicySection(
              isDark,
              '5. Rewards & Points',
              'FindIt offers a reward points system to encourage community participation. Points are awarded for activities such as reporting items, returning items, and daily check-ins. Points have no monetary value and cannot be exchanged for cash. FindIt reserves the right to modify or revoke points at its discretion. Abuse of the reward system (e.g., fake reports to earn points) will result in account suspension.',
            ),
            _buildPolicySection(
              isDark,
              '6. Privacy & Data',
              'Your personal data is handled in accordance with our Privacy Policy. We collect only the information necessary to provide the service. Your data is stored securely using Firebase and Cloudflare infrastructure. We do not sell or share your personal data with third parties for marketing purposes. You may request data deletion at any time by contacting our support team.',
            ),
            _buildPolicySection(
              isDark,
              '7. Intellectual Property',
              'All content, design, graphics, and code within the FindIt App are the intellectual property of FindIt. You may not reproduce, distribute, or create derivative works without prior written permission. User-generated content (item reports, feedback) remains your property, but you grant FindIt a license to display and process this content within the App.',
            ),
            _buildPolicySection(
              isDark,
              '8. Limitation of Liability',
              'FindIt is provided "as is" without warranties of any kind. We are not responsible for any loss, damage, or disputes arising from the use of the App or from interactions between users. We do not guarantee the recovery of lost items. FindIt is not liable for any indirect, incidental, or consequential damages.',
            ),
            _buildPolicySection(
              isDark,
              '9. Account Suspension',
              'We reserve the right to suspend or terminate accounts that violate these Terms of Service. Reasons include but are not limited to: fraudulent activity, repeated false reports, harassment, and abuse of the reward system. Suspended users may appeal by contacting our support team.',
            ),
            _buildPolicySection(
              isDark,
              '10. Changes to Terms',
              'FindIt reserves the right to update these Terms of Service at any time. Users will be notified of significant changes through in-app notifications or email. Continued use of the App after changes constitutes acceptance of the revised terms.',
            ),
            _buildPolicySection(
              isDark,
              '11. Contact',
              'For questions about these Terms of Service, please contact us at sugasrijayaramst@gmail.com or visit our Help Desk in the Settings page.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Last updated: July 2026',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTosHeader(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.description_rounded, color: Colors.white, size: 40),
          SizedBox(height: 12),
          Text('Terms of Service', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Please read carefully', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PrivacyPolicyScreen extends StatelessWidget {
  const _PrivacyPolicyScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrivacyHeader(primary),
            const SizedBox(height: 24),
            _buildPolicySection(
              isDark,
              '1. Information We Collect',
              'When you use FindIt, we collect the following information:\n\n• Account Information: Your name, institutional email address, department, and phone number.\n• Profile Data: Profile picture (optional), reward points, and badge status.\n• Item Reports: Details about lost or found items including descriptions, locations, dates, and photos.\n• Usage Data: App interaction patterns, device type, and OS version for performance optimization.\n• Feedback: Any feedback or support messages you submit through the App.',
            ),
            _buildPolicySection(
              isDark,
              '2. How We Use Your Information',
              'We use your information to:\n\n• Provide and maintain the FindIt service.\n• Connect users who have lost or found items.\n• Display item reports to relevant campus communities.\n• Manage your reward points and badges.\n• Send push notifications about item matches and updates.\n• Improve the App through analytics and feedback.\n• Ensure platform safety and prevent abuse.',
            ),
            _buildPolicySection(
              isDark,
              '3. Data Storage & Security',
              'Your data is stored securely using Google Firebase (Cloud Firestore and Firebase Authentication). All data transmissions are encrypted using TLS/SSL. Profile images are stored on Cloudinary with secure URL access. We implement industry-standard security measures to protect your personal information. Regular security audits are conducted to maintain data integrity.',
            ),
            _buildPolicySection(
              isDark,
              '4. Data Sharing',
              'We do not sell your personal data to third parties. We may share your information only in the following cases:\n\n• With other users: Your name and item reports are visible to other campus users to facilitate lost and found recovery.\n• With administrators: Campus admins can access user data for platform management purposes.\n• Legal requirements: If required by law or to protect the safety of our users.',
            ),
            _buildPolicySection(
              isDark,
              '5. Your Data Rights',
              'You have the right to:\n\n• Access your personal data stored in the App.\n• Update or correct your personal information through the Profile page.\n• Request deletion of your account and associated data.\n• Opt out of push notifications in your device settings.\n• Export your data by contacting our support team.',
            ),
            _buildPolicySection(
              isDark,
              '6. Push Notifications',
              'FindIt uses Firebase Cloud Messaging (FCM) to send push notifications about item matches, claim updates, and reward achievements. You can disable notifications in your device settings. Disabling notifications may limit your ability to receive important updates about your reported items.',
            ),
            _buildPolicySection(
              isDark,
              '7. Children\'s Privacy',
              'FindIt is designed for use by college and university students. We do not knowingly collect data from users under the age of 13. If we become aware that a user under 13 has provided personal information, we will take steps to delete such information promptly.',
            ),
            _buildPolicySection(
              isDark,
              '8. Data Retention',
              'Your account data is retained as long as your account is active. Item reports are retained for 30 days after resolution and then automatically archived. Feedback messages are automatically deleted after 15 days. When you delete your account, all associated personal data is permanently removed within 30 days.',
            ),
            _buildPolicySection(
              isDark,
              '9. Changes to This Policy',
              'We may update this Privacy Policy from time to time. Significant changes will be communicated through in-app notifications or email. Your continued use of FindIt after changes are posted constitutes acceptance of the updated policy.',
            ),
            _buildPolicySection(
              isDark,
              '10. Contact Us',
              'If you have any questions about this Privacy Policy or wish to exercise your data rights, please contact us:\n\nEmail: sugasrijayaramst@gmail.com\nPhone: 9043035295\nHelp Desk: Available in the Settings page of the App.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Last updated: July 2026',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyHeader(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 40),
          SizedBox(height: 12),
          Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Your data, your rights', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

Widget _buildPolicySection(bool isDark, String title, String body) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A2636) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 20 : 8),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.65,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    ),
  );
}
