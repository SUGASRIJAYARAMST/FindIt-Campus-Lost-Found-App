import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/item_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/matching_service.dart';
import '../../../domain/models/item_model.dart';

class ItemListScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool autoFocus;
  final VoidCallback? onAutoFocusDone;
  const ItemListScreen({super.key, this.initialTabIndex = 0, this.autoFocus = false, this.onAutoFocusDone});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _selectedCategory = '';
  String _selectedLocation = '';
  String _selectedStatus = '';
  String _sortBy = 'newest';
  bool _showFilters = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const List<String> _categories = [
    'Electronics',
    'Documents',
    'Clothing',
    'Accessories',
    'Bags',
    'Keys',
    'ID Cards',
    'Books',
    'Other',
  ];

  static const List<String> _statuses = [
    'Lost',
    'Found',
    'Claimed',
    'Returned',
    'Recovered',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemProvider>().startListening();
      if (widget.autoFocus) {
        _searchFocusNode.requestFocus();
        widget.onAutoFocusDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemProvider = context.watch<ItemProvider>();

    final locations = itemProvider.items
        .map((i) => i.location)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Items'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Lost'),
            Tab(text: 'Found'),
          ],
        ),
      ),
      body: ClipRect(
        child: Column(
          children: [
            _buildSearchBar(theme, isDark),
            _buildFilterBar(theme, isDark, locations),
            if (_showFilters) _buildFilterPanel(theme, isDark, locations),
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemList(itemProvider, null, theme, isDark),
                  _buildItemList(itemProvider, 'lost', theme, isDark),
                  _buildItemList(itemProvider, 'found', theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AIGlowFAB(onTap: () => _showAISearchDialog(context, theme, isDark)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(200)],
              ),
            ),
            child: FloatingActionButton.extended(
              heroTag: 'item_list_fab',
              onPressed: () => Navigator.pushNamed(context, AppRouter.uploadItem),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black26),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black26, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1A2636) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark, List<String> locations) {
    final hasActiveFilters = _selectedCategory.isNotEmpty || _selectedLocation.isNotEmpty || _selectedStatus.isNotEmpty || _dateFrom != null || _dateTo != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showFilters || hasActiveFilters
                    ? theme.colorScheme.primary.withAlpha(25)
                    : isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showFilters || hasActiveFilters
                      ? theme.colorScheme.primary.withAlpha(60)
                      : isDark
                          ? Colors.white.withAlpha(12)
                          : const Color(0xFFE8E9ED),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: _showFilters || hasActiveFilters
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showFilters || hasActiveFilters
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${(_selectedCategory.isNotEmpty ? 1 : 0) + (_selectedLocation.isNotEmpty ? 1 : 0) + (_selectedStatus.isNotEmpty ? 1 : 0) + ((_dateFrom != null || _dateTo != null) ? 1 : 0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedCategory.isNotEmpty)
                    _buildFilterChip(_selectedCategory, () {
                      setState(() => _selectedCategory = '');
                    }, theme),
                  if (_selectedCategory.isNotEmpty && _selectedLocation.isNotEmpty)
                    const SizedBox(width: 6),
                  if (_selectedLocation.isNotEmpty)
                    _buildFilterChip(_selectedLocation, () {
                      setState(() => _selectedLocation = '');
                    }, theme),
                  if (_selectedLocation.isNotEmpty && _selectedStatus.isNotEmpty)
                    const SizedBox(width: 6),
                  if (_selectedStatus.isNotEmpty)
                    _buildFilterChip(_selectedStatus, () {
                      setState(() => _selectedStatus = '');
                    }, theme),
                  if (_selectedStatus.isNotEmpty && (_dateFrom != null || _dateTo != null))
                    const SizedBox(width: 6),
                  if (_dateFrom != null || _dateTo != null)
                    _buildFilterChip(
                      _dateFrom != null && _dateTo != null
                          ? '${_dateFrom!.day}/${_dateFrom!.month} - ${_dateTo!.day}/${_dateTo!.month}'
                          : _dateFrom != null
                              ? 'From ${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}'
                              : 'Until ${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}',
                      () => setState(() { _dateFrom = null; _dateTo = null; }),
                      theme,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showSortDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(8) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    _dateFrom != null || _dateTo != null ? 'Filtered' : (_sortBy == 'newest' ? 'Newest' : 'Oldest'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
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

  Widget _buildFilterPanel(ThemeData theme, bool isDark, List<String> locations) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.22,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = isSelected ? '' : cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withAlpha(10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withAlpha(30),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Location',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              if (locations.isEmpty)
                Text(
                  'No locations available',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: locations.map((loc) {
                    final isSelected = _selectedLocation == loc;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLocation = isSelected ? '' : loc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.secondary.withAlpha(10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.secondary.withAlpha(30),
                          ),
                        ),
                        child: Text(
                          loc,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses.map((status) {
                  final isSelected = _selectedStatus == status;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStatus = isSelected ? '' : status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFA726)
                            : const Color(0xFFFFA726).withAlpha(10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFA726)
                              : const Color(0xFFFFA726).withAlpha(30),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFFFFA726),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = '';
                      _selectedLocation = '';
                      _selectedStatus = '';
                    });
                  },
                  child: Text(
                    'Clear All Filters',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(ItemProvider provider, String? typeFilter, ThemeData theme, bool isDark) {
    var items = provider.filterItems(
      type: typeFilter,
      category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
      location: _selectedLocation.isNotEmpty ? _selectedLocation : null,
      status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
      searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    if (_dateFrom != null || _dateTo != null) {
      items = items.where((item) {
        final itemDate = item.itemDate ?? item.createdAt;
        if (itemDate == null) return false;
        if (_dateFrom != null && itemDate.isBefore(_dateFrom!)) return false;
        if (_dateTo != null) {
          final endOfDay = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
          if (itemDate.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
    }

    if (_sortBy == 'oldest') {
      items = items.reversed.toList();
    }

    if (items.isEmpty) {
      return _buildEmptyState(theme, isDark, typeFilter);
    }

    return RefreshIndicator(
      onRefresh: () async {
        provider.startListening();
      },
      color: theme.colorScheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildItemCard(items[index], theme, isDark),
      ),
    );
  }

  Widget _buildItemCard(ItemModel item, ThemeData theme, bool isDark) {
    final isLost = item.type == 'lost';
    final accentColor = isLost ? const Color(0xFFE53935) : const Color(0xFF43A047);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.itemDetail, arguments: item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            _buildItemThumb(item, accentColor, isDark),
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
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(item.statusDisplay, accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(item.createdAt),
                        style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                      ),
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

  Widget _buildItemThumb(ItemModel item, Color accentColor, bool isDark) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: accentColor.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
      ),
              child: item.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: accentColor.withAlpha(25)),
                  errorWidget: (_, _, _) => Icon(item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded, color: accentColor, size: 26)),
            )
          : Icon(
              item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
              color: accentColor,
              size: 26,
            ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark, String? type) {
    String title;
    String subtitle;
    if (type == 'lost') {
      title = 'No lost items';
      subtitle = 'No lost items have been reported yet.';
    } else if (type == 'found') {
      title = 'No found items';
      subtitle = 'No found items have been reported yet.';
    } else {
      title = 'No items yet';
      subtitle = 'Tap + to report a lost or found item.';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 200;
        final iconSize = compact ? 56.0 : 80.0;
        final iconInner = compact ? 28.0 : 40.0;
        final topGap = compact ? 12.0 : 20.0;
        final bottomGap = compact ? 6.0 : 8.0;
        final titleSize = compact ? 14.0 : 16.0;
        final subtitleSize = compact ? 12.0 : 13.0;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary.withAlpha(100), size: iconInner),
                ),
                SizedBox(height: topGap),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: bottomGap),
                Text(
                  subtitle,
                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: subtitleSize),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSortDialog() {
    DateTime? tempFrom = _dateFrom;
    DateTime? tempTo = _dateTo;
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort & Date Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => tempSort = 'newest'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tempSort == 'newest' ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempSort == 'newest'
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.primary.withAlpha(40),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Newest',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tempSort == 'newest' ? Colors.white : Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => tempSort = 'oldest'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tempSort == 'oldest' ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempSort == 'oldest'
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Theme.of(ctx).colorScheme.primary.withAlpha(40),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Oldest',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tempSort == 'oldest' ? Colors.white : Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Filter by Item Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: tempTo ?? DateTime.now(),
                            );
                            if (picked != null) setSheetState(() => tempFrom = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: tempFrom != null
                                  ? Theme.of(ctx).colorScheme.primary.withAlpha(15)
                                  : sheetDark ? Colors.white.withAlpha(8) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempFrom != null
                                    ? Theme.of(ctx).colorScheme.primary
                                    : sheetDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16,
                                    color: tempFrom != null ? Theme.of(ctx).colorScheme.primary : Colors.black38),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tempFrom != null
                                        ? '${tempFrom!.day}/${tempFrom!.month}/${tempFrom!.year}'
                                        : 'From Date',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: tempFrom != null
                                          ? Theme.of(ctx).colorScheme.primary
                                          : Colors.black38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black38),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempTo ?? DateTime.now(),
                              firstDate: tempFrom ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setSheetState(() => tempTo = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: tempTo != null
                                  ? Theme.of(ctx).colorScheme.primary.withAlpha(15)
                                  : sheetDark ? Colors.white.withAlpha(8) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempTo != null
                                    ? Theme.of(ctx).colorScheme.primary
                                    : sheetDark ? Colors.white.withAlpha(12) : const Color(0xFFE8E9ED),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16,
                                    color: tempTo != null ? Theme.of(ctx).colorScheme.primary : Colors.black38),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tempTo != null
                                        ? '${tempTo!.day}/${tempTo!.month}/${tempTo!.year}'
                                        : 'To Date',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: tempTo != null
                                          ? Theme.of(ctx).colorScheme.primary
                                          : Colors.black38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (tempFrom != null || tempTo != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() { tempFrom = null; tempTo = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withAlpha(40)),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Clear Dates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                          ),
                        ),
                      ),
                    if (tempFrom != null || tempTo != null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                           setState(() {
                            _sortBy = tempSort;
                            _dateFrom = tempFrom;
                            _dateTo = tempTo;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
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
    final itemProvider = context.read<ItemProvider>();
    final foundItems = itemProvider.foundItems.where((i) => i.status == 'found').toList();

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
                    ? _buildEmptyResults(theme, isDark, queryName)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: results.length,
                        itemBuilder: (ctx, i) => _buildResultCard(ctx, results[i], theme, isDark),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyResults(ThemeData theme, bool isDark, String queryName) {
    return Center(
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
    );
  }

  Widget _buildResultCard(BuildContext ctx, MatchResult result, ThemeData theme, bool isDark) {
    final item = result.foundItem;
    final score = result.score.round();
    final scoreColor = score >= 80 ? const Color(0xFF43A047) : score >= 60 ? const Color(0xFFFFA726) : const Color(0xFF42A5F5);

    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        Navigator.pushNamed(ctx, AppRouter.itemDetail, arguments: item.id);
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
  }

}

class _AIGlowFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _AIGlowFAB({required this.onTap});

  @override
  State<_AIGlowFAB> createState() => _AIGlowFABState();
}

class _AIGlowFABState extends State<_AIGlowFAB> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final v = _pulseController.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha((30 + (v * 50)).round()),
                  blurRadius: 8 + v * 8,
                  spreadRadius: v * 3,
                ),
                BoxShadow(
                  color: const Color(0xFF0D47A1).withAlpha((20 + (v * 30)).round()),
                  blurRadius: 12 + v * 6,
                  spreadRadius: v * 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
        );
      },
    );
  }
}
