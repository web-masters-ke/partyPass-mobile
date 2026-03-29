class Venue {
  final String id;
  final String name;
  final String address;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final int? capacity;
  final String? googleMapsUrl;
  final String? imageUrl;
  final String createdAt;

  Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.country = 'KE',
    this.latitude,
    this.longitude,
    this.capacity,
    this.googleMapsUrl,
    this.imageUrl,
    required this.createdAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? 'KE',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      capacity: int.tryParse(json['capacity']?.toString() ?? ''),
      googleMapsUrl: json['googleMapsUrl']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'capacity': capacity,
        'googleMapsUrl': googleMapsUrl,
        'imageUrl': imageUrl,
        'createdAt': createdAt,
      };
}
