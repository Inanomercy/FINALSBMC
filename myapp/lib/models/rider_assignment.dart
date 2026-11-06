class RiderAssignment {
  final String id;
  final String orderId;
  final String riderId;
  final String status;
  final String? rejectionReason;
  final DateTime assignedAt;
  final DateTime? respondedAt;

  const RiderAssignment({
    required this.id,
    required this.orderId,
    required this.riderId,
    required this.status,
    this.rejectionReason,
    required this.assignedAt,
    this.respondedAt,
  });

  factory RiderAssignment.fromJson(Map<String, dynamic> json) {
    return RiderAssignment(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      riderId: json['rider_id'] as String,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String? ?? DateTime.now().toIso8601String()),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at'] as String) : null,
    );
  }
}

class OrderStatusHistory {
  final String id;
  final String orderId;
  final String status;
  final String? changedBy;
  final String? notes;
  final DateTime createdAt;

  const OrderStatusHistory({
    required this.id,
    required this.orderId,
    required this.status,
    this.changedBy,
    this.notes,
    required this.createdAt,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      status: json['status'] as String? ?? '',
      changedBy: json['changed_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
