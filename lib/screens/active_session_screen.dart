import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/models/parking_lot.dart';
import 'package:parksmart/services/session_service.dart';
import 'package:parksmart/screens/home_screen.dart';
import 'package:parksmart/screens/payment_screen.dart';
import 'package:parksmart/core/notification_service.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ParkingLot parkingLot;

  const ActiveSessionScreen({super.key, required this.parkingLot});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  Timer? _timer;
  int _seconds = 0;
  double _estimatedCost = 0.0;
  DateTime? _startTime;
  String _sessionId = '';
  bool _isEnding = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _ratePerHour {
    final match = RegExp(r'[\d.]+').firstMatch(widget.parkingLot.rate);
    return match != null ? double.parse(match.group(0)!) : 2.0;
  }

  Future<void> _initSession() async {
    final existing = await SessionService.getActiveSession();

    if (existing != null) {
      _sessionId = existing.id;
      _startTime = existing.startTime;
      _seconds = DateTime.now().difference(_startTime!).inSeconds;
      _estimatedCost = (_seconds / 3600) * _ratePerHour;
    } else {
      final session = await SessionService.startSession(widget.parkingLot);
      _sessionId = session.id;
      _startTime = session.startTime;
      NotificationService().showSessionStarted(
        lotName: widget.parkingLot.name,
        isEv: widget.parkingLot.isEv,
      );
    }

    // Show live lock screen notification immediately
    if (_startTime != null) {
      NotificationService().showLiveSession(
        lotName: widget.parkingLot.name,
        isEv: widget.parkingLot.isEv,
        startTime: _startTime!,
        cost: _estimatedCost,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _startTime != null) {
        setState(() {
          _seconds = DateTime.now().difference(_startTime!).inSeconds;
          _estimatedCost = (_seconds / 3600) * _ratePerHour;
        });

        // Update live notification cost every 60 seconds
        if (_seconds > 0 && _seconds % 60 == 0) {
          NotificationService().showLiveSession(
            lotName: widget.parkingLot.name,
            isEv: widget.parkingLot.isEv,
            startTime: _startTime!,
            cost: _estimatedCost,
          );
          NotificationService().showSessionReminder(
            seconds: _seconds,
            cost: _estimatedCost,
            lotName: widget.parkingLot.name,
          );
        }
      }
    });
  }

  String get _formattedTime {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _startTimeFormatted {
    if (_startTime == null) return '--:--';
    final h = _startTime!.hour.toString().padLeft(2, '0');
    final m = _startTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _endSession() async {
    _timer?.cancel();
    setState(() => _isEnding = true);

    final endTime = DateTime.now();
    final startTime = _startTime ?? endTime;
    final totalCost = double.parse(_estimatedCost.toStringAsFixed(2));

    try {
      await SessionService.endSession(
        sessionId: _sessionId,
        lotId: widget.parkingLot.id,
        duration: _seconds,
        totalCost: totalCost,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended but failed to sync. Please check your history.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    await NotificationService().cancelSessionNotification();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          sessionId: _sessionId,
          lotName: widget.parkingLot.name,
          address: widget.parkingLot.address,
          duration: _seconds,
          totalCost: totalCost,
          rate: widget.parkingLot.rate,
          type: widget.parkingLot.type,
          startTime: startTime,
          endTime: endTime,
        ),
      ),
    );
  }

  Future<bool> _showEndSessionDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'End Session?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your session will be ended and you will proceed to payment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: widget.parkingLot.isEv
                      ? AppColors.evSurface
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current cost',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${_estimatedCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      _formattedTime,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'End Session',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
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
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEv = widget.parkingLot.isEv;
    final accentColor = isEv ? AppColors.ev : AppColors.primary;
    final accentSurface = isEv ? AppColors.evSurface : AppColors.primarySurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Parking Session',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => HomeScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Location card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEv
                                ? Icons.electric_car_rounded
                                : Icons.local_parking_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.parkingLot.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                widget.parkingLot.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha:0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timer display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Elapsed time',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formattedTime,
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Started at $_startTimeFormatted',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info row
                  Row(
                    children: [
                      _buildInfoCard(
                        Icons.payments_outlined,
                        'Rate',
                        widget.parkingLot.rate,
                        AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoCard(
                        Icons.account_balance_wallet_outlined,
                        'Est. Cost',
                        'RM ${_estimatedCost.toStringAsFixed(2)}',
                        AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Session duration
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Session duration',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              '${(_seconds ~/ 3600)}h ${((_seconds % 3600) ~/ 60)}m ${_seconds % 60}s',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: null,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'No time limit — end session whenever you\'re ready',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reminder
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Remember to end your session before leaving to avoid extra charges.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // End session button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isEnding
                          ? null
                          : () async {
                              final confirm = await _showEndSessionDialog();
                              if (confirm) _endSession();
                            },
                      child: _isEnding
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'End Session',
                              style: TextStyle(
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

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
