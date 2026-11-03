class ServiceVariant {
  final String id;
  final String name;
  final double price;
  final int? durationMins;

  ServiceVariant({
    required this.id,
    required this.name,
    required this.price,
    this.durationMins,
  });

  factory ServiceVariant.fromJson(Map<String, dynamic> json) {
    return ServiceVariant(
      id: json['id'],
      name: json['name'] ?? 'Default',
      price: (json['price'] as num).toDouble(),
      durationMins: json['durationMins'] != null ? (json['durationMins'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      if (durationMins != null) 'durationMins': durationMins,
    };
  }
}

class Service {
  final String id;
  final String name;
  final String? description;
  final String category; // CAR or BIKE
  final List<ServiceVariant> variants;

  Service({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.variants,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      variants: (json['variants'] as List?)
              ?.map((v) => ServiceVariant.fromJson(v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}
