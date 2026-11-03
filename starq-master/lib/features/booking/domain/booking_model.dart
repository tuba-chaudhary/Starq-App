import 'package:starq_app/features/addresses/domain/address.dart';
import 'package:starq_app/features/services/domain/service_item.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';

enum BookingStatus {
  draft,
  pendingPayment,
  paymentProcessing,
  paymentFailed,
  confirmed,
  assignmentPending,
  partnerAssigned,
  providerOnTheWay,
  arrived,
  serviceStarted,
  serviceInProgress,
  serviceCompleted,
  customerFeedbackPending,
  completed,
  cancelled,
  refundPending,
  refunded,
  unknown
}

class BookingPartner {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final int completedJobs;
  final String? avatarUrl;

  BookingPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.completedJobs,
    this.avatarUrl,
  });

  factory BookingPartner.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? json['user'] as Map : null;
    return BookingPartner(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ??
          userMap?['fullName'] as String? ??
          userMap?['full_name'] as String? ??
          json['full_name'] as String? ??
          'STARQ Partner',
      phone: json['phone'] as String? ?? userMap?['phone'] as String? ?? '',
      rating: (json['rating'] as num? ?? 4.8).toDouble(),
      completedJobs: json['completed_jobs'] as int? ??
          json['total_completed_jobs'] as int? ??
          json['totalCompletedJobs'] as int? ??
          120,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
    );
  }
}

