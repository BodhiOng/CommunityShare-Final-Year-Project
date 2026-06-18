import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'user_role.dart';

class UserRoleResolver {
  UserRoleResolver._();

  static const List<String> _roleFields = [
    'role',
    'userRole',
    'user_role',
    'userType',
    'user_type',
    'accountType',
    'account_type',
  ];

  static Future<UserRole> resolve(User user) async {
    final firestore = FirebaseFirestore.instance;

    final donorRole = await _resolveByLinkTable(
      firestore: firestore,
      collection: 'DONOR',
      uidField: 'userId',
      role: UserRole.donor,
      uid: user.uid,
    );
    if (donorRole != null) {
      return donorRole;
    }

    final recipientRole = await _resolveByLinkTable(
      firestore: firestore,
      collection: 'RECIPIENT',
      uidField: 'userId',
      role: UserRole.recipient,
      uid: user.uid,
    );
    if (recipientRole != null) {
      return recipientRole;
    }

    final hubRole = await _resolveByLinkTable(
      firestore: firestore,
      collection: 'COMMUNITY_HUB',
      uidField: 'userId',
      role: UserRole.hub,
      uid: user.uid,
    );
    if (hubRole != null) {
      return hubRole;
    }

    final adminRole = await _resolveByLinkTable(
      firestore: firestore,
      collection: 'ADMIN',
      uidField: 'userId',
      role: UserRole.admin,
      uid: user.uid,
    );
    if (adminRole != null) {
      return adminRole;
    }

    final role = await _readRoleByDocumentId(
      firestore: firestore,
      collection: 'USER',
      uid: user.uid,
    );
    if (role != null) {
      return role;
    }

    final fallback = await _readRoleByDocumentId(
      firestore: firestore,
      collection: 'users',
      uid: user.uid,
    );
    if (fallback != null) {
      return fallback;
    }

    debugPrint('Unable to resolve role for uid=${user.uid}, defaulting to recipient.');
    return UserRole.recipient;
  }

  static Future<UserRole?> _resolveByLinkTable({
    required FirebaseFirestore firestore,
    required String collection,
    required String uidField,
    required UserRole role,
    required String uid,
  }) async {
    try {
      final snapshot = await firestore
          .collection(collection)
          .where(uidField, isEqualTo: uid)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }

      debugPrint('Resolved role=${role.key} from $collection using $uidField for $uid.');
      return role;
    } catch (error) {
      debugPrint('Role lookup failed for $collection where $uidField=$uid: $error');
      return null;
    }
  }

  static Future<UserRole?> _readRoleByDocumentId({
    required FirebaseFirestore firestore,
    required String collection,
    required String uid,
  }) async {
    try {
      final snapshot = await firestore.collection(collection).doc(uid).get();
      return _extractRole(snapshot.data(), collection: collection, match: uid);
    } catch (error) {
      debugPrint('Role lookup failed for $collection/$uid: $error');
      return null;
    }
  }

  static UserRole? _extractRole(
    Map<String, dynamic>? data, {
    required String collection,
    required String match,
  }) {
    if (data == null) {
      return null;
    }

    for (final field in _roleFields) {
      final rawValue = data[field]?.toString();
      if (rawValue == null || rawValue.trim().isEmpty) {
        continue;
      }

      final role = UserRoleX.fromStorage(rawValue);
      debugPrint(
        'Resolved role=$rawValue from $collection using $field for $match.',
      );
      return role;
    }

    return null;
  }
}
