import 'package:flutter/material.dart';

import '../features/memories/presentation/memories_page.dart';
import '../features/memories/presentation/memory_form_page.dart';
import '../features/reminders/presentation/today_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../l10n/app_localizations.dart';

/// §5.1 — three tabs maximum; Settings is never required for the core loop.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [TodayPage(), MemoriesPage(), SettingsPage()],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const MemoryFormPage()),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.captureNewTitle),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n.navMemories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