class Booking {
  final String id;
  final String bookingNumber;
  final String customerId;
  final BookingStatus status;
  final Vehicle? vehicle;
  final ServiceItem? service;
  final Address? address;
  final DateTime scheduledDate;
  final String scheduledTimeSlot;
  final double finalTotalAmount;
  final int pointsAwarded;
  final BookingPartner? partner;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.bookingNumber,
    required this.customerId,
    required this.status,
    this.vehicle,
    this.service,
    this.address,
    required this.scheduledDate,
    required this.scheduledTimeSlot,
    required this.finalTotalAmount,
    this.pointsAwarded = 0,
    this.partner,
    required this.createdAt,
  });

  bool get isActive =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.assignmentPending ||
      status == BookingStatus.partnerAssigned ||
      status == BookingStatus.providerOnTheWay ||
      status == BookingStatus.arrived ||
      status == BookingStatus.serviceStarted ||
      status == BookingStatus.serviceInProgress ||
      status == BookingStatus.customerFeedbackPending;

  bool get canTrack =>
      status == BookingStatus.partnerAssigned ||
      status == BookingStatus.providerOnTheWay ||
      status == BookingStatus.arrived;

  bool get isCompleted =>
      status == BookingStatus.serviceCompleted ||
      status == BookingStatus.completed;

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pendingPayment:
        return 'Payment Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.partnerAssigned:
        return 'Partner Assigned';
      case BookingStatus.providerOnTheWay:
        return 'Partner On The Way';
      case BookingStatus.arrived:
        return 'Partner Arrived';
      case BookingStatus.serviceStarted:
        return 'Wash Started';
      case BookingStatus.serviceInProgress:
        return 'Wash In Progress';
      case BookingStatus.serviceCompleted:
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Processing';
    }
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';

    // Support backend fallback for bookingNumber when not explicitly set
    final rawBookingNum = json['booking_number'] as String? ?? json['bookingNumber'] as String?;
    final bookingNumber = (rawBookingNum != null && rawBookingNum.trim().isNotEmpty)
        ? rawBookingNum.trim()
        : (id.length >= 8 ? '#${id.substring(0, 8).toUpperCase()}' : (id.isNotEmpty ? '#${id.toUpperCase()}' : 'Booking'));

    final customerId = json['customer_id'] as String? ??
        json['customerId'] as String? ??
        json['userId'] as String? ??
        '';

    // Parse service from json['service'] or from json['items'] list
    ServiceItem? parsedService;
    if (json['service'] != null && json['service'] is Map) {
      parsedService = ServiceItem.fromJson(Map<String, dynamic>.from(json['service'] as Map));
    } else if (json['items'] is List && (json['items'] as List).isNotEmpty) {
      final firstItem = (json['items'] as List).first;
      if (firstItem is Map) {
        final variant = firstItem['serviceVariant'];
        if (variant is Map) {
          final svc = variant['service'];
          final svcMap = svc is Map ? svc : null;
          final name = svcMap?['name']?.toString() ??
              variant['name']?.toString() ??
              'Wash Service';
          final desc = svcMap?['description']?.toString() ?? '';
          final targetVehicleType = svcMap?['targetVehicleType']?.toString() ??
              svcMap?['target_vehicle_type']?.toString() ??
              'car';
          final imageAssetPath = svcMap?['imageAssetPath']?.toString() ??
              svcMap?['image_asset_path']?.toString() ??
              'exterior_wash.png';
          final price = (variant['price'] as num?)?.toDouble() ??
              (firstItem['priceAtBooking'] as num?)?.toDouble() ??
              0.0;
          final duration = (variant['durationMins'] as num?)?.toInt() ?? 45;

          parsedService = ServiceItem(
            id: svcMap?['id']?.toString() ?? variant['id']?.toString() ?? '',
            slug: svcMap?['slug']?.toString() ?? '',
            name: name,
            targetVehicleType: targetVehicleType,
            description: desc,
            basePrice: price,
            durationMinutes: duration,
            imageAssetPath: imageAssetPath,
            inclusions: const {},
          );
        }
      }
    }

    // Parse scheduled date and time slot with scheduledAt support
    final rawDateStr = json['scheduled_date'] ?? json['scheduledDate'] ?? json['scheduledAt'];
    DateTime scheduledDate = DateTime.now();
    if (rawDateStr != null) {
      final parsed = DateTime.tryParse(rawDateStr.toString());
      if (parsed != null) scheduledDate = parsed;
    }

    String timeSlot = json['scheduled_time_slot'] as String? ??
        json['scheduledTimeSlot'] as String? ??
        json['timeSlot'] as String? ??
        '';
    if (timeSlot.isEmpty && rawDateStr != null) {
      final local = scheduledDate.toLocal();
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      timeSlot = '$displayHour:$minute $period';
    }

    final totalAmount = (json['final_total_amount'] as num? ??
            json['totalAmount'] as num? ??
            json['finalTotalAmount'] as num? ??
            0)
        .toDouble();

    final createdAtStr = json['created_at'] ?? json['createdAt'];
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr.toString()) ?? DateTime.now()
        : DateTime.now();

    return Booking(
      id: id,
      bookingNumber: bookingNumber,
      customerId: customerId,
      status: _parseStatus(json['status'] as String?),
      vehicle: json['vehicle'] != null && json['vehicle'] is Map
          ? Vehicle.fromJson(Map<String, dynamic>.from(json['vehicle'] as Map))
          : null,
      service: parsedService,
      address: json['address'] != null && json['address'] is Map
          ? Address.fromJson(Map<String, dynamic>.from(json['address'] as Map))
          : null,
      scheduledDate: scheduledDate,
      scheduledTimeSlot: timeSlot,
      finalTotalAmount: totalAmount,
      pointsAwarded: json['points_awarded'] as int? ?? json['pointsAwarded'] as int? ?? 0,
      partner: json['partner'] != null && json['partner'] is Map
          ? BookingPartner.fromJson(Map<String, dynamic>.from(json['partner'] as Map))
          : null,
      createdAt: createdAt,
    );
  }

  static BookingStatus _parseStatus(String? status) {
    switch (status?.toUpperCase().replaceAll('-', '_')) {
      case 'DRAFT':
        return BookingStatus.draft;
      case 'PENDING_PAYMENT':
        return BookingStatus.pendingPayment;
      case 'PAYMENT_PROCESSING':
        return BookingStatus.paymentProcessing;
      case 'PAYMENT_FAILED':
        return BookingStatus.paymentFailed;
      case 'CONFIRMED':
        return BookingStatus.confirmed;
      case 'ASSIGNMENT_PENDING':
        return BookingStatus.assignmentPending;
      case 'PARTNER_ASSIGNED':
        return BookingStatus.partnerAssigned;
      case 'PARTNER_ON_THE_WAY':
      case 'PROVIDER_ON_THE_WAY':
        return BookingStatus.providerOnTheWay;
      case 'PARTNER_ARRIVED':
      case 'ARRIVED':
        return BookingStatus.arrived;
      case 'SERVICE_STARTED':
        return BookingStatus.serviceStarted;
      case 'SERVICE_IN_PROGRESS':
        return BookingStatus.serviceInProgress;
      case 'SERVICE_COMPLETED':
        return BookingStatus.serviceCompleted;
      case 'CUSTOMER_FEEDBACK_PENDING':
        return BookingStatus.customerFeedbackPending;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      case 'REFUND_PENDING':
        return BookingStatus.refundPending;
      case 'REFUNDED':
        return BookingStatus.refunded;
      default:
        return BookingStatus.unknown;
    }
  }
}
