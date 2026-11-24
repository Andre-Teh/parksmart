import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parksmart/models/parking_lot.dart';
import 'package:parksmart/models/parking_session.dart';

class SessionService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<ParkingSession?> getActiveSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ParkingSession.fromFirestore(snapshot.docs.first);
  }

  static Future<ParkingSession> startSession(ParkingLot lot) async {
    final user = FirebaseAuth.instance.currentUser!;

    final doc = await _firestore.collection('sessions').add({
      'userId': user.uid,
      'lotId': lot.id,
      'lotName': lot.name,
      'address': lot.address,
      'rate': lot.rate,
      'type': lot.type,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    if (lot.id.isNotEmpty) {
      await _firestore
          .collection('parking_lots')
          .doc(lot.id)
          .update({'available': FieldValue.increment(-1)});
    }

    return ParkingSession(
      id: doc.id,
      lotId: lot.id,
      lotName: lot.name,
      address: lot.address,
      rate: lot.rate,
      type: lot.type,
      startTime: DateTime.now(),
      status: 'active',
    );
  }

  static Future<void> endSession({
    required String sessionId,
    required String lotId,
    required int duration,
    required double totalCost,
  }) async {
    if (sessionId.isNotEmpty) {
      await _firestore.collection('sessions').doc(sessionId).update({
        'endTime': FieldValue.serverTimestamp(),
        'duration': duration,
        'totalCost': totalCost,
        'status': 'pending_payment',
      });
    }

    if (lotId.isNotEmpty) {
      await _firestore
          .collection('parking_lots')
          .doc(lotId)
          .update({'available': FieldValue.increment(1)});
    }
  }

  static Future<void> saveReceipt({
    required String sessionId,
    required String paymentMethod,
  }) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'completed',
      'paymentMethod': paymentMethod,
      'paymentStatus': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });
  }
}
