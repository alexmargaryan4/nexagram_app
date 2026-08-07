import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';

/// Handles the `users/{uid}/contacts` sub-collection: adding, removing,
/// and listing saved contacts.
///
/// Contacts are one-directional by design (like a phone address book,
/// not a mutual "friendship") — you can message anyone via search, but
/// contacts are the people you've explicitly saved for quick access.
class ContactService {
  ContactService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _contacts(String ownerUid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(ownerUid)
          .collection(FirestoreCollections.contacts);

  /// Live, alphabetically-sorted contact list for [ownerUid].
  Stream<List<ContactModel>> watchContacts(String ownerUid) {
    return _contacts(ownerUid)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(ContactModel.fromDoc).toList());
  }

  Future<bool> isContact(String ownerUid, String contactUid) async {
    final doc = await _contacts(ownerUid).doc(contactUid).get();
    return doc.exists;
  }

  Future<void> addContact(String ownerUid, UserModel contact) async {
    if (ownerUid == contact.uid) {
      throw const ValidationException("You can't add yourself as a contact.");
    }
    try {
      await _contacts(ownerUid).doc(contact.uid).set(
            ContactModel(
              contactUid: contact.uid,
              username: contact.username,
              name: contact.name,
              avatarUrl: contact.avatarUrl,
            ).toMap(),
          );
    } catch (e) {
      throw const FirestoreException('Could not add contact.');
    }
  }

  Future<void> removeContact(String ownerUid, String contactUid) async {
    try {
      await _contacts(ownerUid).doc(contactUid).delete();
    } catch (e) {
      throw const FirestoreException('Could not remove contact.');
    }
  }

  /// Keeps denormalized contact display fields (name/avatar) fresh when the
  /// underlying user updates their profile. Call this opportunistically —
  /// e.g. from a Cloud Function trigger in production — since the client
  /// can only patch contacts it directly owns.
  Future<void> refreshContactSnapshot(String ownerUid, UserModel user) async {
    final doc = _contacts(ownerUid).doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) return;
    await doc.update({
      'username': user.username,
      'name': user.name,
      'avatarUrl': user.avatarUrl,
    });
  }
}
