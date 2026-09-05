/// Extra information about one explicitly requested public IP address.
/// Country names are resolved locally, never taken from the API's language.
class IpDetails {
  const IpDetails({
    required this.ip,
    required this.countryCode,
    this.region,
    this.city,
    this.domain,
    this.geographyLanguage = 'en',
  });

  factory IpDetails.fromJson(
    Map<String, dynamic> json, {
    required String geographyLanguage,
  }) {
    final ip = _text(json['ip']);
    final countryCode = _text(json['country_code']);
    if (json['success'] != true ||
        ip == null ||
        countryCode == null ||
        !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
      throw const FormatException('Invalid IP details response');
    }
    final connection = json['connection'];
    return IpDetails(
      ip: ip,
      countryCode: countryCode.toUpperCase(),
      region: _text(json['region']),
      city: _text(json['city']),
      domain: connection is Map ? _text(connection['domain']) : null,
      geographyLanguage: geographyLanguage,
    );
  }

  final String ip;
  final String countryCode;
  final String? region;
  final String? city;
  final String? domain;
  final String geographyLanguage;

  String? get regionAndCity {
    final parts = <String>{
      if (region?.isNotEmpty == true) region!,
      if (city?.isNotEmpty == true) city!,
    };
    return parts.isEmpty ? null : parts.join(' / ');
  }

  static String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
