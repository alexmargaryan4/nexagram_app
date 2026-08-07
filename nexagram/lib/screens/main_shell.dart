import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_provider.dart';
import '../widgets/navigation/custom_navigation_bar.dart';
import 'chats/chats_screen.dart';
import 'contacts/contacts_screen.dart';
import 'settings/settings_screen.dart';

/// Hosts the three primary tabs (Chats, Contacts, Settings) behind the
/// floating glass [CustomNavigationBar].
///
/// [ChatsProvider] is created here — scoped to the shell's lifetime, which
/// spans the whole signed-in session — rather than inside [ChatsScreen],
/// so the chat-list subscription survives switching tabs instead of
/// re-subscribing to Firestore every time the user taps back to Chats.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<NavBarItem> _items = [
    NavBarItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    NavBarItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Contacts',
    ),
    NavBarItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String? uid = context.watch<AuthProvider>().currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider<ChatsProvider>(
      create: (_) => ChatsProvider(currentUid: uid),
      child: Builder(
        builder: (context) {
          final int unread = context.select<ChatsProvider, int>(
            (p) => p.totalUnreadCount,
          );
          final List<NavBarItem> items = [
            NavBarItem(
              icon: _items[0].icon,
              activeIcon: _items[0].activeIcon,
              label: _items[0].label,
              badgeCount: unread,
            ),
            _items[1],
            _items[2],
          ];

          return Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: _index,
              children: const [
                ChatsScreen(),
                ContactsScreen(),
                SettingsScreen(),
              ],
            ),
            bottomNavigationBar: CustomNavigationBar(
              items: items,
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          );
        },
      ),
    );
  }
}
