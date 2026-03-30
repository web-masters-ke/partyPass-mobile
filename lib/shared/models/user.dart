class User {
  final String id;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String role;
  final bool isVerified;
  final bool isActive;
  final String loyaltyTier;
  final int loyaltyPoints;
  final String? city;
  final String? dateOfBirth;
  final String? gender;
  final String? membershipPlan;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.role,
    required this.isVerified,
    required this.isActive,
    required this.loyaltyTier,
    required this.loyaltyPoints,
    this.city,
    this.dateOfBirth,
    this.gender,
    this.membershipPlan,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      role: json['role']?.toString() ?? 'ATTENDEE',
      isVerified: json['isVerified'] == true,
      isActive: json['isActive'] != false,
      loyaltyTier: json['loyaltyTier']?.toString() ?? 'BRONZE',
      loyaltyPoints: int.tryParse(json['loyaltyPoints']?.toString() ?? '0') ?? 0,
      city: json['city']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      gender: json['gender']?.toString(),
      membershipPlan: json['membershipPlan']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'avatarUrl': avatarUrl,
        'role': role,
        'isVerified': isVerified,
        'isActive': isActive,
        'loyaltyTier': loyaltyTier,
        'loyaltyPoints': loyaltyPoints,
        'city': city,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'membershipPlan': membershipPlan,
        'createdAt': createdAt,
      };

  bool get isStaff =>
      role == 'GATE_STAFF' || role == 'ORGANIZER' || role == 'ADMIN' || role == 'SUPER_ADMIN';
}
