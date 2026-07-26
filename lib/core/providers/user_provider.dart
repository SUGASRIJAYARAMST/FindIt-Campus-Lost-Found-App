import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/user_model.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService firestoreService;
  final CloudinaryService cloudinaryService;

  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _userSub;

  UserProvider({
    required this.firestoreService,
    required this.cloudinaryService,
  });

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUserData() {
    _userSub?.cancel();
    _userSub = null;
    _userModel = null;
    _errorMessage = null;
    notifyListeners();
  }

  void startListening(String uid) {
    _userSub?.cancel();
    try {
      _userSub = firestoreService.collection('users').doc(uid).snapshots().listen(
        (doc) {
          if (doc.exists && doc.data() != null) {
            _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('User stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe user: $e');
    }
  }

  void stopListening() {
    _userSub?.cancel();
    _userSub = null;
  }

  Future<void> fetchUserData(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final doc = await firestoreService.document('users', uid);
      if (doc.exists && doc.data() != null) {
        _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      _errorMessage = 'Failed to load profile data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeProfileImage(String uid) async {
    try {
      await firestoreService.setData(
        'users',
        uid,
        {'profileImage': ''},
        merge: true,
      );
      await fetchUserData(uid);
    } catch (e) {
      debugPrint('Error removing profile image: $e');
      _errorMessage = 'Failed to remove profile picture.';
    }
  }

  Stream<DocumentSnapshot> userStream(String uid) {
    return firestoreService.collection('users').doc(uid).snapshots();
  }

  Future<bool> updateProfile({
    required String uid,
    String? name,
    String? department,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (department != null && department.isNotEmpty) updates['department'] = department;
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;

      if (updates.isNotEmpty) {
        await firestoreService.setData('users', uid, updates, merge: true);
      }

      await fetchUserData(uid);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      _errorMessage = 'Failed to update profile. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadProfileImage({
    required String uid,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!cloudinaryService.isConfigured) {
        _errorMessage = 'Image upload is not configured. Please set Cloudinary credentials.';
        return null;
      }

      final imageUrl = await cloudinaryService.uploadImage(
        fileName: fileName,
        fileBytes: fileBytes,
      );

      await firestoreService.setData(
        'users',
        uid,
        {'profileImage': imageUrl},
        merge: true,
      );

      await fetchUserData(uid);
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      _errorMessage = 'Failed to upload image. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
