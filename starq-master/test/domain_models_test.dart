import 'package:flutter_test/flutter_test.dart';
import 'package:starq_app/features/auth/domain/user.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/booking/domain/booking_quote.dart';
import 'package:starq_app/core/utils/formatters.dart';
import 'package:starq_app/core/utils/validators.dart';

void main() {
  group('Domain Models Unit Tests', () {
    test('User serialization test', () {
      final user = User(
        id: 'user-123',
        fullName: 'Aarav Sharma',
        email: 'aarav@example.com',
        phone: '9876543210',
        role: UserRole.customer,
        createdAt: DateTime(2026, 1, 1),
      );

      final json = user.toJson();
      expect(json['full_name'], 'Aarav Sharma');
      expect(json['role'], 'customer');

      final deserialized = User.fromJson(json);
      expect(deserialized.id, 'user-123');
      expect(deserialized.fullName, 'Aarav Sharma');
      expect(deserialized.email, 'aarav@example.com');
    });

    test('Vehicle category and subtitle formatting test', () {
      final car = Vehicle(
        id: 'v-1',
        userId: 'u-1',
        category: VehicleCategory.sedan,
        brand: 'Honda',
        model: 'City',
        variant: 'ZX',
        registrationNumber: 'DL 01 AB 1234',
        color: 'White',
      );

      expect(car.isBike, false);
      expect(car.displayName, 'Honda City (ZX)');
      expect(car.subtitle, 'DL 01 AB 1234 · SEDAN · White');

      final bike = Vehicle(
        id: 'v-2',
        userId: 'u-1',
        category: VehicleCategory.bike,
        brand: 'Royal Enfield',
        model: 'Classic 350',
        registrationNumber: 'DL 02 CD 5678',
      );

      expect(bike.isBike, true);
      expect(bike.displayName, 'Royal Enfield Classic 350');
    });

    test('BookingQuote authoritative calculation parsing', () {
      final json = {
        'base_service_amount': 249.0,
        'add_ons_amount': 50.0,
        'convenience_fee': 30.0,
        'tax_amount': 59.22,
        'discount_amount': 0.0,
        'final_total_amount': 388.22,
        'points_awarded': 38,
        'quote_token': 'signed_jwt_token_123',
      };

      final quote = BookingQuote.fromJson(json);
      expect(quote.finalTotalAmount, 388.22);
      expect(quote.pointsAwarded, 38);
      expect(quote.quoteToken, 'signed_jwt_token_123');
    });

    test('Formatters & Validators helper test', () {
      expect(AppFormatters.currency(249), '₹249');
      expect(AppFormatters.formatPhone('9876543210'), '+91 98765 43210');

      expect(AppValidators.requiredField(''), 'This field is required');
      expect(AppValidators.requiredField('OK'), null);
      expect(AppValidators.email('invalid'), 'Please enter a valid email address');
      expect(AppValidators.email('test@starq.in'), null);
      expect(AppValidators.phone('123'), 'Please enter a valid 10-digit mobile number');
      expect(AppValidators.phone('9876543210'), null);
    });
  });
}
