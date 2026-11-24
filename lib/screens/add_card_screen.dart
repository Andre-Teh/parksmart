import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parksmart/core/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCardSheet extends StatefulWidget {
  const AddCardSheet({super.key});

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String _cardType = '';
  bool _cardInvalid = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _detectCardType(String value) {
    final cleaned = value.replaceAll(' ', '');
    setState(() {
      if (cleaned.isEmpty) {
        _cardType = '';
        _cardInvalid = false;
      } else if (cleaned.startsWith('4')) {
        _cardType = 'visa';
        _cardInvalid = false;
      } else if (cleaned.startsWith('5') || cleaned.startsWith('2')) {
        _cardType = 'mastercard';
        _cardInvalid = false;
      } else {
        _cardType = '';
        _cardInvalid = true;
      }
    });
  }

  String _formatCardNumber(String value) {
    final cleaned = value.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleaned = _cardNumberController.text.replaceAll(' ', '');
    final last4 = cleaned.length >= 4 ? cleaned.substring(cleaned.length - 4) : cleaned;
    final cardLabel =
        '${_cardType == 'visa' ? 'Visa' : 'Mastercard'} •••• $last4';
    final cardId = 'card_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_cards')
          .doc(cardId)
          .set({
            'id': cardId,
            'label': cardLabel,
            'image': _cardType == 'visa' ? 'visa' : 'mastercard',
            'last4': last4,
            'expiry': _expiryController.text,
            'cardType': _cardType,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save card. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, {
      'id': cardId,
      'label': cardLabel,
      'image': _cardType == 'visa' ? 'visa' : 'mastercard',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Credit / Debit Card',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey[500],
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Security note
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your card details are protected and encrypted.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card details header with logos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Card Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/payment/visa.png',
                              height: 20,
                              errorBuilder: (c, e, s) =>
                                  const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 6),
                            Image.asset(
                              'assets/payment/mastercard.jpg',
                              height: 20,
                              errorBuilder: (c, e, s) =>
                                  const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Card number
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 19,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final formatted = _formatCardNumber(newValue.text);
                          return newValue.copyWith(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }),
                      ],
                      onChanged: _detectCardType,
                      decoration: InputDecoration(
                        hintText: 'Card Number',
                        counterText: '',
                        suffixIcon: _cardInvalid
                            ? const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 22,
                              )
                            : _cardType.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(10),
                                child: Image.asset(
                                  _cardType == 'visa'
                                      ? 'assets/payment/visa.png'
                                      : 'assets/payment/mastercard.jpg',
                                  width: 32,
                                  errorBuilder: (c, e, s) =>
                                      const SizedBox.shrink(),
                                ),
                              )
                            : const Icon(
                                Icons.credit_card_rounded,
                                color: Colors.grey,
                              ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (_cardInvalid) { return 'Only Visa and Mastercard are supported'; }
                        final cleaned = v.replaceAll(' ', '');
                        if (cleaned.length < 16) { return 'Enter 16 digit card number'; }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Expiry + CVV
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              TextInputFormatter.withFunction((
                                oldValue,
                                newValue,
                              ) {
                                var text = newValue.text;
                                if (text.length >= 2 && !text.contains('/')) {
                                  text =
                                      '${text.substring(0, 2)}/${text.substring(2)}';
                                }
                                return newValue.copyWith(
                                  text: text,
                                  selection: TextSelection.collapsed(
                                    offset: text.length,
                                  ),
                                );
                              }),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'MM/YY',
                              counterText: '',
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 5) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: InputDecoration(
                              hintText: 'CVV',
                              counterText: '',
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Security Code (CVV)',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Card illustration
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                children: [
                                                  // Card back illustration
                                                  Container(
                                                    width: double.infinity,
                                                    height: 130,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2C2C2C,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        // Magnetic stripe
                                                        Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                top: 18,
                                                              ),
                                                          height: 36,
                                                          color: Colors.black,
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        // Signature strip + CVV
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Container(
                                                                  height: 28,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .white,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Row(
                                                                    children: List.generate(
                                                                      8,
                                                                      (
                                                                        i,
                                                                      ) => Expanded(
                                                                        child: Container(
                                                                          margin:
                                                                              const EdgeInsets.all(
                                                                                2,
                                                                              ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                i % 2 ==
                                                                                    0
                                                                                ? Colors.grey[300]
                                                                                : Colors.grey[200],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              // CVV box highlighted
                                                              Container(
                                                                width: 44,
                                                                height: 28,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: AppColors
                                                                        .primary,
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                                child: const Center(
                                                                  child: Text(
                                                                    '123',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: AppColors
                                                                          .primary,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors
                                                              .primarySurface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            Text(
                                              'The CVV (Card Verification Value) is the 3-digit number on the back of your card, next to the signature strip.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                height: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 20),

                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.help_outline_rounded,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 3) return 'Invalid CVV';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name on card
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Name on Card',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Disclaimer
                    Text(
                      'Your card information is encrypted and stored securely. We do not store your CVV.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add Card',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
