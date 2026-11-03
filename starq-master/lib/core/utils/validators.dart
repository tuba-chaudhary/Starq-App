class AppValidators {
  static String? requiredField(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    final tenDigit = (cleaned.length == 12 && cleaned.startsWith('91'))
        ? cleaned.substring(2)
        : cleaned;

    if (tenDigit.length != 10) {
      return 'Please enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]').hasMatch(tenDigit)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }
    return null;
  }

  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN code is required';
    }
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 6) {
      return 'PIN code must be exactly 6 digits';
    }
    return null;
  }

  static String? name(String? value, [String fieldName = 'Full Name']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static const Set<String> _indianStateCodes = {
    'AN', 'AP', 'AR', 'AS', 'BR', 'CG', 'CH', 'DD', 'DL', 'DN',
    'GA', 'GJ', 'HP', 'HR', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD',
    'MH', 'ML', 'MN', 'MP', 'MZ', 'NL', 'OD', 'OR', 'PB', 'PY',
    'RJ', 'SK', 'TN', 'TR', 'TS', 'UK', 'UA', 'UP', 'WB',
  };

  // Indian standard: [State 2 letters][RTO 1 digit + letter OR 1-2 digits][Series 0-3 letters][Number 1-4 digits]
  static final RegExp _standardPlateRegex = RegExp(
    r'^([A-Z]{2})(?:([0-9][A-Z])|([0-9]{1,2}))([A-Z]{0,3})([0-9]{1,4})$',
  );

  // Bharat Series (BH): [Year 2 digits]BH[Number 4 digits][Series 1-2 letters]
  static final RegExp _bharatSeriesRegex = RegExp(
    r'^([0-9]{2})BH([0-9]{4})([A-Z]{1,2})$',
  );

  static String? registrationNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Registration number is required';
    }
    final raw = value.trim();
    if (RegExp(r'[^a-zA-Z0-9\s\-_]').hasMatch(raw)) {
      return 'Registration number should only contain letters and numbers';
    }

    final cleaned = raw.replaceAll(RegExp(r'[\s\-_]+'), '').toUpperCase();
    if (cleaned.length < 5 || cleaned.length > 15) {
      return 'Please enter a valid vehicle plate (e.g. DL 01 AB 1234)';
    }

    // Check BH series
    if (_bharatSeriesRegex.hasMatch(cleaned)) {
      return null;
    }

    // Check standard State/UT series
    final match = _standardPlateRegex.firstMatch(cleaned);
    if (match == null) {
      return 'Please enter a valid vehicle plate (e.g. DL 01 AB 1234)';
    }

    final stateCode = match.group(1);
    if (stateCode == null || !_indianStateCodes.contains(stateCode)) {
      return 'Please enter a valid vehicle plate (e.g. DL 01 AB 1234)';
    }

    return null;
  }

  static String normalizeRegistrationNumber(String value) {
    final raw = value.trim();
    final cleaned = raw.replaceAll(RegExp(r'[\s\-_]+'), '').toUpperCase();

    // Check BH series
    final bhMatch = _bharatSeriesRegex.firstMatch(cleaned);
    if (bhMatch != null) {
      final year = bhMatch.group(1) ?? '';
      final num = bhMatch.group(2) ?? '';
      final series = bhMatch.group(3) ?? '';
      return '$year BH $num $series'.trim();
    }

    // Check standard State series
    final stdMatch = _standardPlateRegex.firstMatch(cleaned);
    if (stdMatch != null) {
      final state = stdMatch.group(1) ?? '';
      final rto = stdMatch.group(2) ?? stdMatch.group(3) ?? '';
      final series = stdMatch.group(4) ?? '';
      final num = stdMatch.group(5) ?? '';
      if (series.isNotEmpty) {
        return '$state $rto $series $num'.trim();
      } else {
        return '$state $rto $num'.trim();
      }
    }

    return raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
