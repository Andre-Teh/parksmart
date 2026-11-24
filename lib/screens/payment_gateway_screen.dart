import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parksmart/core/theme.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final String paymentMethod;
  final String imageName;
  final double amount;
  final Color color;

  const PaymentGatewayScreen({
    super.key,
    required this.paymentMethod,
    required this.imageName,
    required this.amount,
    required this.color,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  int _countdown = 5;
  Timer? _timer;
  bool _isProcessing = false;

  final Map<String, String> _extensionMap = {
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

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _completePayment();
      }
    });
  }

  void _completePayment() {
    setState(() => _isProcessing = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      // Return success to payment screen
      Navigator.pop(context, true);
    });
  }

  Widget _buildLogo() {
    final ext = _extensionMap[widget.imageName] ?? 'png';
    return Image.asset(
      'assets/payment/${widget.imageName}.$ext',
      height: 48,
      errorBuilder: (c, e, s) => Icon(
        Icons.account_balance_rounded,
        color: widget.color,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Secure Payment',
            style: TextStyle(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Secure badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Secured by SSL encryption',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Bank/wallet logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.color.withValues(alpha:0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLogo(),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              widget.paymentMethod,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing your payment',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 40),

            // Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Amount to pay',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Progress indicator
            if (!_isProcessing) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: (5 - _countdown) / 5,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(widget.color),
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Redirecting to ${widget.paymentMethod}...',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Completing payment...',
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ],

            const Spacer(),

            // Cancel button
            if (!_isProcessing)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel payment',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),

            const SizedBox(height: 8),
            Text(
              'This is a simulated payment gateway for demonstration purposes.',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}