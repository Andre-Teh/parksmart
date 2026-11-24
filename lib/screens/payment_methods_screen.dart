import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/screens/add_card_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _savedCards = [];
  bool _isLoading = true;
  String _defaultCardId = '';

  final Map<String, String> _extensionMap = {
    'visa': 'png',
    'mastercard': 'jpg',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_cards')
          .orderBy('createdAt')
          .get();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _savedCards = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'docId': doc.id,
              'id': data['id'] as String? ?? doc.id,
              'label': data['label'] as String? ?? '',
              'image': data['image'] as String? ?? '',
              'expiry': data['expiry'] as String? ?? '',
              'cardType': data['cardType'] as String? ?? '',
            };
          }).toList();
          _defaultCardId = userDoc.data()?['defaultCardId'] as String? ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultCard(String cardId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'defaultCardId': cardId});

    setState(() => _defaultCardId = cardId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default card updated!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _deleteCard(String docId, String cardId, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Remove Card?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove $label?',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Cancel',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Remove',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_cards')
        .doc(docId)
        .delete();

    // Clear default if deleted card was default
    if (_defaultCardId == cardId) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'defaultCardId': ''});
      setState(() => _defaultCardId = '');
    }

    setState(() {
      _savedCards.removeWhere((c) => c['docId'] == docId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card removed successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildCardImage(String imageName) {
    final ext = _extensionMap[imageName] ?? 'png';
    return Image.asset(
      'assets/payment/$imageName.$ext',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => const Icon(
        Icons.credit_card_rounded,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cards section
                  const Text('Saved Cards',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Tap on a card to set it as default',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),

                  if (_savedCards.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.credit_card_outlined,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text('No saved cards',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text('Add a card to use for payments',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400])),
                        ],
                      ),
                    )
                  else
                    ..._savedCards.map((card) {
                      final isDefault =
                          _defaultCardId == card['id'];
                      return GestureDetector(
                        onTap: () =>
                            _setDefaultCard(card['id'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDefault
                                ? AppColors.primarySurface
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDefault
                                  ? AppColors.primary
                                  : Colors.grey.withValues(alpha:0.2),
                              width: isDefault ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: _buildCardImage(
                                    card['image'] as String),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          card['label'] as String,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w500),
                                        ),
                                        if (isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      4),
                                            ),
                                            child: const Text(
                                              'Default',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'Expires ${card['expiry']}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              // Radio button
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDefault
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isDefault
                                        ? AppColors.primary
                                        : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: isDefault
                                    ? const Icon(Icons.check_rounded,
                                        size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              IconButton(
                                onPressed: () => _deleteCard(
                                  card['docId'] as String,
                                  card['id'] as String,
                                  card['label'] as String,
                                ),
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // Add new card button
                  GestureDetector(
                    onTap: () async {
                      final result =
                          await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AddCardSheet(),
                      );
                      if (result != null) {
                        _loadSavedCards();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha:0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add New Card',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Supported methods
                  const Text('Supported Payment Methods',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness ==
                              Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _buildSupportedMethod(
                            'Credit / Debit Card',
                            'Visa, Mastercard',
                            Icons.credit_card_rounded,
                            AppColors.primary),
                        const Divider(height: 20),
                        _buildSupportedMethod(
                            'FPX Online Banking',
                            'Maybank, CIMB, RHB & more',
                            Icons.account_balance_rounded,
                            AppColors.ev),
                        const Divider(height: 20),
                        _buildSupportedMethod(
                            'e-Wallet',
                            'TNG, GrabPay, Boost, ShopeePay',
                            Icons.account_balance_wallet_rounded,
                            AppColors.warning),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security note
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your payment information is encrypted and stored securely. We never store your full card details.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSupportedMethod(
      String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }
}