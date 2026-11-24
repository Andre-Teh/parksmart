import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/screens/receipt_screen.dart';
import 'package:parksmart/screens/add_card_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parksmart/screens/payment_gateway_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String sessionId;
  final String lotName;
  final String address;
  final int duration;
  final double totalCost;
  final String rate;
  final String type;
  final DateTime startTime;
  final DateTime endTime;

  const PaymentScreen({
    super.key,
    required this.sessionId,
    required this.lotName,
    required this.address,
    required this.duration,
    required this.totalCost,
    required this.rate,
    required this.type,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _expandedIndex = -1;
  String _selectedOptionId = '';
  String _selectedOptionLabel = '';
  bool _isProcessing = false;
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _addedCards = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    final defaultCardId = userDoc.data()?['defaultCardId'] as String? ?? '';

    final cards = snapshot.docs.map((doc) {
      final data = doc.data();
      final cardId = data['id'] as String? ?? doc.id;
      return {
        'id': cardId,
        'label': data['label'] as String? ?? '',
        'image': data['image'] as String? ?? '',
        'isDefault': data['id'] == defaultCardId,
      };
    }).toList();

    setState(() {
      _addedCards = cards;

      // Auto select default card
      if (defaultCardId.isNotEmpty) {
        final defaultCard = cards.firstWhere(
          (c) => c['id'] == defaultCardId,
          orElse: () => {},
        );
        if (defaultCard.isNotEmpty) {
          _selectedOptionId = defaultCard['id'] as String;
          _selectedOptionLabel = defaultCard['label'] as String;
        }
      }
    });
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payment_methods')
          .orderBy('order')
          .get();
      if (mounted) {
        setState(() {
          _paymentMethods = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'type': data['type'] ?? '',
              'title': data['title'] ?? '',
              'options': (data['options'] as List<dynamic>? ?? [])
                  .map((o) => Map<String, dynamic>.from(o as Map))
                  .toList(),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'fpx':
        return AppColors.ev;
      case 'ewallet':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'fpx':
        return Icons.account_balance_rounded;
      case 'ewallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  Widget _buildPaymentImage(String imageName, Color color) {
    if (imageName == 'add_card') {
      return Icon(Icons.add_card_rounded, color: color, size: 28);
    }

    // Map each image name to its actual extension
    const extensionMap = {
      'affinbank': 'png',
      'agrobank': 'webp',
      'alliance': 'webp',
      'ambank': 'png',
      'bankislam': 'jpg',
      'bankrakyat': 'webp',
      'boost': 'png',
      'cimb': 'png',
      'grabpay': 'png',
      'hongleong': 'png',
      'hsbc': 'png',
      'kuwait': 'png',
      'mastercard': 'jpg',
      'maybank': 'jpg',
      'muamalat': 'webp',
      'mybsn': 'png',
      'ocbc': 'png',
      'publicbank': 'png',
      'rhb': 'png',
      'shopeepay': 'webp',
      'standardchartered': 'png',
      'tng': 'png',
      'uob': 'png',
      'visa': 'png',
    };

    final ext = extensionMap[imageName] ?? 'png';

    return Image.asset(
      'assets/payment/$imageName.$ext',
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          Icon(_getIcon('card'), color: color, size: 24),
    );
  }

  String get _formattedDuration {
    final h = widget.duration ~/ 3600;
    final m = (widget.duration % 3600) ~/ 60;
    final s = widget.duration % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get _formattedTime {
    String format(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${format(widget.startTime)} – ${format(widget.endTime)}';
  }

  Future<void> _processPayment() async {
    if (_selectedOptionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment option first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // For FPX and eWallet — show gateway screen
    final selectedMethod = _paymentMethods.firstWhere(
      (m) => _expandedIndex == _paymentMethods.indexOf(m),
      orElse: () => {'type': 'card'},
    );
    final type = selectedMethod['type'] as String? ?? 'card';

    if (type == 'fpx' || type == 'ewallet') {
      // Find the image for selected option
      String imageName = '';
      for (final method in _paymentMethods) {
        final options = method['options'] as List<Map<String, dynamic>>;
        for (final option in options) {
          if (option['id'] == _selectedOptionId) {
            imageName = option['image'] as String? ?? '';
            break;
          }
        }
      }

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentGatewayScreen(
            paymentMethod: _selectedOptionLabel,
            imageName: imageName,
            amount: widget.totalCost,
            color: type == 'fpx' ? AppColors.ev : AppColors.warning,
          ),
        ),
      );

      if (result != true) return; // User cancelled
    } else {
      // For card — just simulate processing
      setState(() => _isProcessing = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          sessionId: widget.sessionId,
          lotName: widget.lotName,
          address: widget.address,
          duration: widget.duration,
          totalCost: widget.totalCost,
          rate: widget.rate,
          type: widget.type,
          startTime: widget.startTime,
          endTime: widget.endTime,
          paymentMethod: _selectedOptionLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
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
                  // Session summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.type == 'ev'
                                    ? AppColors.evSurface
                                    : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.type == 'ev'
                                    ? Icons.electric_car_rounded
                                    : Icons.local_parking_rounded,
                                color: widget.type == 'ev'
                                    ? AppColors.ev
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.lotName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    widget.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey[200]),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Time', _formattedTime),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Duration', _formattedDuration),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Rate', widget.rate),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Session type',
                          widget.type == 'ev' ? 'EV Charging' : 'Parking',
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[200]),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total amount',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'RM ${widget.totalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment methods from Firestore
                  const Text(
                    'Payment method',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  ...List.generate(_paymentMethods.length, (index) {
                    final method = _paymentMethods[index];
                    final type = method['type'] as String;
                    final color = _getColor(type);
                    final icon = _getIcon(type);
                    final isExpanded = _expandedIndex == index;
                    final options =
                        method['options'] as List<Map<String, dynamic>>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? color.withValues(alpha:0.04)
                              : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isExpanded
                                ? color
                                : Colors.grey.withValues(alpha:0.2),
                            width: isExpanded ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                () => _expandedIndex = isExpanded ? -1 : index,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            method['title'] as String,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey[400],
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expanded options
                            if (isExpanded) ...[
                              Divider(
                                height: 1,
                                color: Colors.grey.withValues(alpha:0.15),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    // Add new card button for card type
                                    if (type == 'card') ...[
                                      GestureDetector(
                                        onTap: () async {
                                          final result =
                                              await showModalBottomSheet<
                                                Map<String, dynamic>
                                              >(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor:
                                                    Colors.transparent,
                                                builder: (_) =>
                                                    const AddCardSheet(),
                                              );
                                          if (result != null) {
                                            setState(() {
                                              _addedCards.add(result);
                                              _selectedOptionId =
                                                  result['id'] as String;
                                              _selectedOptionLabel =
                                                  result['label'] as String;
                                            });
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _selectedOptionId == 'new_card'
                                                ? AppColors.primarySurface
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedOptionId ==
                                                      'new_card'
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Add New Card',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Show newly added cards
                                      ..._addedCards.map((card) {
                                        final isSelected =
                                            _selectedOptionId == card['id'];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: GestureDetector(
                                            onTap: () => setState(() {
                                              _selectedOptionId =
                                                  card['id'] as String;
                                              _selectedOptionLabel =
                                                  card['label'] as String;
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primary
                                                          .withValues(alpha:0.08)
                                                    : Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Colors.grey.withValues(alpha:
                                                          0.2,
                                                        ),
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    child: _buildPaymentImage(
                                                      card['image'] as String,
                                                      AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          card['label']
                                                              as String,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: isSelected
                                                                ? AppColors
                                                                      .primary
                                                                : Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.color,
                                                          ),
                                                        ),
                                                        if (card['isDefault'] ==
                                                            true) ...[
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .primary,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'Default',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 150,
                                                    ),
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected
                                                          ? AppColors.primary
                                                          : Colors.transparent,
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? AppColors.primary
                                                            : Colors.grey[300]!,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                            size: 10,
                                                            color: Colors.white,
                                                          )
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],

                                    // Options from Firestore
                                    ...options
                                        .where(
                                          (option) =>
                                              option['id'] != 'new_card',
                                        )
                                        .map((option) {
                                          final optionId =
                                              option['id'] as String;
                                          final label =
                                              option['label'] as String;
                                          final image =
                                              option['image'] as String? ?? '';
                                          final isSelected =
                                              _selectedOptionId == optionId;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => setState(() {
                                                _selectedOptionId = optionId;
                                                _selectedOptionLabel = label;
                                              }),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? color.withValues(alpha:0.08)
                                                      : Colors.grey[50],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? color
                                                        : Colors.grey
                                                              .withValues(alpha:0.2),
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Local asset image
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child: _buildPaymentImage(
                                                        image,
                                                        color,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            label,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isSelected
                                                                  ? color
                                                                  : Theme.of(
                                                                          context,
                                                                        )
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.color,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 150,
                                                      ),
                                                      width: 18,
                                                      height: 18,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isSelected
                                                            ? color
                                                            : Colors
                                                                  .transparent,
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? color
                                                              : Colors
                                                                    .grey[300]!,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons
                                                                  .check_rounded,
                                                              size: 10,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Payments are simulated and secured',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isProcessing ? null : _processPayment,
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Pay RM ${widget.totalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
