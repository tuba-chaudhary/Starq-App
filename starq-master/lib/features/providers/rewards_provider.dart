import 'package:flutter/foundation.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/points/points_repository.dart';

class RewardsProvider extends ChangeNotifier {
  final PointsRepository _repository;

  PointsSummary? _summary;
  List<PointsEntry> _history = [];
  ReferralSummary? _referralSummary;
  String? _referralCode;

  bool _isLoadingSummary = false;
  bool _isLoadingHistory = false;
  bool _isLoadingReferrals = false;

  String? _summaryError;
  String? _historyError;
  String? _referralError;

  RewardsProvider([PointsRepository? repository])
      : _repository = repository ?? pointsRepository {
    final cached = LocalCacheService().getString('cached_referral_code');
    if (cached != null && cached.isNotEmpty) {
      _referralCode = cached;
    }
  }

  PointsSummary? get summary => _summary;
  List<PointsEntry> get history => _history;
  ReferralSummary? get referralSummary => _referralSummary;
  String? get referralCode {
    if (_referralCode != null && _referralCode!.isNotEmpty) return _referralCode;
    if (_referralSummary?.referralCode != null && _referralSummary!.referralCode.isNotEmpty) {
      return _referralSummary!.referralCode;
    }
    final cached = LocalCacheService().getString('cached_referral_code');
    if (cached != null && cached.isNotEmpty) return cached;
    return null;
  }

  void seedReferralCode(String code) {
    if (code.trim().isNotEmpty) {
      _referralCode = code.trim();
      LocalCacheService().setString('cached_referral_code', _referralCode!);
      notifyListeners();
    }
  }

  bool get isLoadingSummary => _isLoadingSummary;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingReferrals => _isLoadingReferrals;
  bool get isLoadingAny =>
      _isLoadingSummary || _isLoadingHistory || _isLoadingReferrals;

  String? get summaryError => _summaryError;
  String? get historyError => _historyError;
  String? get referralError => _referralError;

  Future<void> loadSummary() async {
    _isLoadingSummary = true;
    _summaryError = null;
    notifyListeners();

    try {
      _summary = await _repository.getSummary();
    } catch (e) {
      _summaryError = 'Could not load points summary. Tap to retry.';
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({int limit = 50}) async {
    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      _history = await _repository.getHistory(limit: limit);
    } catch (e) {
      _historyError = 'Could not load points history. Tap to retry.';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadReferrals({String? fallbackUserCode}) async {
    _isLoadingReferrals = true;
    _referralError = null;
    notifyListeners();

    if (fallbackUserCode != null && fallbackUserCode.isNotEmpty && (_referralCode == null || _referralCode!.isEmpty)) {
      _referralCode = fallbackUserCode;
      LocalCacheService().setString('cached_referral_code', fallbackUserCode);
    }

    try {
      _referralSummary = await _repository.getReferralSummary();
      if (_referralSummary != null && _referralSummary!.referralCode.isNotEmpty) {
        _referralCode = _referralSummary!.referralCode;
        await LocalCacheService().setString('cached_referral_code', _referralCode!);
      }
    } catch (_) {
      try {
        final code = await _repository.getReferralCode();
        if (code.isNotEmpty) {
          _referralCode = code;
          await LocalCacheService().setString('cached_referral_code', code);
        }
      } catch (err) {
        final fallback = _referralCode ?? fallbackUserCode ?? LocalCacheService().getString('cached_referral_code');
        if (fallback != null && fallback.isNotEmpty) {
          _referralCode = fallback;
        } else {
          _referralError = 'Could not load referral details. Tap to retry.';
        }
      }
    } finally {
      _isLoadingReferrals = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll({String? fallbackUserCode}) async {
    await Future.wait([
      loadSummary(),
      loadHistory(),
      loadReferrals(fallbackUserCode: fallbackUserCode),
    ]);
  }

  void clear() {
    _summary = null;
    _history = [];
    _referralSummary = null;
    _referralCode = null;
    _summaryError = null;
    _historyError = null;
    _referralError = null;
    _isLoadingSummary = false;
    _isLoadingHistory = false;
    _isLoadingReferrals = false;
    notifyListeners();
  }
}

