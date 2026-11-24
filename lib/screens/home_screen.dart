import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/screens/map_screen.dart';
import 'package:parksmart/screens/session_screen.dart';
import 'package:parksmart/screens/history_screen.dart';
import 'package:parksmart/screens/profile_screen.dart';
import 'package:parksmart/screens/payment_screen.dart';

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class HomeScreen extends StatefulWidget {
  HomeScreen({Key? key}) : super(key: key ?? homeScreenKey);

  @override
  HomeScreenState createState() => HomeScreenState();
}

final vehicleUpdateNotifier = ValueNotifier<int>(0);

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingPayment());
  }

  Future<void> _checkPendingPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending_payment')
        .get();

    if (snapshot.docs.isEmpty || !mounted) return;

    // Auto-heal sessions that were already paid but status wasn't updated
    for (final doc in snapshot.docs) {
      if (doc.data()['paymentStatus'] == 'paid') {
        doc.reference.update({'status': 'completed'});
      }
    }

    final unpaid = snapshot.docs
        .where((d) => d.data()['paymentStatus'] != 'paid')
        .toList();

    if (unpaid.isEmpty || !mounted) return;

    final doc = unpaid.first;
    final data = doc.data();
    final startTime = (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endTime = (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          sessionId: doc.id,
          lotName: data['lotName'] as String? ?? '',
          address: data['address'] as String? ?? '',
          duration: (data['duration'] as num?)?.toInt() ?? 0,
          totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
          rate: data['rate'] as String? ?? '',
          type: data['type'] as String? ?? 'parking',
          startTime: startTime,
          endTime: endTime,
        ),
      ),
    );
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    MapScreen(),
    SessionScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        indicatorColor: AppColors.primarySurface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon:
                Icon(Icons.map_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon:
                Icon(Icons.timer_rounded, color: AppColors.primary),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded,
                color: AppColors.primary),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}