import 'package:billing/features/providers/role_provider.dart';
import 'package:billing/features/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:billing/features/services/firebase_options.dart';
import 'package:billing/features/screens/billing_screen.dart';
import 'package:billing/features/screens/pending_payment.dart';
import 'package:billing/features/screens/prduct_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web Firebase initialization
    await Firebase.initializeApp(options: windowsFirebaseOptions);
  } else {
    // Mobile/Desktop Firebase initialization
    await Firebase.initializeApp();
  }

  runApp(const ProviderScope(child: BillingApp()));
}

class BillingApp extends ConsumerWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);

    // While SharedPreferences is still loading (role == null)
    if (role == null) {
      return MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.blue),
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      key: ValueKey(role),
      title: 'Billing System',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
      ),
      debugShowCheckedModeBanner: false,
      home: switch (role) {
        UserRole.none => const LoginScreen(),
        UserRole.user || UserRole.admin => const MainNavigationScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;
  final PageController _pageController = PageController(initialPage: 1);
  final NotchBottomBarController _barController = NotchBottomBarController(
    index: 1,
  );

  final List<Widget> _screens = const [
    AdminScreen(),
    BillingScreen(),
    BillExplorerScreen(),
  ];

  late final Connectivity _connectivity;
  late final Stream<List<ConnectivityResult>> _connectivityStream;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;

    _connectivityStream.listen((results) {
      final isNowOffline = results.every((r) => r == ConnectivityResult.none);
      if (isNowOffline != _isOffline) {
        setState(() {
          _isOffline = isNowOffline;
        });
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar:
            _isOffline
                ? AppBar(
                  backgroundColor: Colors.red,
                  title: const Text(
                    'No Internet Connection',
                    style: TextStyle(color: Colors.white),
                  ),
                  centerTitle: true,
                )
                : null,
        body:
            isDesktop
                ? Row(
                  children: [
                    NavigationRail(
                      indicatorColor: const Color.fromARGB(255, 2, 113, 192),
                      selectedIconTheme: const IconThemeData(
                        color: Colors.white,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        color: Colors.blueGrey,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: Colors.blueGrey,
                      ),
                      backgroundColor: Colors.white,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.admin_panel_settings),
                          label: Text('Admin'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long),
                          label: Text('Billing'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.details),
                          label: Text('Details'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        children: _screens,
                      ),
                    ),
                  ],
                )
                : PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: _screens,
                ),
        bottomNavigationBar:
            isDesktop
                ? null
                : AnimatedNotchBottomBar(
                  notchBottomBarController: _barController,
                  color: Colors.white,
                  notchColor: const Color.fromARGB(255, 2, 113, 192),
                  removeMargins: false,
                  bottomBarWidth: 500,
                  showLabel: true,
                  shadowElevation: 5,
                  durationInMilliSeconds: 300,
                  kIconSize: 20,
                  kBottomRadius: 20,
                  bottomBarItems: const [
                    BottomBarItem(
                      inActiveItem: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.blueGrey,
                      ),
                      activeItem: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                      ),
                      itemLabel: 'Admin',
                    ),
                    BottomBarItem(
                      inActiveItem: Icon(Icons.receipt, color: Colors.blueGrey),
                      activeItem: Icon(Icons.receipt, color: Colors.white),
                      itemLabel: 'Billing',
                    ),
                    BottomBarItem(
                      inActiveItem: Icon(Icons.details, color: Colors.blueGrey),
                      activeItem: Icon(Icons.details, color: Colors.white),
                      itemLabel: 'Details',
                    ),
                  ],
                  onTap: _onItemTapped,
                ),
      ),
    );
  }
}
