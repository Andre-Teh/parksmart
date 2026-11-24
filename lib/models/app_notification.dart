import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'info',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  IconData get icon {
    switch (type) {
      case 'session_start':
        return Icons.directions_car_rounded;
      case 'session_reminder':
        return Icons.timer_rounded;
      case 'payment':
        return Icons.check_circle_rounded;
      case 'ev_start':
        return Icons.electric_car_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'session_start':
      case 'ev_start':
        return const Color(0xFF1E7A4F);
      case 'session_reminder':
        return const Color(0xFFF59E0B);
      case 'payment':
        return const Color(0xFF1E7A4F);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
