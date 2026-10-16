class CountryInfo {
  final String name;
  final String code;
  final String currency;
  final String defaultDistanceUnit; // 'km' or 'mi'
  final String defaultVolumeUnit; // 'L' or 'gal'
  final String defaultEfficiencyUnit; // 'km/L', 'L/100km', 'MPG'
  final List<String> popularStations;

  const CountryInfo({
    required this.name,
    required this.code,
    required this.currency,
    required this.defaultDistanceUnit,
    required this.defaultVolumeUnit,
    required this.defaultEfficiencyUnit,
    required this.popularStations,
  });
}

class CountryRepository {
  static const List<CountryInfo> countries = [
    CountryInfo(
      name: 'United States',
      code: 'US',
      currency: '\$',
      defaultDistanceUnit: 'mi',
      defaultVolumeUnit: 'gal',
      defaultEfficiencyUnit: 'MPG',
      popularStations: [
        'Shell',
        'Chevron',
        'Exxon',
        'Mobil',
        'BP',
        'Costco',
        'Marathon',
        '7-Eleven',
        'Phillips 66',
        'Sunoco',
        'Valero',
        'Circle K',
      ],
    ),
    CountryInfo(
      name: 'United Kingdom',
      code: 'GB',
      currency: '£',
      defaultDistanceUnit: 'mi',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'MPG',
      popularStations: [
        'BP',
        'Shell',
        'Esso',
        'Texaco',
        'Tesco',
        'Sainsbury\'s',
        'Morrisons',
        'Asda',
        'Applegreen',
        'Jet',
      ],
    ),
    CountryInfo(
      name: 'Canada',
      code: 'CA',
      currency: 'C\$',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'Petro-Canada',
        'Esso',
        'Shell',
        'Canadian Tire',
        'Pioneer',
        'Husky',
        'Costco Gas',
        'Irving',
        'Ultramar',
      ],
    ),
    CountryInfo(
      name: 'Australia',
      code: 'AU',
      currency: 'A\$',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'Ampol',
        'BP',
        'Shell / Coles Express',
        '7-Eleven',
        'United Petroleum',
        'Puma Energy',
        'Liberty',
        'Costco',
      ],
    ),
    CountryInfo(
      name: 'India',
      code: 'IN',
      currency: '₹',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'km/L',
      popularStations: [
        'IndianOil (IOCL)',
        'Bharat Petroleum (BPCL)',
        'Hindustan Petroleum (HPCL)',
        'Reliance Petroleum / Jio-bp',
        'Shell',
        'Nayara Energy',
      ],
    ),
    CountryInfo(
      name: 'Germany',
      code: 'DE',
      currency: '€',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'Aral',
        'Shell',
        'TotalEnergies',
        'Esso',
        'Jet',
        'Avia',
        'HEM',
        'OMV',
      ],
    ),
    CountryInfo(
      name: 'France',
      code: 'FR',
      currency: '€',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'TotalEnergies',
        'Shell',
        'BP',
        'Esso Express',
        'E.Leclerc',
        'Carrefour',
        'Intermarché',
        'Avia',
      ],
    ),
    CountryInfo(
      name: 'United Arab Emirates',
      code: 'AE',
      currency: 'AED',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'km/L',
      popularStations: [
        'ADNOC Distribution',
        'ENOC',
        'EPPCO',
        'Emarat',
        'Shell',
      ],
    ),
    CountryInfo(
      name: 'Japan',
      code: 'JP',
      currency: '¥',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'km/L',
      popularStations: [
        'ENEOS',
        'Idemitsu Kosan (apollostation)',
        'Cosmo Oil',
        'Kygnus',
        'Taiyo Oil (SOLATO)',
      ],
    ),
    CountryInfo(
      name: 'Brazil',
      code: 'BR',
      currency: 'R\$',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'km/L',
      popularStations: [
        'Posto Ipiranga',
        'Petrobras (BR Distribuidora)',
        'Raízen (Shell)',
        'Ale Sat',
      ],
    ),
    CountryInfo(
      name: 'Mexico',
      code: 'MX',
      currency: 'Mex\$',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'km/L',
      popularStations: [
        'Pemex',
        'OXXO Gas',
        'BP',
        'Mobil',
        'G500',
        'Shell',
        'Total',
      ],
    ),
    CountryInfo(
      name: 'South Africa',
      code: 'ZA',
      currency: 'R',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'Engen',
        'Shell',
        'BP',
        'Sasol',
        'Caltex (Astron Energy)',
        'TotalEnergies',
      ],
    ),
    CountryInfo(
      name: 'New Zealand',
      code: 'NZ',
      currency: 'NZ\$',
      defaultDistanceUnit: 'km',
      defaultVolumeUnit: 'L',
      defaultEfficiencyUnit: 'L/100km',
      popularStations: [
        'Z Energy',
        'BP',
        'Mobil',
        'Gull',
        'Caltex',
        'Allied Petroleum',
      ],
    ),
  ];

  static CountryInfo getCountryByName(String name) {
    return countries.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => countries.first,
    );
  }

  static CountryInfo getCountryByCode(String code) {
    return countries.firstWhere(
      (c) => c.code.toLowerCase() == code.toLowerCase(),
      orElse: () => countries.first,
    );
  }
}

