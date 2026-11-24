import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingSession {
  final String id;
  final String lotId;
  final String lotName;
  final String address;
  final String rate;
  final String type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? duration;
  final double? totalCost;
  final String status;
  final String? paymentMethod;
  final String? paymentStatus;

  const ParkingSession({
    required this.id,
    required this.lotId,
    required this.lotName,
    required this.address,
    required this.rate,
    required this.type,
    required this.startTime,
    this.endTime,
    this.duration,
    this.totalCost,
    required this.status,
    this.paymentMethod,
    this.paymentStatus,
  });

  bool get isEv => type == 'ev';
  bool get isActive => status == 'active';
  bool get isPaid => paymentStatus == 'paid';

  factory ParkingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ParkingSession(
      id: doc.id,
      lotId: data['lotId'] as String? ?? '',
      lotName: data['lotName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      rate: data['rate'] as String? ?? '',
      type: data['type'] as String? ?? 'parking',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      duration: (data['duration'] as num?)?.toInt(),
      totalCost: (data['totalCost'] as num?)?.toDouble(),
      status: data['status'] as String? ?? 'active',
      paymentMethod: data['paymentMethod'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
    );
  }
}
