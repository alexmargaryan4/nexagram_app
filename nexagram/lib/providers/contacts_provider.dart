import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';
import '../services/contact_service.dart';
import '../services/user_service.dart';

/// Live contact list plus a debounced user-search flow for the "add
/// contact" screen.
class ContactsProvider extends ChangeNotifier {
  ContactsProvider({
    required String currentUid,
    ContactService? contactService,
    UserService? userService,
  })  : _currentUid = currentUid,
        _contactService = contactService ?? ContactService(),
        _userService = userService ?? UserService() {
    _subscribe();
  }

  final String _currentUid;
  final ContactService _contactService;
  final UserService _userService;

  StreamSubscription<List<ContactModel>>? _sub;
  Timer? _searchDebounce;

  List<ContactModel> _contacts = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  List<ContactModel> get contacts => _contacts;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  void _subscribe() {
    _sub = _contactService.watchContacts(_currentUid).listen(
      (contacts) {
        _contacts = contacts;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = 'Could not load contacts.';
        notifyListeners();
      },
    );
  }

  bool isContact(String uid) => _contacts.any((c) => c.contactUid == uid);

  /// Debounced live search as the user types, so we don't hammer Firestore
  /// on every keystroke.
  void search(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _userService.searchUsers(
        query,
        excludeUid: _currentUid,
      );
      _searchResults = results;
      _isSearching = false;
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  Future<void> addContact(UserModel user) {
    return _contactService.addContact(_currentUid, user);
  }

  Future<void> removeContact(String contactUid) {
    return _contactService.removeContact(_currentUid, contactUid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
