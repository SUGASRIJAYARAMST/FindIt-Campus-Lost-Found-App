import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/item_model.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/reward_service.dart';
import '../services/timeline_service.dart';

class ItemProvider extends ChangeNotifier {
  final FirestoreService firestoreService;
  final CloudinaryService cloudinaryService;
  final RewardService rewardService;
  final TimelineService? timelineService;
  final NotificationService? notificationService;

  List<ItemModel> _items = [];
  List<ItemModel> _myItems = [];
  ItemModel? _selectedItem;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _itemsSub;

  ItemProvider({
    required this.firestoreService,
    required this.cloudinaryService,
    required this.rewardService,
    this.timelineService,
    this.notificationService,
  });

  List<ItemModel> get items => _items;
  List<ItemModel> get myItems => _myItems;
  ItemModel? get selectedItem => _selectedItem;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<ItemModel> get lostItems =>
      _items.where((i) => i.type == 'lost').toList();

  List<ItemModel> get foundItems =>
      _items.where((i) => i.type == 'found').toList();

  void startListening() {
    _itemsSub?.cancel();
    try {
      _itemsSub = firestoreService
          .collection('items')
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint('Items stream: ${snapshot.docs.length} docs');
          _items = snapshot.docs
              .map((doc) => ItemModel.fromMap({
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  }))
              .toList();
          _items.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Items stream error: $error');
          _errorMessage = 'Failed to load items.';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe items: $e');
    }

    fetchItems();
  }

