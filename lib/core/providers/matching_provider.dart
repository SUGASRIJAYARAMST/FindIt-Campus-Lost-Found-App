import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/item_model.dart';
import '../services/matching_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Notification Tiers
// ---------------------------------------------------------------------------

enum NotificationTier {
  /// Score 90-100: Send immediately, high confidence match.
  immediateCritical,

  /// Score 75-89: Send immediately, good match.
  immediateHigh,

  /// Score 60-74: Collect and send as daily summary.
  dailySummary,

  /// Score < 60: Do not notify.
  silent,
}

class NotificationTierConfig {
  final double minScore;
  final double maxScore;
  final NotificationTier tier;
  final String label;

  const NotificationTierConfig({
    required this.minScore,
    required this.maxScore,
    required this.tier,
    required this.label,
  });

  static const List<NotificationTierConfig> tiers = [
    NotificationTierConfig(minScore: 90, maxScore: 100, tier: NotificationTier.immediateCritical, label: 'Critical Match'),
    NotificationTierConfig(minScore: 75, maxScore: 89.99, tier: NotificationTier.immediateHigh, label: 'High Match'),
    NotificationTierConfig(minScore: 60, maxScore: 74.99, tier: NotificationTier.dailySummary, label: 'Summary Match'),
    NotificationTierConfig(minScore: 0, maxScore: 59.99, tier: NotificationTier.silent, label: 'Silent'),
  ];

  static NotificationTier classify(double score) {
    for (final tier in tiers) {
      if (score >= tier.minScore && score <= tier.maxScore) {
        return tier.tier;
      }
    }
    return NotificationTier.silent;
  }

  static String classifyLabel(double score) {
    for (final tier in tiers) {
      if (score >= tier.minScore && score <= tier.maxScore) {
        return tier.label;
      }
    }
    return 'Silent';
  }
}

// ---------------------------------------------------------------------------
// Notification Deduplication Key
// ---------------------------------------------------------------------------

class NotificationDedupKey {
  final String lostItemId;
  final String foundItemId;

  const NotificationDedupKey(this.lostItemId, this.foundItemId);

  String get key => '${lostItemId}_$foundItemId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationDedupKey &&
          lostItemId == other.lostItemId &&
          foundItemId == other.foundItemId;

  @override
  int get hashCode => lostItemId.hashCode ^ foundItemId.hashCode;
}

// ---------------------------------------------------------------------------
// Notification Strategy
// ---------------------------------------------------------------------------

class NotificationStrategy {
  final FirestoreService firestoreService;
  final NotificationService? notificationService;

  /// Tracks pairs that have already been notified (in-memory cache).
  final Set<String> _notifiedPairs = {};

  /// Daily summary buffer: userId → list of summary items.
  final Map<String, List<_DailySummaryItem>> _dailySummaryBuffer = {};

  Timer? _dailySummaryTimer;

  NotificationStrategy({
    required this.firestoreService,
    this.notificationService,
  });

