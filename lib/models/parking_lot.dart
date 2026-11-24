import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingLot {
  final String id;
  final String name;
  final String address;
  final int available;
  final int total;
  final String rate;
  final String type;
  final LatLng position;

  const ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.available,
    required this.total,
    required this.rate,
    required this.type,
    required this.position,
  });

  bool get isEv => type == 'ev';
  bool get isFull => available == 0;
  bool get isFillingUp => available > 0 && total > 0 && available / total < 0.3;
  double get occupancyRatio => total > 0 ? (total - available) / total : 0;

  factory ParkingLot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ParkingLot(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      available: (data['available'] as int?) ?? 0,
      total: (data['total'] as int?) ?? 1,
      rate: data['rate'] as String? ?? '',
      type: data['type'] as String? ?? 'parking',
      position: LatLng(
        (data['lat'] as num?)?.toDouble() ?? 0.0,
        (data['lng'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  ParkingLot copyWith({int? available, int? total}) {
    return ParkingLot(
      id: id,
      name: name,
      address: address,
      available: available ?? this.available,
      total: total ?? this.total,
      rate: rate,
      type: type,
      position: position,
    );
  }
}
