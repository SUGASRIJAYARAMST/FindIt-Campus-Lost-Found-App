import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/matching_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/matching_service.dart';
import '../../../domain/models/item_model.dart';
import '../../../l10n/app_localizations.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  late final MatchingProvider _matchingProvider;
  String _sortBy = 'score';
  double _minScore = 0;
  double _maxScore = 100;
  String _categoryFilter = 'All';
  bool _showFilters = false;

  final _categories = ['All', 'Electronics', 'Documents', 'Clothing', 'Accessories', 'Bags', 'Keys', 'ID Cards', 'Books', 'Other'];

  @override
  void initState() {
    super.initState();
    _matchingProvider = context.read<MatchingProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _matchingProvider.startListening();
    });
  }

  @override
  void dispose() {
    _matchingProvider.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matchingProvider = context.watch<MatchingProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Smart Matches'),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => _showAISearchDialog(context, theme, isDark),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 22),
            ),
          ),
          if (matchingProvider.isMatching)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => matchingProvider.runManualMatch(),
            ),
        ],
      ),
      body: matchingProvider.isMatching && matchingProvider.matches.isEmpty
          ? _buildLoadingState(theme, isDark)
          : matchingProvider.matches.isEmpty
              ? RefreshIndicator(
                  onRefresh: () async => matchingProvider.runManualMatch(),
                  color: theme.colorScheme.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      _buildEmptyState(context, theme, isDark),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => matchingProvider.runManualMatch(),
                  color: theme.colorScheme.primary,
                  child: _buildMatchList(matchingProvider, theme, isDark),
                ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing matches...',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparing lost and found items',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, bool isDark) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.primary.withAlpha(150),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Matches Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Report a lost item and a found item to let AI find matches for you.',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRouter.uploadLost),
                icon: const Icon(Icons.report_problem_rounded, size: 18),
                label: Text(loc.reportLost),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRouter.uploadFound),
                icon: const Icon(Icons.search_off_rounded, size: 18),
                label: Text(loc.reportFound),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList(MatchingProvider provider, ThemeData theme, bool isDark) {
    var filtered = provider.matches.where((m) => m.score >= _minScore && m.score <= _maxScore).toList();

    if (_categoryFilter != 'All') {
      filtered = filtered.where((m) =>
        m.lostItem.category == _categoryFilter || m.foundItem.category == _categoryFilter
      ).toList();
    }

    if (_sortBy == 'score') {
      filtered.sort((a, b) => b.score.compareTo(a.score));
    } else if (_sortBy == 'newest') {
      filtered.sort((a, b) {
        final aDate = a.lostItem.createdAt ?? a.lostItem.itemDate;
        final bDate = b.lostItem.createdAt ?? b.lostItem.itemDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    } else if (_sortBy == 'oldest') {
      filtered.sort((a, b) {
        final aDate = a.lostItem.createdAt ?? a.lostItem.itemDate;
        final bDate = b.lostItem.createdAt ?? b.lostItem.itemDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF43A047), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filtered.length} Potential Matches',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'AI-powered matching results',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // How It Works info
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withAlpha(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI matches based on item name, category, description, location & date',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.primary.withAlpha(180)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Filter controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Sort row
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('Best Score', Icons.trending_up_rounded, _sortBy == 'score', () {
                      setState(() => _sortBy = 'score');
                    }, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Newest', Icons.new_releases_outlined, _sortBy == 'newest', () {
                      setState(() => _sortBy = 'newest');
                    }, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Oldest', Icons.history_rounded, _sortBy == 'oldest', () {
                      setState(() => _sortBy = 'oldest');
                    }, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Score range dropdown + filter button row
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showScoreRangeSheet(context, isDark, theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _scoreLabel() != 'All Scores'
                              ? theme.colorScheme.primary.withAlpha(25)
                              : isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _scoreLabel() != 'All Scores'
                                ? theme.colorScheme.primary.withAlpha(80)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _scoreLabel() != 'All Scores' ? Icons.star_rounded : Icons.filter_list_rounded,
                              size: 14,
                              color: _scoreLabel() != 'All Scores'
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _scoreLabel(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _scoreLabel() != 'All Scores'
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white54 : Colors.black45),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: _scoreLabel() != 'All Scores'
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _showFilters = !_showFilters),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _showFilters || _categoryFilter != 'All'
                              ? theme.colorScheme.primary.withAlpha(25)
                              : isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showFilters || _categoryFilter != 'All'
                                ? theme.colorScheme.primary.withAlpha(60)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _showFilters || _categoryFilter != 'All'
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter panel (expandable)
              if (_showFilters) ...[
                const SizedBox(height: 10),
                _buildFilterPanel(theme, isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? _buildNoMatchFilterState(isDark, theme)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final match = filtered[index];
                    return _buildMatchCard(match, theme, isDark, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoMatchFilterState(bool isDark, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 12),
          Text(
            'No matches in this filter',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing the score or category filter',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white24 : Colors.black26),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 15 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              if (_categoryFilter != 'All')
                GestureDetector(
                  onTap: () => setState(() => _categoryFilter = 'All'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE53935)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Category',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = _categoryFilter == cat;
              return GestureDetector(
                onTap: () => setState(() => _categoryFilter = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withAlpha(30),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF43A047).withAlpha(25)
              : isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF43A047).withAlpha(80) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF43A047) : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF43A047) : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(MatchResult match, ThemeData theme, bool isDark, int index) {
    final scoreColor = _getScoreColor(match.score);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showMatchDialog(context, match, isDark, theme),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2636) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scoreColor.withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scoreColor.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildScoreHeader(match, scoreColor, theme, isDark),
              _buildMatchContent(match, theme, isDark),
              _buildExplanation(match, scoreColor, isDark, theme),
              _buildTimestamp(match, isDark),
              _buildShareRow(match, isDark),
              _buildFactorBreakdown(match, theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHeader(MatchResult match, Color scoreColor, ThemeData theme, bool isDark) {
    final score = match.score.round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scoreColor.withAlpha(15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: match.score / 100,
                  strokeWidth: 5,
                  backgroundColor: scoreColor.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: scoreColor),
                    const SizedBox(width: 6),
                    Text(
                      _getScoreLabel(match.score),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.lostItem.title} ↔ ${match.foundItem.title}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchContent(MatchResult match, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildItemMini(
              title: match.lostItem.title,
              category: match.lostItem.category,
              type: 'Lost',
              color: const Color(0xFFE53935),
              imageUrl: match.lostItem.imageUrl,
              isDark: isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getScoreColor(match.score).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: _getScoreColor(match.score),
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: _buildItemMini(
              title: match.foundItem.title,
              category: match.foundItem.category,
              type: 'Found',
              color: const Color(0xFF43A047),
              imageUrl: match.foundItem.imageUrl,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemMini({
    required String title,
    required String category,
    required String type,
    required Color color,
    required String imageUrl,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: color.withAlpha(25)),
                      errorWidget: (_, _, _) => Icon(Icons.help_outline_rounded, color: color, size: 28)),
                )
              : Icon(Icons.help_outline_rounded, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildFactorBreakdown(MatchResult match, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildFactorBar('Name', match.factors['title'] ?? 0, const Color(0xFF5C6BC0), isDark),
          _buildFactorBar('Category', match.factors['category'] ?? 0, const Color(0xFF26A69A), isDark),
          _buildFactorBar('Description', match.factors['description'] ?? 0, const Color(0xFFFFA726), isDark),
          _buildFactorBar('Location', match.factors['location'] ?? 0, const Color(0xFF42A5F5), isDark),
          _buildFactorBar('Date', match.factors['date'] ?? 0, const Color(0xFFAB47BC), isDark),
        ],
      ),
    );
  }

  Widget _buildExplanation(MatchResult match, Color scoreColor, bool isDark, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scoreColor.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 14, color: scoreColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                match.explanation,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scoreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(MatchResult match, bool isDark) {
    final diff = DateTime.now().difference(match.matchedAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 4),
          Text(
            'Matched $timeAgo',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildShareRow(MatchResult match, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => _shareMatch(match),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 6),
              Text('Share Match', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  void _shareMatch(MatchResult match) {
    final text = 'Found a possible match on FindIt!\n\n'
        'Lost: ${match.lostItem.title}\n'
        'Found: ${match.foundItem.title}\n'
        'Match Score: ${match.score.round()}%\n'
        '${match.explanation}\n\n'
        'Open FindIt to claim this item!';
    Share.share(text);
  }

  Widget _buildFactorBar(String label, double value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(BuildContext context, MatchResult match, bool isDark, ThemeData theme) {
    final scoreColor = _getScoreColor(match.score);
    final score = match.score.round();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$score%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: scoreColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getScoreLabel(match.score),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: scoreColor),
            ),
            const SizedBox(height: 16),
            _buildMatchItemOption(
              context: context,
              title: match.lostItem.title,
              category: match.lostItem.category,
              type: 'Lost',
              color: const Color(0xFFE53935),
              imageUrl: match.lostItem.imageUrl,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRouter.itemDetail, arguments: match.lostItem.id);
              },
            ),
            const SizedBox(height: 10),
            _buildMatchItemOption(
              context: context,
              title: match.foundItem.title,
              category: match.foundItem.category,
              type: 'Found',
              color: const Color(0xFF43A047),
              imageUrl: match.foundItem.imageUrl,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRouter.itemDetail, arguments: match.foundItem.id);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRouter.itemDetail, arguments: match.lostItem.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Claim Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchItemOption({
    required BuildContext context,
    required String title,
    required String category,
    required String type,
    required Color color,
    required String imageUrl,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF152030) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: color.withAlpha(20)),
                          errorWidget: (_, _, _) => Icon(Icons.help_outline_rounded, color: color, size: 24)),
                    )
                  : Icon(Icons.help_outline_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(category, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF43A047);
    if (score >= 60) return const Color(0xFFFFA726);
    if (score >= 40) return const Color(0xFFFF7043);
    return const Color(0xFFE53935);
  }

  String _scoreLabel() {
    if (_minScore == 0 && _maxScore == 100) return 'All Scores';
    return '${_minScore.round()} - ${_maxScore.round()}%';
  }

  void _showScoreRangeSheet(BuildContext context, bool isDark, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Score Range', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildScoreOption(ctx, 'All Scores', 0, 100, Icons.filter_list_rounded, sheetDark, theme),
                const SizedBox(height: 8),
                _buildScoreOption(ctx, '70 - 100%', 70, 100, Icons.star_rounded, sheetDark, theme),
                const SizedBox(height: 8),
                _buildScoreOption(ctx, '40 - 60%', 40, 60, Icons.thumb_up_outlined, sheetDark, theme),
                const SizedBox(height: 8),
                _buildScoreOption(ctx, '10 - 40%', 10, 40, Icons.trending_down_rounded, sheetDark, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreOption(BuildContext ctx, String label, double min, double max, IconData icon, bool isDark, ThemeData theme) {
    final selected = _minScore == min && _maxScore == max;
    final color = selected ? theme.colorScheme.primary : (isDark ? Colors.white54 : Colors.black45);
    return GestureDetector(
      onTap: () {
        setState(() { _minScore = min; _maxScore = max; });
        Navigator.pop(ctx);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary.withAlpha(60) : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 20, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return 'Excellent Match';
    if (score >= 60) return 'Good Match';
    if (score >= 40) return 'Possible Match';
    return 'Weak Match';
  }

  void _showAISearchDialog(BuildContext context, ThemeData theme, bool isDark) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Other';
    DateTime? selectedDate;

    final categories = [
      'Electronics', 'Documents', 'Clothing', 'Accessories',
      'Bags', 'Keys', 'ID Cards', 'Books', 'Other',
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final dialogDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: dialogDark ? const Color(0xFF1A2636) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: StatefulBuilder(
              builder: (ctx, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('AI Quick Search', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: dialogDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 18, color: dialogDark ? Colors.white54 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Describe what you lost and we\'ll find matches',
                        style: TextStyle(fontSize: 13, color: dialogDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: dialogDark ? Colors.white : Colors.black87, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Item name (e.g. Blue Backpack)',
                              hintStyle: TextStyle(color: dialogDark ? Colors.white38 : Colors.black26),
                              prefixIcon: Icon(Icons.search_rounded, color: dialogDark ? Colors.white38 : Colors.black26, size: 22),
                              filled: true,
                              fillColor: dialogDark ? Colors.white.withAlpha(8) : const Color(0xFFF5F6FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: dialogDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descController,
                            maxLines: 2,
                            style: TextStyle(color: dialogDark ? Colors.white : Colors.black87, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Description (color, brand, where lost...)',
                              hintStyle: TextStyle(color: dialogDark ? Colors.white38 : Colors.black26),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 20),
                                child: Icon(Icons.description_outlined, color: dialogDark ? Colors.white38 : Colors.black26, size: 22),
                              ),
                              filled: true,
                              fillColor: dialogDark ? Colors.white.withAlpha(8) : const Color(0xFFF5F6FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: dialogDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setDialogState(() => selectedDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: selectedDate != null
                                    ? theme.colorScheme.primary.withAlpha(15)
                                    : dialogDark ? Colors.white.withAlpha(8) : const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedDate != null
                                      ? theme.colorScheme.primary
                                      : dialogDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 18,
                                    color: selectedDate != null ? theme.colorScheme.primary : (dialogDark ? Colors.white38 : Colors.black26)),
                                  const SizedBox(width: 10),
                                  Text(
                                    selectedDate != null
                                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                        : 'When did you lose it? (optional)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selectedDate != null
                                          ? theme.colorScheme.primary
                                          : (dialogDark ? Colors.white38 : Colors.black26),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (selectedDate != null)
                                    GestureDetector(
                                      onTap: () => setDialogState(() => selectedDate = null),
                                      child: Icon(Icons.close_rounded, size: 16, color: dialogDark ? Colors.white38 : Colors.black38),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Category',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dialogDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: categories.map((cat) {
                              final selected = selectedCategory == cat;
                              return GestureDetector(
                                onTap: () => setDialogState(() => selectedCategory = cat),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? theme.colorScheme.primary : theme.colorScheme.primary.withAlpha(10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected ? theme.colorScheme.primary : theme.colorScheme.primary.withAlpha(30),
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? Colors.white : theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          if (nameController.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          _runAISearch(
                            context, theme, isDark,
                            nameController.text.trim(),
                            descController.text.trim(),
                            selectedCategory,
                            selectedDate,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(200)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Find Matches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
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

  void _runAISearch(BuildContext context, ThemeData theme, bool isDark, String name, String description, String category, DateTime? date) {
    final matchingProvider = context.read<MatchingProvider>();
    final foundItems = matchingProvider.foundItems;

    if (foundItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('No Items to Search'),
          content: const Text('No found items available to match against right now.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final searchItem = ItemModel(
      id: 'search',
      title: name,
      category: category,
      description: description.isNotEmpty ? description : name,
      location: '',
      contactNumber: '',
      type: 'lost',
      itemDate: date,
      createdBy: '',
      createdByUid: '',
    );

    final matchingService = MatchingService();
    final results = matchingService.findMatchesForItem(
      item: searchItem,
      oppositeItems: foundItems,
      maxResults: 10,
      minScore: 10,
    );

    _showAIResultsDialog(context, theme, isDark, name, results);
  }

  void _showAIResultsDialog(BuildContext context, ThemeData theme, bool isDark, String queryName, List<MatchResult> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AI Search Results', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(
                            'Results for "$queryName"',
                            style: TextStyle(fontSize: 12, color: sheetDark ? Colors.white38 : Colors.black38),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${results.length} match${results.length == 1 ? '' : 'es'}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.search_off_rounded, color: theme.colorScheme.primary.withAlpha(100), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matches found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No similar items matched "$queryName"',
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: results.length,
                        itemBuilder: (ctx, i) {
                          final result = results[i];
                          final item = result.foundItem;
                          final score = result.score.round();
                          final scoreColor = score >= 80 ? const Color(0xFF43A047) : score >= 60 ? const Color(0xFFFFA726) : const Color(0xFF42A5F5);

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(context, AppRouter.itemDetail, arguments: item.id);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2636) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: scoreColor.withAlpha(30)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withAlpha(isDark ? 15 : 5), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(color: scoreColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                    child: item.imageUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover,
                                              placeholder: (_, _) => Container(color: scoreColor.withAlpha(20)),
                                              errorWidget: (_, _, _) => Icon(Icons.search_off_rounded, color: scoreColor, size: 24)),
                                          )
                                        : Icon(Icons.search_off_rounded, color: scoreColor, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                item.location.isNotEmpty ? item.location : 'Unknown location',
                                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.category,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(
                                          color: scoreColor.withAlpha(20),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: scoreColor.withAlpha(60)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$score%',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scoreColor),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Match',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scoreColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