  /// Start the daily summary timer (checks every hour for pending summaries).
  void startDailySummaryTimer() {
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _flushDailySummaries();
    });
  }

  /// Stop the daily summary timer.
  void stopDailySummaryTimer() {
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = null;
  }

  /// Process a list of matches and send notifications according to tier rules.
  Future<void> processMatches(List<MatchResult> matches) async {
    // Load previously notified pairs from Firestore
    await _loadNotifiedPairs();

    for (final match in matches) {
      final tier = NotificationTierConfig.classify(match.score);
      final dedupKey = NotificationDedupKey(
        match.lostItem.id,
        match.foundItem.id,
      );

      // Skip if already notified
      if (_notifiedPairs.contains(dedupKey.key)) continue;

      switch (tier) {
        case NotificationTier.immediateCritical:
          await _sendImmediateNotification(match, isCritical: true);
          _notifiedPairs.add(dedupKey.key);
          break;

        case NotificationTier.immediateHigh:
          await _sendImmediateNotification(match, isCritical: false);
          _notifiedPairs.add(dedupKey.key);
          break;

        case NotificationTier.dailySummary:
          _addToDailySummary(match);
          break;

        case NotificationTier.silent:
          // Do nothing
          break;
      }
    }
  }

  /// Send an immediate notification for high/critical matches.
  Future<void> _sendImmediateNotification(
    MatchResult match, {
    required bool isCritical,
  }) async {
    if (notificationService == null) return;

    final ownerUid = match.lostItem.createdByUid;
    if (ownerUid.isEmpty) return;

    final title = isCritical
        ? 'High Confidence Match Found!'
        : 'Possible Match Found!';

    final body = '"${match.foundItem.title}" may match your lost '
        '"${match.lostItem.title}" (${match.score.round()}% match)';

    await notificationService!.sendNotificationToUser(
      targetUid: ownerUid,
      title: title,
      body: body,
      data: {
        'itemId': match.lostItem.id,
        'type': 'match',
        'tier': isCritical ? 'critical' : 'high',
        'score': match.score.round(),
      },
    );

    debugPrint('Immediate notification sent: ${isCritical ? "critical" : "high"} '
        'score=${match.score.round()}% pair=${match.lostItem.id}_${match.foundItem.id}');
  }

  /// Add a match to the daily summary buffer.
  void _addToDailySummary(MatchResult match) {
    final ownerUid = match.lostItem.createdByUid;
    if (ownerUid.isEmpty) return;

    _dailySummaryBuffer.putIfAbsent(ownerUid, () => []).add(
      _DailySummaryItem(
        lostItemTitle: match.lostItem.title,
        foundItemTitle: match.foundItem.title,
        score: match.score,
        lostItemId: match.lostItem.id,
        matchedAt: match.matchedAt,
      ),
    );

    debugPrint('Added to daily summary: score=${match.score.round()}% '
        'for user=$ownerUid');
  }

  /// Flush daily summaries (send one notification per user with all pending matches).
  Future<void> _flushDailySummaries() async {
    if (_dailySummaryBuffer.isEmpty) return;
    if (notificationService == null) return;

    final buffer = Map<String, List<_DailySummaryItem>>.from(_dailySummaryBuffer);
    _dailySummaryBuffer.clear();

    for (final entry in buffer.entries) {
      final uid = entry.key;
      final items = entry.value;

      if (items.isEmpty) continue;

      final count = items.length;
      final topMatch = items.reduce((a, b) => a.score > b.score ? a : b);

      final title = '$count New Match${count > 1 ? 'es' : ''} Found';

      final bodyBuf = StringBuffer();
      bodyBuf.write('"${topMatch.foundItemTitle}" matches your lost '
          '"${topMatch.lostItemTitle}" (${topMatch.score.round()}%)');
      if (count > 1) {
        bodyBuf.write(' and ${count - 1} more');
      }

      await notificationService!.sendNotificationToUser(
        targetUid: uid,
        title: title,
        body: bodyBuf.toString(),
        data: {
          'type': 'match_summary',
          'count': count,
        },
      );

      debugPrint('Daily summary sent to $uid: $count matches');
    }
  }

  /// Load previously notified pairs from Firestore to avoid re-notification.
  Future<void> _loadNotifiedPairs() async {
    try {
      final existing = await firestoreService
          .collection('notifications')
          .where('type', isEqualTo: 'match')
          .get();

      for (final doc in existing.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final itemId = data['itemId'] as String? ?? '';
        final body = data['body'] as String? ?? '';

        // Extract found item ID from body if possible
        if (itemId.isNotEmpty && body.isNotEmpty) {
          // Mark as notified to prevent re-sending
          _notifiedPairs.add(itemId);
        }
      }
    } catch (e) {
      debugPrint('Error loading notified pairs: $e');
    }
  }

  /// Clear all cached state.
  void reset() {
    _notifiedPairs.clear();
    _dailySummaryBuffer.clear();
    _dailySummaryTimer?.cancel();
  }

  void dispose() {
    stopDailySummaryTimer();
    _notifiedPairs.clear();
    _dailySummaryBuffer.clear();
  }
}

class _DailySummaryItem {
  final String lostItemTitle;
  final String foundItemTitle;
  final double score;
  final String lostItemId;
  final DateTime matchedAt;

  const _DailySummaryItem({
    required this.lostItemTitle,
    required this.foundItemTitle,
    required this.score,
    required this.lostItemId,
    required this.matchedAt,
  });
}

// ---------------------------------------------------------------------------
// MatchingProvider
// ---------------------------------------------------------------------------

class MatchingProvider extends ChangeNotifier {
  final FirestoreService firestoreService;
  final NotificationService? notificationService;
  final MatchingService _matchingService = MatchingService();
  late final NotificationStrategy _notificationStrategy;

  List<MatchResult> _matches = [];
  final Set<String> _dismissedMatches = {};
  bool _isMatching = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _lostSub;
  StreamSubscription<QuerySnapshot>? _foundSub;
  List<ItemModel> _lostItems = [];
  List<ItemModel> _foundItems = [];
  Timer? _debounceTimer;

  MatchingProvider({required this.firestoreService, this.notificationService}) {
    _notificationStrategy = NotificationStrategy(
      firestoreService: firestoreService,
      notificationService: notificationService,
    );
    _notificationStrategy.startDailySummaryTimer();
  }

