class Quote {
  final String serviceName;
  final double basePrice;
  final double addonsTotal;
  final double subtotal;
  final double taxes;
  final double total;
  final List<dynamic> addons;

  Quote({
    required this.serviceName,
    required this.basePrice,
    required this.addonsTotal,
    required this.subtotal,
    required this.taxes,
    required this.total,
    required this.addons,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      serviceName: json['serviceName'] ?? '',
      basePrice: (json['basePrice'] as num).toDouble(),
      addonsTotal: (json['addonsTotal'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxes: (json['taxes'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      addons: json['addons'] ?? [],
    );
  }
}
