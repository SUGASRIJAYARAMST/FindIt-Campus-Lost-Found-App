import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/archive_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../domain/models/item_model.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArchiveProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final archiveProvider = context.watch<ArchiveProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131F) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Archived Items', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          archiveProvider.startListening();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: theme.colorScheme.primary,
        child: archiveProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : archiveProvider.archivedItems.isEmpty
                ? _buildEmptyState(isDark, theme)
                : _buildArchivedList(archiveProvider, theme, isDark),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.archive_outlined,
                  size: 48,
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Archived Items',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Items are automatically archived after being resolved for 20+ days',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 8),
                    Text(
                      'Resolved items auto-archive after 20 days',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedList(ArchiveProvider archiveProvider, ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archiveProvider.archivedItems.length,
      itemBuilder: (context, index) {
        final item = archiveProvider.archivedItems[index];
        return _buildArchivedCard(item, archiveProvider, theme, isDark);
      },
    );
  }

  Widget _buildArchivedCard(ItemModel item, ArchiveProvider archiveProvider, ThemeData theme, bool isDark) {
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: item.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: accentColor.withAlpha(25)),
                      errorWidget: (_, _, _) => Icon(
                        item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                  )
                : Icon(
                    item.type == 'lost' ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
                    color: accentColor,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'unarchive') {
                await archiveProvider.unarchiveItem(item.id);
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Archived Item'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await archiveProvider.deleteArchivedItem(item.id);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'unarchive', child: Text('Restore')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFE53935)))),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
