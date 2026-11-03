class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final List<String> roles;
  final String? phone;
  final String? referralCode;
  final Map<String, dynamic>? partnerApplication;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.roles = const ['CUSTOMER'],
    this.phone,
    this.referralCode,
    this.partnerApplication,
  });

  bool get isApprovedPartner =>
      roles.contains('PARTNER') ||
      partnerApplication?['status'] == 'APPROVED';

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    List<String> parsedRoles = ['CUSTOMER'];
    if (rawRoles is List) {
      parsedRoles = rawRoles.map((e) => e.toString()).toList();
    } else if (json['role'] != null) {
      parsedRoles = [json['role'].toString()];
    }

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: (json['fullName'] ?? json['full_name'])?.toString() ?? '',
      role: json['role']?.toString() ?? 'CUSTOMER',
      roles: parsedRoles,
      phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
      referralCode: (json['referralCode'] ?? json['referral_code'])?.toString(),
      partnerApplication: json['partnerApplication'] is Map<String, dynamic>
          ? json['partnerApplication'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'roles': roles,
      'phone': phone,
      'referralCode': referralCode,
      if (partnerApplication != null) 'partnerApplication': partnerApplication,
    };
  }
}
