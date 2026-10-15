import 'package:flutter/material.dart';

import 'notify.dart';
import 'screens/add_sheet.dart';
import 'screens/budget_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.load();
  await Notify.instance.init();
  await Store.instance.applyRecurring();
  await Notify.instance.refresh();
  runApp(const MaliApp());
}

class MaliApp extends StatelessWidget {
  const MaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00875A);
    return MaterialApp(
      title: 'Mali',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Catch debit orders and refresh alerts whenever the app is reopened.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Store.instance.applyRecurring().then((_) => Notify.instance.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSetUp: () => setState(() => _index = 2)),
      const InsightsScreen(),
      const BudgetScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.donut_large_outlined),
              selectedIcon: Icon(Icons.donut_large),
              label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Budget'),
        ],
      ),
    );
  }
}
