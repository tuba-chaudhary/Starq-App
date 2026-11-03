class Addon {
  final String id;
  final String name;
  final String? description;
  final double price;

  Addon({
    required this.id,
    required this.name,
    this.description,
    required this.price,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    return Addon(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
    );
  }
}