  List<MatchResult> get matches =>
      _matches.where((m) => !_dismissedMatches.contains('${m.lostItem.id}_${m.foundItem.id}')).toList();
  List<ItemModel> get foundItems => List.unmodifiable(_foundItems);
  bool get isMatching => _isMatching;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void startListening() {
    _lostSub?.cancel();
    _foundSub?.cancel();

    try {
      _lostSub = firestoreService
          .collection('items')
          .where('type', isEqualTo: 'lost')
          .snapshots()
          .listen(
        (snapshot) {
          final seen = <String>{};
          _lostItems = snapshot.docs
              .map((doc) => ItemModel.fromMap({
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  }))
              .where((item) =>
                  (item.status == 'lost' || item.status == 'matched') &&
                  seen.add(item.id))
              .toList();
          _debounceRunMatching();
        },
        onError: (error) {
          debugPrint('Lost items stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe lost items: $e');
    }

    try {
      _foundSub = firestoreService
          .collection('items')
          .where('type', isEqualTo: 'found')
          .snapshots()
          .listen(
        (snapshot) {
          final seen = <String>{};
          _foundItems = snapshot.docs
              .map((doc) => ItemModel.fromMap({
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  }))
              .where((item) =>
                  item.status == 'found' && seen.add(item.id))
              .toList();
          _debounceRunMatching();
        },
        onError: (error) {
          debugPrint('Found items stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe found items: $e');
    }
  }

  void _debounceRunMatching() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _runMatching();
    });
  }

  void stopListening() {
    _debounceTimer?.cancel();
    _lostSub?.cancel();
    _foundSub?.cancel();
    _lostSub = null;
    _foundSub = null;
  }

  void _runMatching() {
    if (_lostItems.isEmpty || _foundItems.isEmpty) {
      _matches = [];
      _isMatching = false;
      notifyListeners();
      return;
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final freshLost = _lostItems.where((i) {
      final date = i.createdAt ?? i.itemDate;
      return date == null || date.isAfter(cutoff);
    }).toList();
    final freshFound = _foundItems.where((i) {
      final date = i.createdAt ?? i.itemDate;
      return date == null || date.isAfter(cutoff);
    }).toList();

    _isMatching = true;
    notifyListeners();

    _matches = _matchingService.findMatches(
      lostItems: freshLost,
      foundItems: freshFound,
      maxResults: 50,
    );

    // Use the new notification strategy
    _notificationStrategy.processMatches(_matches);

    _isMatching = false;
    notifyListeners();
  }

  List<MatchResult> getMatchesForItem(String itemId) {
    ItemModel? item;
    try {
      item = [..._lostItems, ..._foundItems].firstWhere((i) => i.id == itemId);
    } catch (e) {
      debugPrint('Item not found for matching: $itemId');
      return [];
    }

    if (item.id.isEmpty) return [];

    final oppositeItems = item.type == 'lost' ? _foundItems : _lostItems;

    return _matchingService.findMatchesForItem(
      item: item,
      oppositeItems: oppositeItems,
      maxResults: 10,
    );
  }

  void runManualMatch() {
    _debounceTimer?.cancel();
    _isMatching = true;
    notifyListeners();
    _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    try {
      final lostSnapshot = await firestoreService
          .collection('items')
          .where('type', isEqualTo: 'lost')
          .get(const GetOptions(source: Source.server));

      final foundSnapshot = await firestoreService
          .collection('items')
          .where('type', isEqualTo: 'found')
          .get(const GetOptions(source: Source.server));

      final lostSeen = <String>{};
      _lostItems = lostSnapshot.docs
          .map((doc) => ItemModel.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .where((item) =>
              (item.status == 'lost' || item.status == 'matched') &&
              lostSeen.add(item.id))
          .toList();

      final foundSeen = <String>{};
      _foundItems = foundSnapshot.docs
          .map((doc) => ItemModel.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .where((item) =>
              item.status == 'found' && foundSeen.add(item.id))
          .toList();

      _runMatching();
    } catch (e) {
      debugPrint('Refresh from server error: $e');
      _isMatching = false;
      _errorMessage = 'Failed to refresh. Pull down to try again.';
      notifyListeners();
    }
  }

  void dismissMatch(String lostItemId, String foundItemId) {
    final key = '${lostItemId}_$foundItemId';
    _dismissedMatches.add(key);
    notifyListeners();
  }

  void restoreAllMatches() {
    _dismissedMatches.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _notificationStrategy.dispose();
    super.dispose();
  }
}