  Future<void> fetchItems() async {
    try {
      final snapshot = await firestoreService.collection('items').get();
      final fetched = snapshot.docs
          .map((doc) => ItemModel.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
      fetched.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      if (fetched.isNotEmpty) {
        _items = fetched;
        _errorMessage = null;
        notifyListeners();
      } else if (_items.isEmpty) {
        debugPrint('fetchItems: 0 items found in Firestore');
      }
    } catch (e) {
      debugPrint('fetchItems error: $e');
      if (_items.isEmpty) {
        _errorMessage = 'Cannot load items: $e';
        notifyListeners();
      }
    }
  }

  void stopListening() {
    _itemsSub?.cancel();
    _itemsSub = null;
  }

  // Future<int> cleanupSeedItems() async {
  //   int deletedCount = 0;
  //   try {
  //     final snapshot = await firestoreService.collection('items').get();
  //     for (final doc in snapshot.docs) {
  //       final data = doc.data() as Map<String, dynamic>;
  //       final createdByUid = data['createdByUid'] as String? ?? '';
  //       if (createdByUid.startsWith('seed_user_')) {
  //         await firestoreService.deleteData('items', doc.id);
  //         deletedCount++;
  //         debugPrint('Deleted seed item: ${doc.id} (createdByUid: $createdByUid)');
  //       }
  //     }
  //     debugPrint('Seed items cleanup complete: $deletedCount items deleted');
  //     await fetchItems();
  //   } catch (e) {
  //     debugPrint('Error cleaning up seed items: $e');
  //   }
  //   return deletedCount;
  // }

  // Future<void> seedMatchTestData() async {
  //   try {
  //     final existing = await firestoreService.collection('items').get();
  //     final seedCount = existing.docs.where((doc) {
  //       final data = doc.data() as Map<String, dynamic>;
  //       return (data['createdByUid'] as String? ?? '').startsWith('seed_user_');
  //     }).length;
  //     if (seedCount >= 8) return;
  //
  //     final now = DateTime.now();
  //     final seedUid = 'seed_user_match_test';
  //     final seedItems = <Map<String, dynamic>>[
  //       {
  //         'title': 'Dell Laptop',
  //         'category': 'Electronics',
  //         'description': 'Black Dell Inspiron laptop lost near library. Has a sticker on the lid.',
  //         'location': 'Library',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543210',
  //         'type': 'lost',
  //         'status': 'lost',
  //         'createdBy': 'Seed User',
  //         'createdByUid': seedUid,
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
  //       },
  //       {
  //         'title': 'Black Dell Laptop',
  //         'category': 'Electronics',
  //         'description': 'Found a black Dell laptop near cafe area. Power adapter included.',
  //         'location': 'Near Cafe',
  //         'itemDate': Timestamp.fromDate(now),
  //         'imageUrl': '',
  //         'contactNumber': '9876543211',
  //         'type': 'found',
  //         'status': 'found',
  //         'createdBy': 'Seed Finder',
  //         'createdByUid': '${seedUid}_founder',
  //         'createdAt': Timestamp.fromDate(now),
  //       },
  //       {
  //         'title': 'Blue Backpack',
  //         'category': 'Bags',
  //         'description': 'Lost my blue Jansport backpack with books and laptop charger inside.',
  //         'location': 'CSE Block',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543212',
  //         'type': 'lost',
  //         'status': 'lost',
  //         'createdBy': 'Seed User',
  //         'createdByUid': seedUid,
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
  //       },
  //       {
  //         'title': 'Blue Jansport Bag',
  //         'category': 'Bags',
  //         'description': 'Found a blue Jansport backpack in CSE Block hallway. Contains notebooks.',
  //         'location': 'CSE Block',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543213',
  //         'type': 'found',
  //         'status': 'found',
  //         'createdBy': 'Seed Finder',
  //         'createdByUid': '${seedUid}_founder',
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
  //       },
  //       {
  //         'title': 'Student ID Card',
  //         'category': 'ID Cards',
  //         'description': 'Lost my college ID card with name Ravi. Blue lanyard attached.',
  //         'location': 'Main Gate',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543214',
  //         'type': 'lost',
  //         'status': 'lost',
  //         'createdBy': 'Seed User',
  //         'createdByUid': seedUid,
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
  //       },
  //       {
  //         'title': 'College ID Card Found',
  //         'category': 'ID Cards',
  //         'description': 'Found an ID card near main gate. Student name appears to be Ravi.',
  //         'location': 'Main Gate',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(days: 1, hours: 12))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543215',
  //         'type': 'found',
  //         'status': 'found',
  //         'createdBy': 'Seed Finder',
  //         'createdByUid': '${seedUid}_founder',
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1, hours: 12))),
  //       },
  //       {
  //         'title': 'Silver Watch',
  //         'category': 'Accessories',
  //         'description': 'Lost a silver Casio watch near the cafeteria. Has a metal band.',
  //         'location': 'Cafeteria',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543216',
  //         'type': 'lost',
  //         'status': 'lost',
  //         'createdBy': 'Seed User',
  //         'createdByUid': seedUid,
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
  //       },
  //       {
  //         'title': 'Silver Casio Watch',
  //         'category': 'Accessories',
  //         'description': 'Found a silver Casio wristwatch with metal band near the cafeteria.',
  //         'location': 'Cafeteria',
  //         'itemDate': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
  //         'imageUrl': '',
  //         'contactNumber': '9876543217',
  //         'type': 'found',
  //         'status': 'found',
  //         'createdBy': 'Seed Finder',
  //         'createdByUid': '${seedUid}_founder',
  //         'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
  //       },
  //     ];
  //
  //     for (final item in seedItems) {
  //       final docRef = firestoreService.collection('items').doc();
  //       item['id'] = docRef.id;
  //       await docRef.set(item);
  //     }
  //     debugPrint('Match test data seeded: ${seedItems.length} items');
  //     await fetchItems();
  //   } catch (e) {
  //     debugPrint('Error seeding match test data: $e');
  //   }
  // }

  Future<void> loadMyItems(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await firestoreService
          .collection('items')
          .where('createdByUid', isEqualTo: uid)
          .get();

      _myItems = snapshot.docs
          .map((doc) => ItemModel.fromMap({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();

      _myItems.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    } catch (e) {
      debugPrint('Error loading my items: $e');
      _errorMessage = 'Failed to load your reports.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ItemModel?> getItemById(String id) async {
    try {
      final doc = await firestoreService.document('items', id);
      if (doc.exists && doc.data() != null) {
        final item = ItemModel.fromMap({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
        _selectedItem = item;
        notifyListeners();
        return item;
      }

      final archivedDoc = await firestoreService.document('archived_items', id);
      if (archivedDoc.exists && archivedDoc.data() != null) {
        final item = ItemModel.fromMap({
          'id': archivedDoc.id,
          ...archivedDoc.data() as Map<String, dynamic>,
        });
        _selectedItem = item;
        notifyListeners();
        return item;
      }
    } catch (e) {
      debugPrint('Error getting item: $e');
      _errorMessage = 'Failed to load item details.';
      notifyListeners();
    }
    return null;
  }

  Future<String?> createItem({
    required String title,
    required String category,
    required String description,
    required String location,
    required DateTime? itemDate,
    required String contactNumber,
    required String type,
    required String createdBy,
    required String createdByUid,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    // Prevent duplicate uploads
    if (_isUploading) {
      _errorMessage = 'Upload already in progress...';
      notifyListeners();
      return null;
    }

    _isUploading = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String imageUrl = '';
      if (imageBytes != null && fileName != null) {
        imageUrl = await cloudinaryService.uploadImage(
          fileName: fileName,
          fileBytes: imageBytes,
        );
      }

      final docRef = firestoreService.collection('items').doc();
      final itemData = {
        'id': docRef.id,
        'title': title,
        'category': category,
        'description': description,
        'location': location,
        'itemDate': itemDate != null ? Timestamp.fromDate(itemDate) : null,
        'imageUrl': imageUrl,
        'contactNumber': contactNumber,
        'type': type,
        'status': type == 'lost' ? 'lost' : 'found',
        'createdBy': createdBy,
        'createdByUid': createdByUid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(itemData);

      await _notifyUser(
        createdByUid,
        type == 'lost' ? 'Lost Item Reported' : 'Found Item Reported',
        'Your ${type == 'lost' ? 'lost' : 'found'} item "$title" has been posted successfully.',
        'status_update',
      );

      try {
        await rewardService.awardPointsForReport(createdByUid, type);
      } catch (_) {}

      try {
        timelineService?.addEvent(
          itemId: docRef.id,
          eventType: 'created',
          description: '${type == 'lost' ? 'Lost' : 'Found'} item "$title" reported',
          performedBy: createdByUid,
          performedByName: createdBy,
        );
      } catch (_) {}

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating item: $e');
      _errorMessage = 'Failed to create report. Please try again.';
      notifyListeners();
      return null;
    } finally {
      _isUploading = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateItem({
    required String id,
    String? title,
    String? category,
    String? description,
    String? location,
    DateTime? itemDate,
    String? contactNumber,
    String? status,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      if (location != null) updates['location'] = location;
      if (itemDate != null) updates['itemDate'] = Timestamp.fromDate(itemDate);
      if (contactNumber != null) updates['contactNumber'] = contactNumber;
      if (status != null) updates['status'] = status;

      if (imageBytes != null && fileName != null) {
        final imageUrl = await cloudinaryService.uploadImage(
          fileName: fileName,
          fileBytes: imageBytes,
        );
        updates['imageUrl'] = imageUrl;
      }

      if (updates.isNotEmpty) {
        await firestoreService.setData('items', id, updates, merge: true);
      }

      await getItemById(id);
      return true;
    } catch (e) {
      debugPrint('Error updating item: $e');
      _errorMessage = 'Failed to update report.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteItem(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await firestoreService.deleteData('items', id);
      _items.removeWhere((item) => item.id == id);
      _myItems.removeWhere((item) => item.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting item: $e');
      _errorMessage = 'Failed to delete report.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> claimItem(String itemId, String claimedByUid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final itemDoc = await firestoreService.document('items', itemId);
      final itemData = itemDoc.data() as Map<String, dynamic>?;
      final ownerUid = itemData?['createdByUid'] as String? ?? '';
      final itemTitle = itemData?['title'] as String? ?? 'item';

      final updates = <String, dynamic>{
        'status': 'claimed',
        'claimedBy': claimedByUid,
        'claimedAt': FieldValue.serverTimestamp(),
      };

      await firestoreService.setData('items', itemId, updates, merge: true);
      await getItemById(itemId);

      if (ownerUid.isNotEmpty && ownerUid != claimedByUid) {
        await _notifyUser(ownerUid, 'Item Claimed!', 'Your item "$itemTitle" has been claimed.', 'claim');
      }

      try {
        await rewardService.awardPointsForClaim(claimedByUid);
        await _notifyUser(claimedByUid, 'Reward Earned!', 'You earned 5 points for claiming an item.', 'reward');
      } catch (_) {}

      try {
        timelineService?.addEvent(
          itemId: itemId,
          eventType: 'claimed',
          description: 'Item "$itemTitle" has been claimed',
          performedBy: claimedByUid,
          performedByName: claimedByUid,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error claiming item: $e');
      _errorMessage = 'Failed to claim item.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markAsReturned(String itemId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final itemDoc = await firestoreService.document('items', itemId);
      final itemData = itemDoc.data() as Map<String, dynamic>?;
      final ownerUid = itemData?['createdByUid'] as String? ?? '';
      final claimerUid = itemData?['claimedBy'] as String? ?? '';
      final itemTitle = itemData?['title'] as String? ?? 'item';

      await firestoreService.setData(
        'items',
        itemId,
        {'status': 'returned'},
        merge: true,
      );
      await getItemById(itemId);

      if (ownerUid.isNotEmpty) {
        await _notifyUser(ownerUid, 'Item Returned', 'Your item "$itemTitle" has been returned successfully.', 'status_update');
      }
      if (claimerUid.isNotEmpty && claimerUid != ownerUid) {
        await _notifyUser(claimerUid, 'Item Returned', 'The item "$itemTitle" has been marked as returned.', 'status_update');
      }

      try {
        await rewardService.awardPointsForReturn(ownerUid);
        await _notifyUser(ownerUid, 'Reward Earned!', 'You earned 10 points for returning an item.', 'reward');
      } catch (_) {}

      try {
        timelineService?.addEvent(
          itemId: itemId,
          eventType: 'returned',
          description: 'Item "$itemTitle" has been returned',
          performedBy: ownerUid,
          performedByName: ownerUid,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error marking as returned: $e');
      _errorMessage = 'Failed to update status.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyUser(String uid, String title, String body, String type) async {
    try {
      if (notificationService != null) {
        await notificationService!.sendNotificationToUser(
          targetUid: uid,
          title: title,
          body: body,
          data: {'type': type},
        );
      } else {
        await firestoreService.addData('notifications', {
          'uid': uid,
          'title': title,
          'body': body,
          'type': type,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error writing notification: $e');
    }
  }

  Future<bool> markAsRecovered(String itemId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await firestoreService.setData(
        'items',
        itemId,
        {'status': 'recovered'},
        merge: true,
      );
      await getItemById(itemId);

      try {
        timelineService?.addEvent(
          itemId: itemId,
          eventType: 'recovered',
          description: 'Item has been recovered',
          performedBy: '',
          performedByName: '',
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error marking as recovered: $e');
      _errorMessage = 'Failed to update status.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ItemModel> filterItems({
    String? type,
    String? category,
    String? location,
    String? status,
    String? searchQuery,
  }) {
    var filtered = List<ItemModel>.from(_items);

    if (type != null && type.isNotEmpty) {
      filtered = filtered.where((item) => item.type == type).toList();
    }

    if (category != null && category.isNotEmpty) {
      filtered = filtered.where((item) => item.category == category).toList();
    }

    if (location != null && location.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.location.toLowerCase().contains(location.toLowerCase()))
          .toList();
    }

    if (status != null && status.isNotEmpty) {
      filtered = filtered.where((item) => item.statusDisplay == status).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.location.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> migrateStatuses() async {
    try {
      final snapshot = await firestoreService.collection('items').get();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        String? newStatus;
        if (status == 'open') {
          newStatus = 'lost';
        } else if (status == 'available') {
          newStatus = 'found';
        }
        if (newStatus != null) {
          await firestoreService.setData('items', doc.id, {'status': newStatus}, merge: true);
          debugPrint('Migrated item ${doc.id}: $status → $newStatus');
        }
      }
      debugPrint('Status migration complete');
    } catch (e) {
      debugPrint('Error migrating statuses: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
