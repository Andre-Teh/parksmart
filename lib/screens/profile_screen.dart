import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/screens/login_screen.dart';
import 'package:parksmart/screens/edit_profile_screen.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parksmart/screens/payment_methods_screen.dart';
import 'package:parksmart/screens/vehicle_screen.dart';
import 'package:parksmart/screens/home_screen.dart';
import 'package:parksmart/screens/help_screen.dart';
import 'package:parksmart/screens/notification_screen.dart';
import 'package:parksmart/services/notification_store_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          StreamBuilder<int>(
            stream: NotificationStoreService.unreadCountStream(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 26),
                      if (count > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final base64Image = data?['profileImage'] as String?;

                if (base64Image != null && base64Image.isNotEmpty) {
                  try {
                    return CircleAvatar(
                      radius: 40,
                      backgroundImage: MemoryImage(base64Decode(base64Image)),
                    );
                  } catch (_) {}
                }
                return CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    ((user?.displayName ?? user?.email ?? 'User').isNotEmpty
                            ? (user?.displayName ?? user?.email ?? 'User')
                            : 'User')[0]
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              user?.displayName ?? 'User',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              user?.email ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),

            // Stats — real-time stream so numbers update without re-login
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('userId', isEqualTo: user?.uid)
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                final total = docs.length;
                final ev = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['type'] == 'ev')
                    .length;
                final spent = docs.fold<double>(0.0, (acc, d) {
                  final data = d.data() as Map<String, dynamic>;
                  return acc +
                      ((data['totalCost'] as num?)?.toDouble() ?? 0.0);
                });
                return Row(
                  children: [
                    _buildStatCard('$total', 'Sessions'),
                    const SizedBox(width: 10),
                    _buildStatCard('$ev', 'EV charges'),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      'RM ${spent.toStringAsFixed(2)}',
                      'Total spent',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Menu items
            _buildMenuItem(
              context,
              Icons.person_outline,
              'Edit profile',
              () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (updated == true && context.mounted) {
                  setState(() {});
                }
              },
            ),
            _buildMenuItem(
              context,
              Icons.credit_card_outlined,
              'Payment methods',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentMethodsScreen(),
                  ),
                );
              },
            ),
            _buildMenuItem(
              context,
              Icons.directions_car_rounded,
              'My Vehicle',
              () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehicleScreen()),
                );
                // Notify map to reload vehicle
                vehicleUpdateNotifier.value++;
                setState(() {});
              },
            ),
            _buildMenuItem(
              context,
              Icons.help_outline_rounded,
              'Help & Support',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            // Logout
            InkWell(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha:0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
