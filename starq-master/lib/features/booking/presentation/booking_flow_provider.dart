import 'package:flutter/foundation.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/features/addresses/domain/address.dart';
import 'package:starq_app/features/payment/domain/payment_models.dart';
import 'package:starq_app/features/services/domain/add_on.dart';
import 'package:starq_app/features/services/domain/service_item.dart';
import 'package:starq_app/features/vehicles/domain/vehicle.dart';
import 'package:starq_app/features/booking/data/booking_repository.dart';
import 'package:starq_app/features/booking/domain/booking_model.dart';
import 'package:starq_app/features/booking/domain/booking_quote.dart';

class BookingFlowProvider extends ChangeNotifier {
  final BookingRepository repository = BookingRepository();

  Vehicle? vehicle;
  ServiceItem? service;
  final List<AddOn> selectedAddOns = [];
  Address? address;
  DateTime? date;
  String? timeSlot;
  String? consentId;
  String? damageNotes;
  BookingQuote? quote;
  RazorpayOrder? order;
  Booking? lastConfirmed;
  bool busy = false;
  String? error;

  void startWithVehicle(Vehicle v) {
    vehicle = v;
    service = null;
    selectedAddOns.clear();
    address = null;
    date = null;
    timeSlot = null;
    consentId = null;
    quote = null;
    order = null;
    notifyListeners();
  }

  void setService(ServiceItem item) {
    service = item;
    selectedAddOns.clear();
    quote = null;
    notifyListeners();
  }

  void toggleAddOn(AddOn addOn) {
    final index = selectedAddOns.indexWhere((a) => a.id == addOn.id);
    if (index >= 0) {
      selectedAddOns.removeAt(index);
    } else {
      selectedAddOns.add(addOn);
    }
    quote = null;
    notifyListeners();
  }

  void skipAddOns() {
    selectedAddOns.clear();
    quote = null;
    notifyListeners();
  }

  void setAddress(Address value) {
    address = value;
    notifyListeners();
  }

  void setSlot(DateTime selectedDate, String slot) {
    date = selectedDate;
    timeSlot = slot;
    notifyListeners();
  }

  Future<bool> refreshQuote() async {
    if (vehicle == null || service == null || address == null || date == null || timeSlot == null || consentId == null) {
      error = 'Complete vehicle, service, address, slot and consent first';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      quote = await repository.quote({
        'vehicle_id': vehicle!.id,
        'service_id': service!.id,
        'addon_ids': selectedAddOns.map((a) => a.id).toList(),
        'address_id': address!.id,
        'scheduled_date':
            '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
        'scheduled_time_slot': timeSlot,
        'consent_id': consentId,
      });
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e is AppException ? e.message : e.toString();
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<RazorpayOrder?> createPaymentOrder() async {
    if (quote == null) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      order = await repository.createOrder(quote!.quoteToken);
      busy = false;
      notifyListeners();
      return order;
    } catch (e) {
      error = e is AppException ? e.message : e.toString();
      busy = false;
      notifyListeners();
      return null;
    }
  }
}
