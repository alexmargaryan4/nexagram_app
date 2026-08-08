import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';

/// Handles the `public.contacts` table (`owner_uid` + `contact_uid`
/// composite key): adding, removing, and listing saved contacts.
///
/// Contacts are one-directional by design (like a phone address book,
/// not a mutual "friendship") — you can message anyone via search, but
/// contacts are the people you've explicitly saved for quick access.
class ContactService {
  ContactService({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  sb.SupabaseQueryBuilder get _contacts => _client.from(SupabaseTables.contacts);

  /// Live, alphabetically-sorted contact list for [ownerUid].
  Stream<List<ContactModel>> watchContacts(String ownerUid) {
    return _client
        .from(SupabaseTables.contacts)
        .stream(primaryKey: ['owner_uid', 'contact_uid'])
        .eq('owner_uid', ownerUid)
        .map((rows) {
          final List<ContactModel> contacts =
              rows.map(ContactModel.fromMap).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          return contacts;
        });
  }

  Future<bool> isContact(String ownerUid, String contactUid) async {
    final Map<String, dynamic>? row = await _contacts
        .select('contact_uid')
        .eq('owner_uid', ownerUid)
        .eq('contact_uid', contactUid)
        .maybeSingle();
    return row != null;
  }

  Future<void> addContact(String ownerUid, UserModel contact) async {
    if (ownerUid == contact.uid) {
      throw const ValidationException("You can't add yourself as a contact.");
    }
    try {
      await _contacts.upsert({
        'owner_uid': ownerUid,
        ...ContactModel(
          contactUid: contact.uid,
          username: contact.username,
          name: contact.name,
          avatarUrl: contact.avatarUrl,
        ).toMap(),
      }, onConflict: 'owner_uid,contact_uid');
    } on sb.PostgrestException catch (_) {
      throw const DatabaseException('Could not add contact.');
    }
  }

  Future<void> removeContact(String ownerUid, String contactUid) async {
    try {
      await _contacts
          .delete()
          .eq('owner_uid', ownerUid)
          .eq('contact_uid', contactUid);
    } on sb.PostgrestException catch (_) {
      throw const DatabaseException('Could not remove contact.');
    }
  }

  /// Keeps denormalized contact display fields (name/avatar) fresh when the
  /// underlying user updates their profile. Call this opportunistically —
  /// e.g. from a Postgres trigger in production — since the client can
  /// only patch contacts it directly owns.
  Future<void> refreshContactSnapshot(String ownerUid, UserModel user) async {
    final Map<String, dynamic>? existing = await _contacts
        .select('contact_uid')
        .eq('owner_uid', ownerUid)
        .eq('contact_uid', user.uid)
        .maybeSingle();
    if (existing == null) return;
    await _contacts.update({
      'username': user.username,
      'name': user.name,
      'avatar_url': user.avatarUrl,
    }).eq('owner_uid', ownerUid).eq('contact_uid', user.uid);
  }
}
