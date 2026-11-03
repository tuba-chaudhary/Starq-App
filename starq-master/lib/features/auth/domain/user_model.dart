class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final String? referralCode;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.referralCode,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: (json['fullName'] ?? json['full_name'])?.toString() ?? '',
      role: json['role']?.toString() ?? 'CUSTOMER',
      phone: (json['phone'] ?? json['phoneNumber'])?.toString(),
      referralCode: (json['referralCode'] ?? json['referral_code'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'phone': phone,
      'referralCode': referralCode,
    };
  }
}
