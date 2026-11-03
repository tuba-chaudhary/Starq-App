import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_cache_service.dart';
import '../models/address_model.dart';

class AddressProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<Address> _addresses = [];
  Address? _selectedAddress;
  Address? _lastAddedAddress;
  String? _defaultAddressId;
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  AddressProvider([ApiClient? apiClient]) : _apiClient = apiClient ?? ApiClient() {
    loadFromCache();
  }

  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  Address? get lastAddedAddress => _lastAddedAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _currentUserId;

  String? get defaultAddressId {
    if (_defaultAddressId != null && _addresses.any((a) => a.id == _defaultAddressId)) {
      return _defaultAddressId;
    }
    return null;
  }

  bool isDefaultAddress(Address addr) {
    final defId = defaultAddressId;
    return defId != null && addr.id == defId;
  }

  void setCurrentUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      loadFromCache(userId);
    }
  }

  String _cacheKey(String? userId) {
    final uid = userId ?? _currentUserId;
    return (uid != null && uid.isNotEmpty)
        ? 'cached_addresses_$uid'
        : 'cached_addresses_default';
  }

  String _selectedKey(String? userId) {
    final uid = userId ?? _currentUserId;
    return (uid != null && uid.isNotEmpty)
        ? 'selected_address_id_$uid'
        : 'selected_address_id';
  }

  String _defaultKey(String? userId) {
    final uid = userId ?? _currentUserId;
    return (uid != null && uid.isNotEmpty)
        ? 'default_address_id_$uid'
        : 'default_address_id';
  }

  void loadFromCache([String? userId]) {
    final uid = userId ?? _currentUserId;
    try {
      final jsonStr = LocalCacheService().getString(_cacheKey(uid)) ??
          LocalCacheService().getString('cached_addresses_default');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          _addresses = decoded
              .map((a) => Address.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList();
        }
      }

      Address? explicitDef;
      for (final a in _addresses) {
        if (a.isDefault) {
          explicitDef = a;
          break;
        }
      }

      final cachedDefId = LocalCacheService().getString(_defaultKey(uid)) ??
          LocalCacheService().getString('default_address_id');
      if (explicitDef != null) {
        _defaultAddressId = explicitDef.id;
      } else if (cachedDefId != null && _addresses.any((a) => a.id == cachedDefId)) {
        _defaultAddressId = cachedDefId;
      } else {
        _defaultAddressId = null;
      }

      final cachedId = LocalCacheService().getString(_selectedKey(uid)) ??
          LocalCacheService().getString('selected_address_id');
      if (cachedId != null && _addresses.any((a) => a.id == cachedId)) {
        _selectedAddress = _addresses.firstWhere((a) => a.id == cachedId);
      } else if (_defaultAddressId != null && _addresses.any((a) => a.id == _defaultAddressId)) {
        _selectedAddress = _addresses.firstWhere((a) => a.id == _defaultAddressId);
      } else if (_addresses.isNotEmpty) {
        _selectedAddress = _addresses.first;
      }
    } catch (_) {
      // Ignore cache parsing errors
    }
    notifyListeners();
  }

  Future<void> _persistToCache(String? userId) async {
    final uid = userId ?? _currentUserId;
    try {
      final jsonList = _addresses.map((a) => a.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      await LocalCacheService().setString(_cacheKey(uid), encoded);
      await LocalCacheService().setString('cached_addresses_default', encoded);
      if (_selectedAddress != null) {
        await LocalCacheService().setString(_selectedKey(uid), _selectedAddress!.id);
        await LocalCacheService().setString('selected_address_id', _selectedAddress!.id);
      }
      if (_defaultAddressId != null) {
        await LocalCacheService().setString(_defaultKey(uid), _defaultAddressId!);
        await LocalCacheService().setString('default_address_id', _defaultAddressId!);
      }
    } catch (_) {}
  }

  Future<void> fetchAddresses([String? userId]) async {
    final uid = userId ?? _currentUserId;
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.get('/addresses');
      final dynamic raw = response.data is Map ? (response.data['data'] ?? response.data) : response.data;
      if (raw is List) {
        final fetched = raw.map((a) => Address.fromJson(Map<String, dynamic>.from(a as Map))).toList();
        if (uid != null && uid.isNotEmpty) {
          _addresses = fetched.where((a) => a.userId.isEmpty || a.userId == uid).toList();
        } else {
          _addresses = fetched;
        }
      } else {
        _addresses = [];
      }

      Address? explicitDef;
      for (final a in _addresses) {
        if (a.isDefault) {
          explicitDef = a;
          break;
        }
      }

      final cachedDefId = LocalCacheService().getString(_defaultKey(uid)) ??
          LocalCacheService().getString('default_address_id');
      if (explicitDef != null) {
        _defaultAddressId = explicitDef.id;
        if (uid != null && uid.isNotEmpty) {
          await LocalCacheService().setString(_defaultKey(uid), explicitDef.id);
        }
      } else if (cachedDefId != null && _addresses.any((a) => a.id == cachedDefId)) {
        _defaultAddressId = cachedDefId;
      } else {
        _defaultAddressId = null;
      }

      final cachedId = LocalCacheService().getString(_selectedKey(uid)) ??
          LocalCacheService().getString('selected_address_id');
      if (cachedId != null && _addresses.any((a) => a.id == cachedId)) {
        _selectedAddress = _addresses.firstWhere((a) => a.id == cachedId);
      } else if (_defaultAddressId != null && _addresses.any((a) => a.id == _defaultAddressId)) {
        _selectedAddress = _addresses.firstWhere((a) => a.id == _defaultAddressId);
      } else if (_addresses.isNotEmpty) {
        _selectedAddress = _addresses.first;
      } else {
        _selectedAddress = null;
      }

      await _persistToCache(uid);
    } catch (e) {
      _error = e.toString();
      if (_addresses.isEmpty) {
        loadFromCache(uid);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectAddress(Address address, [String? userId]) {
    final uid = userId ?? _currentUserId;
    _selectedAddress = address;
    if (uid != null && uid.isNotEmpty) {
      LocalCacheService().setString(_selectedKey(uid), address.id);
    }
    LocalCacheService().setString('selected_address_id', address.id);
    notifyListeners();
  }

  void selectAddressById(String id, [String? userId]) {
    final matches = _addresses.where((a) => a.id == id).toList();
    if (matches.isNotEmpty) {
      selectAddress(matches.first, userId);
    }
  }

  Future<void> setDefaultAddress(Address address, [String? userId]) async {
    final uid = userId ?? _currentUserId;
    final previousDefaultId = _defaultAddressId;
    _defaultAddressId = address.id;

    if (uid != null && uid.isNotEmpty) {
      await LocalCacheService().setString(_defaultKey(uid), address.id);
    }
    await LocalCacheService().setString('default_address_id', address.id);

    _addresses = _addresses.map((a) {
      final isDef = a.id == address.id;
      final clean = a.displayTitle;
      final newLine2 = isDef ? '[DEFAULT] $clean' : clean;
      return a.copyWith(isDefault: isDef, line2: newLine2);
    }).toList();

    await _persistToCache(uid);
    notifyListeners();

    try {
      final clean = address.displayTitle;
      await _apiClient.patch('/addresses/${address.id}', data: {
        'line2': '[DEFAULT] $clean',
      });
      if (previousDefaultId != null && previousDefaultId != address.id) {
        final prev = _addresses.where((a) => a.id == previousDefaultId).firstOrNull;
        if (prev != null) {
          final prevClean = prev.displayTitle;
          await _apiClient.patch('/addresses/${prev.id}', data: {
            'line2': prevClean,
          });
        }
      }
    } catch (_) {}
  }

  Future<bool> addAddress(Map<String, dynamic> data, [String? userId]) async {
    final uid = userId ?? _currentUserId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.post('/addresses', data: data);
      final dynamic raw = response.data is Map ? (response.data['data'] ?? response.data) : response.data;
      Address? created;
      if (raw is Map) {
        created = Address.fromJson(Map<String, dynamic>.from(raw));
        _lastAddedAddress = created;
        _addresses.removeWhere((a) => a.id == created!.id);
        _addresses.insert(0, created);
        _selectedAddress = created;
        await _persistToCache(uid);
      }

      try {
        await fetchAddresses(uid);
      } catch (_) {}

      if (created != null) {
        final newId = created.id;
        if (!_addresses.any((a) => a.id == newId)) {
          _addresses.insert(0, created);
          _selectedAddress ??= created;
          await _persistToCache(uid);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAddress(String id, Map<String, dynamic> data, [String? userId]) async {
    final uid = userId ?? _currentUserId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiClient.patch('/addresses/$id', data: data);
      final dynamic raw = response.data is Map ? (response.data['data'] ?? response.data) : response.data;
      if (raw is Map) {
        final updated = Address.fromJson(Map<String, dynamic>.from(raw));
        final idx = _addresses.indexWhere((a) => a.id == id);
        if (idx != -1) {
          _addresses[idx] = updated;
        } else {
          _addresses.insert(0, updated);
        }
        if (_selectedAddress?.id == id) {
          _selectedAddress = updated;
        }
        await _persistToCache(uid);
      }

      try {
        await fetchAddresses(uid);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAddress(String id, [String? userId]) async {
    final uid = userId ?? _currentUserId;
    try {
      await _apiClient.delete('/addresses/$id');
      _addresses.removeWhere((a) => a.id == id);

      if (_defaultAddressId == id) {
        _defaultAddressId = _addresses.isNotEmpty ? _addresses.first.id : null;
        if (_defaultAddressId != null) {
          if (uid != null && uid.isNotEmpty) {
            await LocalCacheService().setString(_defaultKey(uid), _defaultAddressId!);
          }
          await LocalCacheService().setString('default_address_id', _defaultAddressId!);
        } else {
          if (uid != null && uid.isNotEmpty) {
            await LocalCacheService().remove(_defaultKey(uid));
          }
          await LocalCacheService().remove('default_address_id');
        }
      }

      if (_selectedAddress?.id == id) {
        _selectedAddress = _defaultAddressId != null && _addresses.any((a) => a.id == _defaultAddressId)
            ? _addresses.firstWhere((a) => a.id == _defaultAddressId)
            : (_addresses.isNotEmpty ? _addresses.first : null);
        if (_selectedAddress != null) {
          await LocalCacheService().setString(_selectedKey(uid), _selectedAddress!.id);
          await LocalCacheService().setString('selected_address_id', _selectedAddress!.id);
        } else {
          await LocalCacheService().remove(_selectedKey(uid));
          await LocalCacheService().remove('selected_address_id');
        }
      }
      await _persistToCache(uid);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> clear([String? userId]) async {
    final uid = userId ?? _currentUserId;
    _addresses = [];
    _selectedAddress = null;
    _lastAddedAddress = null;
    _defaultAddressId = null;
    _currentUserId = null;
    _error = null;
    _isLoading = false;
    if (uid != null && uid.isNotEmpty) {
      await LocalCacheService().remove(_cacheKey(uid));
      await LocalCacheService().remove(_selectedKey(uid));
      await LocalCacheService().remove(_defaultKey(uid));
    }
    await LocalCacheService().remove('cached_addresses_default');
    await LocalCacheService().remove('selected_address_id');
    await LocalCacheService().remove('default_address_id');
    notifyListeners();
  }
}
