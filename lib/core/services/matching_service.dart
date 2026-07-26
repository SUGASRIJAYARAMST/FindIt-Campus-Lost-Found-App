import 'dart:math';

import '../../domain/models/item_model.dart';

// ---------------------------------------------------------------------------
// Weight Profile
// ---------------------------------------------------------------------------

class MatchWeightProfile {
  final Map<String, double> weights;
  final String label;

  MatchWeightProfile({required this.weights, required this.label});

  double operator [](String key) => weights[key] ?? 0.0;
}

// ---------------------------------------------------------------------------
// Extracted Attributes
// ---------------------------------------------------------------------------

class ExtractedAttributes {
  final Set<String> brands;
  final Set<String> models;
  final Set<String> colors;
  final Set<String> materials;
  final Set<String> keywords;

  const ExtractedAttributes({
    this.brands = const {},
    this.models = const {},
    this.colors = const {},
    this.materials = const {},
    this.keywords = const {},
  });
}

// ---------------------------------------------------------------------------
// Evidence
// ---------------------------------------------------------------------------

enum EvidenceLevel { strong, moderate, weak }

class ReasonItem {
  final String attribute;
  final bool isMatch;
  final String detail;

  const ReasonItem({
    required this.attribute,
    required this.isMatch,
    required this.detail,
  });

  @override
  String toString() => '${isMatch ? "✔" : "✖"} $detail';
}

class EvidenceResult {
  final double confidence;
  final EvidenceLevel evidenceLevel;
  final List<ReasonItem> matchingReasons;
  final List<ReasonItem> conflictingReasons;

  const EvidenceResult({
    required this.confidence,
    required this.evidenceLevel,
    required this.matchingReasons,
    required this.conflictingReasons,
  });

  String get evidenceLevelLabel {
    switch (evidenceLevel) {
      case EvidenceLevel.strong:
        return 'Strong';
      case EvidenceLevel.moderate:
        return 'Moderate';
      case EvidenceLevel.weak:
        return 'Weak';
    }
  }

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('Overall evidence: $evidenceLevelLabel (${(confidence * 100).round()}%)');
    for (final r in matchingReasons) {
      buf.writeln('  ✔ ${r.detail}');
    }
    for (final r in conflictingReasons) {
      buf.writeln('  ✖ ${r.detail}');
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Attribute Extractor
// ---------------------------------------------------------------------------

class AttributeExtractor {
  AttributeExtractor._();

  // -- Lexicons ------------------------------------------------------------

  static const Set<String> _brands = {
    'samsung', 'apple', 'iphone', 'ipad', 'airpods', 'galaxy', 'oneplus',
    'sony', 'bose', 'jbl', 'nike', 'adidas', 'puma', 'reebok', 'gucci',
    'zara', 'h&m', 'levi', 'rayban', 'oakley', 'casio', 'fossil', 'lg',
    'dell', 'lenovo', 'asus', 'hp', 'macbook', 'mi', 'xiaomi', 'oppo',
    'vivo', 'realme', 'nothing', 'pixel', 'huawei', 'honor', 'toro',
    'tkmg', 'herman miller', 'swiss', 'parker', 'montblanc', 'fastrack',
    'titan', 'timex', 'skagen', 'amazfit', 'noise', 'boat', 'ptron',
    'western digital', 'seagate', 'crucial', 'kingston', 'sandisk',
    'logitech', 'razer', 'corsair', 'hyperx', 'steelseries',
  };

  static const Set<String> _colors = {
    'black', 'white', 'blue', 'red', 'green', 'yellow', 'pink', 'purple',
    'orange', 'brown', 'grey', 'gray', 'silver', 'gold', 'navy', 'teal',
    'beige', 'maroon', 'olive', 'cyan', 'magenta', 'tan', 'ivory', 'charcoal',
    'sky blue', 'dark blue', 'light blue', 'dark green', 'light green',
    'rose gold', 'space gray', 'midnight', 'starlight', 'bronze', 'copper',
    'rust', 'cream', 'peach', 'lavender', 'mint', 'coral', 'turquoise',
  };

  static const Set<String> _materials = {
    'leather', 'canvas', 'nylon', 'polyester', 'cotton', 'rubber', 'plastic',
    'metal', 'steel', 'aluminum', 'aluminium', 'titanium', 'wood', 'glass',
    'silicone', 'fabric', 'suede', 'denim', 'wool', 'silk', 'linen',
    'neoprene', 'felt', 'velvet', 'corduroy', 'mesh', 'knit', 'cashmere',
    'acrylic', 'spandex', 'lycra', 'microfiber', 'fleece', 'gore-tex',
    'kevlar', 'carbon fiber', 'bamboo', 'cork', 'jute', 'hemp',
  };

  static final List<RegExp> _modelPatterns = [
    RegExp(r'\b(?:pro|max|plus|mini|ultra|lite|se)\b', caseSensitive: false),
    RegExp(r'\b\d{4}\b'),
    RegExp(r'\d+(?:gb|tb|mb)', caseSensitive: false),
    RegExp(r'(?:gen|generation)\s*\d+', caseSensitive: false),
    RegExp(r'\b[a-z]{1,3}\d{2,4}\b'),
    RegExp(r'(?:v|version)\s*\d+', caseSensitive: false),
    RegExp(r'\b(?:mk|mark)\s*[ivxlc]+\b', caseSensitive: false),
  ];

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'is', 'it', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'and', 'or', 'but', 'not', 'this', 'that',
    'was', 'are', 'be', 'has', 'had', 'have', 'from', 'i', 'my',
    'me', 'we', 'our', 'you', 'your', 'he', 'she', 'they', 'them',
    'its', 'his', 'her', 'will', 'can', 'may', 'shall', 'do', 'did',
    'if', 'so', 'no', 'yes', 'very', 'just', 'also', 'than', 'too',
    'about', 'been', 'being', 'into', 'over', 'such', 'after', 'before',
    'between', 'under', 'again', 'there', 'here', 'when', 'where',
    'how', 'all', 'each', 'every', 'both', 'few', 'more', 'most',
    'other', 'some', 'any', 'only', 'own', 'same', 'then', 'now',
    'once', 'twice', 'what', 'which', 'who', 'whom', 'found', 'lost',
    'near', 'around', 'behind', 'next', 'left', 'right', 'front',
    'inside', 'outside', 'top', 'bottom', 'back', 'side',
  };

  // -- Public API ----------------------------------------------------------

  static ExtractedAttributes extract(ItemModel item) {
    final text = '${item.title} ${item.description}'.toLowerCase();
    return ExtractedAttributes(
      brands: _findBrands(text),
      models: _findModels(text),
      colors: _findColors(text),
      materials: _findMaterials(text),
      keywords: _findKeywords('${item.title} ${item.description}'),
    );
  }

  static ExtractedAttributes extractFromText(String title, String description) {
    final text = '$title $description'.toLowerCase();
    return ExtractedAttributes(
      brands: _findBrands(text),
      models: _findModels(text),
      colors: _findColors(text),
      materials: _findMaterials(text),
      keywords: _findKeywords('$title $description'),
    );
  }

  // -- Extraction ----------------------------------------------------------

  static Set<String> _findBrands(String text) {
    final words = text.split(RegExp(r'\s+'));
    return words.where((w) => _brands.contains(w)).toSet();
  }

  static Set<String> _findModels(String text) {
    final found = <String>{};
    for (final pattern in _modelPatterns) {
      for (final match in pattern.allMatches(text)) {
        found.add(match.group(0)!.toLowerCase());
      }
    }
    return found;
  }

  static Set<String> _findColors(String text) {
    final found = <String>{};
    for (final color in _colors) {
      if (text.contains(color)) {
        found.add(color);
      }
    }
    return found;
  }

  static Set<String> _findMaterials(String text) {
    final found = <String>{};
    for (final material in _materials) {
      if (text.contains(material)) {
        found.add(material);
      }
    }
    return found;
  }

  static Set<String> _findKeywords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !_stopWords.contains(w))
        .map(_stem)
        .where((w) => w.length > 1)
        .toSet();
  }

  static String _stem(String word) {
    var w = word.toLowerCase();
    if (w.length <= 3) return w;

    if (w.endsWith('ing') && w.length > 5) {
      final base = w.substring(0, w.length - 3);
      if (base.length >= 2 && base[base.length - 1] == base[base.length - 2]) {
        return base.substring(0, base.length - 1);
      }
      if (base.endsWith('y')) return '${base.substring(0, base.length - 1)}ie';
      if (base.endsWith('e')) return base;
      return base;
    }

    if (w.endsWith('tion') && w.length > 5) return w.substring(0, w.length - 4);
    if (w.endsWith('sion') && w.length > 5) return w.substring(0, w.length - 4);
    if (w.endsWith('ment') && w.length > 5) return w.substring(0, w.length - 4);
    if (w.endsWith('ness') && w.length > 5) return w.substring(0, w.length - 4);
    if ((w.endsWith('able') || w.endsWith('ible')) && w.length > 5) return w.substring(0, w.length - 4);
    if (w.endsWith('ly') && w.length > 4) return w.substring(0, w.length - 2);

    if ((w.endsWith('er') || w.endsWith('or')) && w.length > 4) {
      final base = w.substring(0, w.length - 2);
      if (base.length >= 2 && base[base.length - 1] == base[base.length - 2]) {
        return base.substring(0, base.length - 1);
      }
      return base;
    }

    if (w.endsWith('ed') && w.length > 4) {
      final base = w.substring(0, w.length - 2);
      if (base.length >= 2 && base[base.length - 1] == base[base.length - 2]) {
        return base.substring(0, base.length - 1);
      }
      if (base.endsWith('i')) return '${base.substring(0, base.length - 1)}y';
      if (base.endsWith('e')) return base;
      return base;
    }

    if (w.endsWith('ies') && w.length > 4) return '${w.substring(0, w.length - 3)}y';

    if (w.endsWith('es') && w.length > 4) {
      final base = w.substring(0, w.length - 2);
      if (base.endsWith('s') || base.endsWith('x') || base.endsWith('z') ||
          base.endsWith('ch') || base.endsWith('sh')) {
        return base;
      }
      if (base.endsWith('e')) {
        return base;
      }
      return base;
    }

    if (w.endsWith('s') && !w.endsWith('ss') && w.length > 3) {
      return w.substring(0, w.length - 1);
    }

    return w;
  }
}

// ---------------------------------------------------------------------------
// Category Profiles
// ---------------------------------------------------------------------------

class CategoryProfiles {
  CategoryProfiles._();

  static final Map<String, MatchWeightProfile> profiles = {
    'electronics': MatchWeightProfile(
      label: 'Electronics',
      weights: {
        'title': 0.18,
        'category': 0.05,
        'description': 0.10,
        'location': 0.12,
        'date': 0.08,
        'brand': 0.25,
        'color': 0.10,
        'model': 0.07,
        'material': 0.05,
      },
    ),
    'wallet': MatchWeightProfile(
      label: 'Wallet',
      weights: {
        'title': 0.20,
        'category': 0.12,
        'description': 0.15,
        'location': 0.10,
        'date': 0.08,
        'brand': 0.08,
        'color': 0.12,
        'model': 0.05,
        'material': 0.10,
      },
    ),
    'documents': MatchWeightProfile(
      label: 'Documents',
      weights: {
        'title': 0.15,
        'category': 0.10,
        'description': 0.30,
        'location': 0.20,
        'date': 0.20,
        'brand': 0.00,
        'color': 0.00,
        'model': 0.00,
        'material': 0.05,
      },
    ),
    'bags': MatchWeightProfile(
      label: 'Bags',
      weights: {
        'title': 0.18,
        'category': 0.08,
        'description': 0.18,
        'location': 0.12,
        'date': 0.08,
        'brand': 0.12,
        'color': 0.12,
        'model': 0.00,
        'material': 0.12,
      },
    ),
    'clothing': MatchWeightProfile(
      label: 'Clothing',
      weights: {
        'title': 0.12,
        'category': 0.08,
        'description': 0.18,
        'location': 0.12,
        'date': 0.08,
        'brand': 0.12,
        'color': 0.15,
        'model': 0.00,
        'material': 0.15,
      },
    ),
    'accessories': MatchWeightProfile(
      label: 'Accessories',
      weights: {
        'title': 0.18,
        'category': 0.08,
        'description': 0.15,
        'location': 0.12,
        'date': 0.08,
        'brand': 0.12,
        'color': 0.12,
        'model': 0.05,
        'material': 0.10,
      },
    ),
    'keys': MatchWeightProfile(
      label: 'Keys',
      weights: {
        'title': 0.18,
        'category': 0.08,
        'description': 0.20,
        'location': 0.20,
        'date': 0.15,
        'brand': 0.00,
        'color': 0.05,
        'model': 0.05,
        'material': 0.09,
      },
    ),
    'id cards': MatchWeightProfile(
      label: 'ID Cards',
      weights: {
        'title': 0.15,
        'category': 0.10,
        'description': 0.28,
        'location': 0.20,
        'date': 0.15,
        'brand': 0.00,
        'color': 0.05,
        'model': 0.05,
        'material': 0.02,
      },
    ),
    'books': MatchWeightProfile(
      label: 'Books',
      weights: {
        'title': 0.28,
        'category': 0.08,
        'description': 0.22,
        'location': 0.15,
        'date': 0.10,
        'brand': 0.05,
        'color': 0.05,
        'model': 0.00,
        'material': 0.07,
      },
    ),
  };

  static final _default = MatchWeightProfile(
    label: 'Default',
    weights: {
      'title': 0.28,
      'category': 0.18,
      'description': 0.12,
      'location': 0.18,
      'date': 0.12,
      'brand': 0.00,
      'color': 0.00,
      'model': 0.00,
      'material': 0.12,
    },
  );

  static MatchWeightProfile resolve(String category) {
    return profiles[category.toLowerCase().trim()] ?? _default;
  }
}

// ---------------------------------------------------------------------------
// Score Breakdown
// ---------------------------------------------------------------------------

class FactorBreakdown {
  final String factor;
  final double weight;
  final double factorScore;
  final double maxPoints;
  final double earnedPoints;
  final int percentage;
  final String reason;

  const FactorBreakdown({
    required this.factor,
    required this.weight,
    required this.factorScore,
    required this.maxPoints,
    required this.earnedPoints,
    required this.percentage,
    required this.reason,
  });

  @override
  String toString() =>
      '$factor: ${earnedPoints.toStringAsFixed(2)}/${maxPoints.toStringAsFixed(2)} '
      '($percentage%) — $reason';
}

class ScoreBreakdown {
  final double totalScore;
  final String profileLabel;
  final List<FactorBreakdown> factors;

  const ScoreBreakdown({
    required this.totalScore,
    required this.profileLabel,
    required this.factors,
  });

  List<FactorBreakdown> get topFactors =>
      factors.toList()..sort((a, b) => b.earnedPoints.compareTo(a.earnedPoints));

  List<FactorBreakdown> get matchedFactors =>
      factors.where((f) => f.factorScore >= 0.5).toList();

  List<FactorBreakdown> get unmatchedFactors =>
      factors.where((f) => f.factorScore < 0.5).toList();

  double get totalMaxPoints =>
      factors.fold(0, (sum, f) => sum + f.maxPoints);

  double get totalEarnedPoints =>
      factors.fold(0, (sum, f) => sum + f.earnedPoints);

  @override
  String toString() {
    final buf = StringBuffer('Score Breakdown ($profileLabel): ${totalScore.round()}%\n');
    for (final f in factors) {
      buf.writeln('  ${f.factor.padRight(12)} '
          '${f.earnedPoints.toStringAsFixed(2).padLeft(6)}/${f.maxPoints.toStringAsFixed(2).padLeft(6)} '
          '${f.percentage.toString().padLeft(3)}%  ${f.reason}');
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// MatchResult
// ---------------------------------------------------------------------------

class MatchResult {
  final ItemModel lostItem;
  final ItemModel foundItem;
  final double score;
  final Map<String, double> factors;
  final DateTime matchedAt;
  final String profileLabel;
  final EvidenceResult evidence;
  final ScoreBreakdown breakdown;

  MatchResult({
    required this.lostItem,
    required this.foundItem,
    required this.score,
    required this.factors,
    DateTime? matchedAt,
    this.profileLabel = 'Default',
    EvidenceResult? evidence,
    ScoreBreakdown? breakdown,
  })  : matchedAt = matchedAt ?? DateTime.now(),
        evidence = evidence ?? const EvidenceResult(
          confidence: 0,
          evidenceLevel: EvidenceLevel.weak,
          matchingReasons: [],
          conflictingReasons: [],
        ),
        breakdown = breakdown ?? const ScoreBreakdown(
          totalScore: 0,
          profileLabel: 'Default',
          factors: [],
        );

  String get explanation {
    final topFactors = factors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final reasons = <String>[];
    for (final entry in topFactors.take(4)) {
      if (entry.value < 0.3) continue;
      switch (entry.key) {
        case 'title':
          if (entry.value >= 0.7) {
            reasons.add('Very similar item name');
          } else if (entry.value >= 0.4) {
            reasons.add('Similar item name');
          }
          break;
        case 'category':
          if (entry.value >= 0.7) {
            reasons.add('Same category');
          } else if (entry.value >= 0.4) {
            reasons.add('Related category');
          }
          break;
        case 'description':
          if (entry.value >= 0.5) {
            reasons.add('Similar description');
          }
          break;
        case 'location':
          if (entry.value >= 0.7) {
            reasons.add('Same location');
          } else if (entry.value >= 0.4) {
            reasons.add('Nearby location');
          }
          break;
        case 'date':
          if (entry.value >= 0.7) {
            reasons.add('Same date');
          } else if (entry.value >= 0.4) {
            reasons.add('Close date');
          }
          break;
        case 'brand':
          if (entry.value >= 0.7) {
            reasons.add('Same brand');
          } else if (entry.value >= 0.4) {
            reasons.add('Similar brand');
          }
          break;
        case 'color':
          if (entry.value >= 0.7) {
            reasons.add('Same color');
          } else if (entry.value >= 0.4) {
            reasons.add('Similar color');
          }
          break;
        case 'model':
          if (entry.value >= 0.7) {
            reasons.add('Same model');
          } else if (entry.value >= 0.4) {
            reasons.add('Similar model');
          }
          break;
        case 'material':
          if (entry.value >= 0.7) {
            reasons.add('Same material');
          } else if (entry.value >= 0.4) {
            reasons.add('Similar material');
          }
          break;
      }
    }

    if (reasons.isEmpty) reasons.add('Partial similarity across fields');
    return reasons.join(' · ');
  }
}

// ---------------------------------------------------------------------------
// Campus Location Normalizer
// ---------------------------------------------------------------------------

class LocationNormalizer {
  LocationNormalizer._();

  /// Canonical name → set of known aliases (lowercase).
  static final Map<String, Set<String>> _aliasGroups = {
    'library': {
      'library', 'central library', 'main library', 'campus library',
      'university library', 'reading room', 'reference library',
    },
    'cse block': {
      'cse block', 'computer science block', 'cs block',
      'cse building', 'computer science building', 'cs building',
    },
    'main gate': {
      'main gate', 'entrance gate', 'front gate', 'primary gate',
      'main entrance', 'campus entrance',
    },
    'admin block': {
      'admin block', 'administration block', 'admin building',
      'administration building', 'office block',
    },
    'canteen': {
      'canteen', 'cafeteria', 'food court', 'mess', 'mess hall',
      'campus canteen', 'college canteen',
    },
    'parking': {
      'parking', 'parking lot', 'parking area', 'parking zone',
      'car park', 'bike parking', 'vehicle parking',
    },
    'auditorium': {
      'auditorium', 'hall', 'main hall', 'lecture hall',
      'seminar hall', 'event hall', 'conference hall',
    },
    'lab': {
      'lab', 'laboratory', 'computer lab', 'physics lab',
      'chemistry lab', 'electronics lab', 'science lab',
      'bio lab', 'mechanical lab', 'language lab',
    },
    'hostel': {
      'hostel', 'hostel block', 'boys hostel', 'girls hostel',
      'residence hall', 'dormitory', 'dorm', 'accommodation',
    },
    'sports complex': {
      'sports complex', 'gym', 'gymnasium', 'sports ground',
      'playground', 'sports arena', 'stadium',
    },
    'medical center': {
      'medical center', 'health center', 'clinic', 'dispensary',
      'campus clinic', 'first aid center', 'hospital',
    },
    'bank': {
      'bank', 'atm', 'atm center', 'banking center',
    },
    'post office': {
      'post office', 'mail room', 'courier center',
    },
    'department': {
      'department', 'dept', 'dept block',
    },
    'campus ground': {
      'campus ground', 'campus', 'college ground', 'open ground',
      'central ground', 'quadrangle', 'quad',
    },
    'classroom': {
      'classroom', 'class room', 'lecture room', 'room',
    },
    'toilet': {
      'toilet', 'washroom', 'restroom', 'bathroom', 'loo',
    },
    'security': {
      'security', 'security office', 'security cabin', 'guard room',
    },
    'chapel': {
      'chapel', 'prayer hall', 'temple', 'mosque', 'church',
    },
  };

  static Map<String, String>? _reverseLookup;

  static Map<String, String> get reverseLookup {
    _reverseLookup ??= _buildReverseLookup();
    return _reverseLookup!;
  }

  static Map<String, String> _buildReverseLookup() {
    final map = <String, String>{};
    for (final entry in _aliasGroups.entries) {
      for (final alias in entry.value) {
        map[alias] = entry.key;
      }
    }
    return map;
  }

  /// Normalize a location string to its canonical campus name.
  static String normalize(String location) {
    final lower = location.toLowerCase().trim();
    if (lower.isEmpty) return lower;

    // Direct lookup
    final direct = reverseLookup[lower];
    if (direct != null) return direct;

    // Check if any canonical name is a substring of the input
    for (final canonical in _aliasGroups.keys) {
      if (lower.contains(canonical)) return canonical;
    }

    // Check if any alias is a substring of the input
    for (final entry in _aliasGroups.entries) {
      for (final alias in entry.value) {
        if (lower.contains(alias)) return entry.key;
      }
    }

    // Check word-level overlap (e.g. "Near CSE Block 3" → "cse block")
    final words = lower.split(RegExp(r'\s+'));
    for (final canonical in _aliasGroups.keys) {
      final canonicalWords = canonical.split(' ');
      int matched = 0;
      for (final cw in canonicalWords) {
        if (words.any((w) => w == cw || w.contains(cw) || cw.contains(w))) {
          matched++;
        }
      }
      if (matched == canonicalWords.length) return canonical;
    }

    return lower;
  }

  /// Add a custom alias group at runtime.
  static void addGroup(String canonical, List<String> aliases) {
    final key = canonical.toLowerCase().trim();
    _aliasGroups[key] = {key, ...aliases.map((a) => a.toLowerCase().trim())};
    _reverseLookup = null; // invalidate cache
  }
}

// ---------------------------------------------------------------------------
// Score History
// ---------------------------------------------------------------------------

class ScoreHistoryEntry {
  final double oldScore;
  final double newScore;
  final DateTime timestamp;
  final String reason;
  final Map<String, double> oldFactors;
  final Map<String, double> newFactors;

  const ScoreHistoryEntry({
    required this.oldScore,
    required this.newScore,
    required this.timestamp,
    required this.reason,
    this.oldFactors = const {},
    this.newFactors = const {},
  });

  double get delta => newScore - oldScore;

  @override
  String toString() =>
      '${oldScore.round()}% → ${newScore.round()}% ($reason) @ $timestamp';
}

class MatchScoreHistory {
  final String lostItemId;
  final String foundItemId;
  final List<ScoreHistoryEntry> entries;

  MatchScoreHistory({
    required this.lostItemId,
    required this.foundItemId,
    List<ScoreHistoryEntry>? entries,
  }) : entries = entries ?? [];

  String get pairKey => '${lostItemId}_$foundItemId';

  double get firstScore => entries.isNotEmpty ? entries.first.newScore : 0;
  double get latestScore => entries.isNotEmpty ? entries.last.newScore : 0;
  double get peakScore => entries.isEmpty
      ? 0
      : entries.map((e) => e.newScore).reduce((a, b) => a > b ? a : b);
  double get lowestScore => entries.isEmpty
      ? 0
      : entries.map((e) => e.newScore).reduce((a, b) => a < b ? a : b);
  int get changeCount => entries.isNotEmpty ? entries.length - 1 : 0;

  double get totalDelta =>
      entries.length >= 2 ? entries.last.newScore - entries.first.newScore : 0;

  ScoreHistoryEntry? get lastChange =>
      entries.length >= 2 ? entries.last : null;

  @override
  String toString() =>
      'MatchScoreHistory($pairKey, ${entries.length} entries, '
      'latest=${latestScore.round()}%, peak=${peakScore.round()}%)';
}

// ---------------------------------------------------------------------------
// Score History Store
// ---------------------------------------------------------------------------

class ScoreHistoryStore {
  final Map<String, MatchScoreHistory> _store = {};

  MatchScoreHistory? getHistory(String lostItemId, String foundItemId) {
    return _store['${lostItemId}_$foundItemId'];
  }

  List<MatchScoreHistory> getAllHistories() => _store.values.toList();

  List<MatchScoreHistory> getChangedPairs() =>
      _store.values.where((h) => h.changeCount > 0).toList();

  List<MatchScoreHistory> getImprovedPairs() =>
      _store.values.where((h) => h.totalDelta > 0).toList();

  List<MatchScoreHistory> getDeclinedPairs() =>
      _store.values.where((h) => h.totalDelta < 0).toList();

  List<ScoreHistoryEntry> getAllEntries() =>
      _store.values.expand((h) => h.entries).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  Map<String, dynamic> getSummary() {
    final histories = _store.values.toList();
    final totalPairs = histories.length;
    final changedPairs = getChangedPairs().length;
    final improvedPairs = getImprovedPairs().length;
    final declinedPairs = getDeclinedPairs().length;
    final totalEntries = getAllEntries().length;

    final allScores = histories.map((h) => h.latestScore).toList();
    final avgScore =
        allScores.isEmpty ? 0.0 : allScores.reduce((a, b) => a + b) / allScores.length;

    return {
      'totalPairs': totalPairs,
      'changedPairs': changedPairs,
      'improvedPairs': improvedPairs,
      'declinedPairs': declinedPairs,
      'totalEntries': totalEntries,
      'averageScore': double.parse(avgScore.toStringAsFixed(1)),
    };
  }

  void record({
    required String lostItemId,
    required String foundItemId,
    required double newScore,
    required String reason,
    Map<String, double> oldFactors = const {},
    Map<String, double> newFactors = const {},
  }) {
    final key = '${lostItemId}_$foundItemId';
    final history = _store.putIfAbsent(
      key,
      () => MatchScoreHistory(lostItemId: lostItemId, foundItemId: foundItemId),
    );

    final oldScore = history.latestScore;

    history.entries.add(ScoreHistoryEntry(
      oldScore: oldScore,
      newScore: newScore,
      timestamp: DateTime.now(),
      reason: reason,
      oldFactors: oldFactors,
      newFactors: newFactors,
    ));
  }

  void clear() => _store.clear();

  int get length => _store.length;
}

// ---------------------------------------------------------------------------
// MatchingService
// ---------------------------------------------------------------------------

class MatchingService {
  final ScoreHistoryStore scoreHistory = ScoreHistoryStore();

  // -- Public API ---------------------------------------------------------

  List<MatchResult> findMatches({
    required List<ItemModel> lostItems,
    required List<ItemModel> foundItems,
    int maxResults = 5,
  }) {
    final results = <MatchResult>[];
    final seenPairs = <String>{};

    // Deduplicate input by ID
    final lostById = <String, ItemModel>{};
    for (final item in lostItems) {
      lostById.putIfAbsent(item.id, () => item);
    }
    final foundById = <String, ItemModel>{};
    for (final item in foundItems) {
      if (item.status == 'found') {
        foundById.putIfAbsent(item.id, () => item);
      }
    }

    // Pre-index found items by normalized location for fast lookup
    final foundByLocation = <String, List<ItemModel>>{};
    for (final f in foundById.values) {
      final loc = LocationNormalizer.normalize(f.location);
      foundByLocation.putIfAbsent(loc, () => []).add(f);
    }

    for (final lost in lostById.values) {
      final candidates = _prefilterFound(
        lost,
        foundByLocation,
      );

      for (final found in candidates) {
        final pairKey = '${lost.id}_${found.id}';
        if (!seenPairs.add(pairKey)) continue;
        if (!_canCompare(lost, found)) continue;

        final profile = CategoryProfiles.resolve(lost.category);
        final factors = _calculateFactors(lost, found, profile);
        final score = _calculateTotalScore(factors, profile);

        if (score >= 30) {
          final evidence = _generateEvidence(factors, lost, found);
          final previous = scoreHistory.getHistory(lost.id, found.id);
          final previousFactors = previous?.entries.isNotEmpty == true
              ? previous!.entries.last.newFactors
              : <String, double>{};

          final reason = _detectChangeReason(previousFactors, factors, score, previous?.latestScore ?? 0);

          scoreHistory.record(
            lostItemId: lost.id,
            foundItemId: found.id,
            newScore: score,
            reason: reason,
            oldFactors: previousFactors,
            newFactors: factors,
          );

          final breakdown = _buildBreakdown(factors, profile, lost, found);

          results.add(MatchResult(
            lostItem: lost,
            foundItem: found,
            score: score,
            factors: factors,
            profileLabel: profile.label,
            evidence: evidence,
            breakdown: breakdown,
          ));
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).toList();
  }

  List<MatchResult> findMatchesForItem({
    required ItemModel item,
    required List<ItemModel> oppositeItems,
    int maxResults = 5,
    double minScore = 25,
  }) {
    final results = <MatchResult>[];

    for (final other in oppositeItems) {
      if (other.status != 'found') continue;
      if (other.createdByUid == item.createdByUid) continue;
      if (!_canCompare(item, other)) continue;

      final profile = CategoryProfiles.resolve(item.category);
      final factors = item.type == 'lost'
          ? _calculateFactors(item, other, profile)
          : _calculateFactors(other, item, profile);
      final score = _calculateTotalScore(factors, profile);

      if (score >= minScore) {
        final evidence = _generateEvidence(factors, item, other);
        final breakdown = _buildBreakdown(factors, profile, item.type == 'lost' ? item : other, item.type == 'found' ? item : other);
        results.add(MatchResult(
          lostItem: item.type == 'lost' ? item : other,
          foundItem: item.type == 'found' ? item : other,
          score: score,
          factors: factors,
          profileLabel: profile.label,
          evidence: evidence,
          breakdown: breakdown,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).toList();
  }

  // -- Pre-filtering -------------------------------------------------------

  bool _canCompare(ItemModel lost, ItemModel found) {
    // Category must match (exact or synonym)
    if (!_categoriesOverlap(lost.category, found.category)) return false;

    // Date within 30 days
    if (!_datesWithinRange(lost.itemDate ?? lost.createdAt, found.itemDate ?? found.createdAt, 30)) return false;

    return true;
  }

  bool _categoriesOverlap(String cat1, String cat2) {
    if (cat1.isEmpty || cat2.isEmpty) return true;
    if (cat1.toLowerCase() == cat2.toLowerCase()) return true;

    const synonyms = {
      'electronics': ['phone', 'mobile', 'laptop', 'tablet', 'earbuds', 'headphones', 'watch', 'charger', 'camera'],
      'bags': ['backpack', 'handbag', 'purse', 'laptop bag'],
      'clothing': ['jacket', 'hoodie', 'shirt', 'pants', 'shoes', 'cap', 'hat'],
      'accessories': ['glasses', 'sunglasses', 'watch', 'ring', 'necklace', 'bracelet'],
      'documents': ['id', 'card', 'passport', 'license', 'notebook'],
      'keys': ['key', 'keychain', 'car key'],
      'id cards': ['id', 'student id', 'library card', 'badge'],
      'books': ['textbook', 'notebook', 'diary', 'journal'],
    };

    final c1 = cat1.toLowerCase();
    final c2 = cat2.toLowerCase();

    for (final entry in synonyms.entries) {
      final cats = [entry.key, ...entry.value];
      if (cats.contains(c1) && cats.contains(c2)) return true;
    }

    return false;
  }

  bool _datesWithinRange(DateTime? d1, DateTime? d2, int maxDays) {
    if (d1 == null || d2 == null) return true;
    return d1.difference(d2).inDays.abs() <= maxDays;
  }

  List<ItemModel> _prefilterFound(
    ItemModel lost,
    Map<String, List<ItemModel>> foundByLocation,
  ) {
    final lostCat = lost.category.toLowerCase();
    final lostLoc = LocationNormalizer.normalize(lost.location);
    final seenIds = <String>{};
    final candidates = <ItemModel>[];

    void addUnique(List<ItemModel> items) {
      for (final item in items) {
        if (seenIds.add(item.id)) {
          candidates.add(item);
        }
      }
    }

    // 1. Same location bucket
    if (foundByLocation.containsKey(lostLoc)) {
      addUnique(foundByLocation[lostLoc]!);
    }

    // 2. Also check nearby location buckets (word overlap)
    if (candidates.isEmpty) {
      final lostWords = _tokenize(lostLoc);
      for (final entry in foundByLocation.entries) {
        final locWords = _tokenize(entry.key);
        for (final lw in lostWords) {
          for (final fw in locWords) {
            if (lw == fw || lw.contains(fw) || fw.contains(lw)) {
              addUnique(entry.value);
            }
          }
        }
      }
    }

    // 3. If no location-based candidates, fall back to all found items
    if (candidates.isEmpty) {
      for (final entry in foundByLocation.values) {
        addUnique(entry);
      }
    }

    // 4. Category pre-filter
    return candidates.where((f) {
      if (f.status != 'found') return false;
      if (lostCat.isEmpty) return true;
      return _categoriesOverlap(lostCat, f.category);
    }).toList();
  }

  // -- Score breakdown generation ------------------------------------------

  ScoreBreakdown _buildBreakdown(
    Map<String, double> factors,
    MatchWeightProfile profile,
    ItemModel lost,
    ItemModel found,
  ) {
    final entries = <FactorBreakdown>[];

    for (final factorName in factors.keys) {
      final factorScore = factors[factorName]!;
      final weight = profile[factorName];
      final maxPoints = weight;
      final earnedPoints = factorScore * weight;
      final percentage = (factorScore * 100).round();
      final reason = _factorReason(factorName, factorScore, lost, found);

      entries.add(FactorBreakdown(
        factor: factorName,
        weight: weight,
        factorScore: factorScore,
        maxPoints: maxPoints,
        earnedPoints: earnedPoints,
        percentage: percentage,
        reason: reason,
      ));
    }

    return ScoreBreakdown(
      totalScore: _calculateTotalScore(factors, profile),
      profileLabel: profile.label,
      factors: entries,
    );
  }

  String _factorReason(
    String factor,
    double score,
    ItemModel lost,
    ItemModel found,
  ) {
    switch (factor) {
      case 'title':
        if (score >= 0.9) return 'Exact title match';
        if (score >= 0.7) return 'Very similar title';
        if (score >= 0.5) return 'Similar title words';
        if (score >= 0.3) return 'Some title overlap';
        if (score > 0) return 'Minimal title overlap';
        return 'No title match';

      case 'category':
        if (score >= 0.9) return 'Exact category match';
        if (score >= 0.7) return 'Same category group';
        if (score >= 0.4) return 'Related category';
        return 'Different categories';

      case 'description':
        if (score >= 0.7) return 'High keyword overlap';
        if (score >= 0.5) return 'Moderate keyword overlap';
        if (score >= 0.3) return 'Some keyword overlap';
        if (score > 0) return 'Minimal keyword overlap';
        return 'No keyword match';

      case 'location':
        if (score >= 0.9) return 'Exact location match';
        if (score >= 0.7) return 'Same general area';
        if (score >= 0.4) return 'Nearby location';
        if (score > 0) return 'Partially overlapping area';
        return 'Different locations';

      case 'date':
        if (score >= 0.9) return 'Same date';
        if (score >= 0.7) return 'Within 3 days';
        if (score >= 0.5) return 'Within 1 week';
        if (score >= 0.3) return 'Within 2 weeks';
        return 'Dates far apart';

      case 'brand':
        if (score >= 0.9) return 'Exact brand match';
        if (score >= 0.7) return 'Similar brand name';
        return 'Brand not detected';

      case 'color':
        if (score >= 0.9) return 'Exact color match';
        if (score >= 0.7) return 'Same color family';
        return 'Color not detected';

      case 'model':
        if (score >= 0.9) return 'Exact model match';
        if (score >= 0.6) return 'Partial model match';
        return 'Model not detected';

      case 'material':
        if (score >= 0.9) return 'Exact material match';
        if (score >= 0.7) return 'Same material type';
        return 'Material not detected';

      default:
        return score > 0 ? 'Partial match' : 'No match';
    }
  }

  // -- Evidence generation ------------------------------------------------

  EvidenceResult _generateEvidence(
    Map<String, double> factors,
    ItemModel lost,
    ItemModel found,
  ) {
    final matching = <ReasonItem>[];
    final conflicting = <ReasonItem>[];

    // Title
    final titleScore = factors['title'] ?? 0;
    if (titleScore >= 0.7) {
      matching.add(ReasonItem(
        attribute: 'title',
        isMatch: true,
        detail: 'Same item name: "${lost.title}"',
      ));
    } else if (titleScore >= 0.4) {
      matching.add(ReasonItem(
        attribute: 'title',
        isMatch: true,
        detail: 'Similar item name',
      ));
    } else if (titleScore < 0.2) {
      conflicting.add(ReasonItem(
        attribute: 'title',
        isMatch: false,
        detail: 'Different item names',
      ));
    }

    // Brand
    final brandScore = factors['brand'] ?? 0;
    if (brandScore >= 0.7) {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      final brand = lostAttrs.brands.intersection(foundAttrs.brands).first;
      matching.add(ReasonItem(
        attribute: 'brand',
        isMatch: true,
        detail: 'Same brand: $brand',
      ));
    } else if (brandScore > 0) {
      matching.add(ReasonItem(
        attribute: 'brand',
        isMatch: true,
        detail: 'Similar brand detected',
      ));
    } else {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      if (lostAttrs.brands.isNotEmpty && foundAttrs.brands.isNotEmpty) {
        conflicting.add(ReasonItem(
          attribute: 'brand',
          isMatch: false,
          detail: 'Different brands',
        ));
      }
    }

    // Color
    final colorScore = factors['color'] ?? 0;
    if (colorScore >= 0.7) {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      final color = lostAttrs.colors.intersection(foundAttrs.colors).first;
      matching.add(ReasonItem(
        attribute: 'color',
        isMatch: true,
        detail: 'Same color: $color',
      ));
    } else if (colorScore > 0) {
      matching.add(ReasonItem(
        attribute: 'color',
        isMatch: true,
        detail: 'Similar color detected',
      ));
    } else {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      if (lostAttrs.colors.isNotEmpty && foundAttrs.colors.isNotEmpty) {
        conflicting.add(ReasonItem(
          attribute: 'color',
          isMatch: false,
          detail: 'Different colors',
        ));
      }
    }

    // Location
    final locationScore = factors['location'] ?? 0;
    final n1 = LocationNormalizer.normalize(lost.location);
    if (locationScore >= 0.9) {
      matching.add(ReasonItem(
        attribute: 'location',
        isMatch: true,
        detail: 'Same location: $n1',
      ));
    } else if (locationScore >= 0.5) {
      matching.add(ReasonItem(
        attribute: 'location',
        isMatch: true,
        detail: 'Nearby location',
      ));
    } else if (locationScore < 0.2 && lost.location.isNotEmpty && found.location.isNotEmpty) {
      conflicting.add(ReasonItem(
        attribute: 'location',
        isMatch: false,
        detail: 'Different locations',
      ));
    }

    // Date
    final dateScore = factors['date'] ?? 0;
    if (dateScore >= 0.9) {
      matching.add(ReasonItem(
        attribute: 'date',
        isMatch: true,
        detail: 'Same date reported',
      ));
    } else if (dateScore >= 0.5) {
      matching.add(ReasonItem(
        attribute: 'date',
        isMatch: true,
        detail: 'Date within range',
      ));
    } else if (dateScore < 0.3) {
      conflicting.add(ReasonItem(
        attribute: 'date',
        isMatch: false,
        detail: 'Dates differ significantly',
      ));
    }

    // Material
    final materialScore = factors['material'] ?? 0;
    if (materialScore >= 0.7) {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      final mat = lostAttrs.materials.intersection(foundAttrs.materials).first;
      matching.add(ReasonItem(
        attribute: 'material',
        isMatch: true,
        detail: 'Same material: $mat',
      ));
    } else if (materialScore > 0) {
      matching.add(ReasonItem(
        attribute: 'material',
        isMatch: true,
        detail: 'Similar material detected',
      ));
    }

    // Model
    final modelScore = factors['model'] ?? 0;
    if (modelScore >= 0.7) {
      final lostAttrs = AttributeExtractor.extract(lost);
      final foundAttrs = AttributeExtractor.extract(found);
      final model = lostAttrs.models.intersection(foundAttrs.models).first;
      matching.add(ReasonItem(
        attribute: 'model',
        isMatch: true,
        detail: 'Same model: $model',
      ));
    } else if (modelScore > 0) {
      matching.add(ReasonItem(
        attribute: 'model',
        isMatch: true,
        detail: 'Similar model detected',
      ));
    }

    // Calculate confidence
    final matchCount = matching.length;
    final conflictCount = conflicting.length;
    final totalEvidence = matchCount + conflictCount;

    double confidence;
    if (totalEvidence == 0) {
      confidence = factors.values.fold<double>(0, (a, b) => a + b) / factors.length;
    } else {
      confidence = matchCount / totalEvidence;
    }

    // Apply score modifier
    confidence = (confidence * (factors.values.fold<double>(0, (a, b) => a + b) / factors.length)).clamp(0.0, 1.0);

    // Determine evidence level
    EvidenceLevel level;
    if (confidence >= 0.7 && matchCount >= 3) {
      level = EvidenceLevel.strong;
    } else if (confidence >= 0.4 && matchCount >= 2) {
      level = EvidenceLevel.moderate;
    } else {
      level = EvidenceLevel.weak;
    }

    return EvidenceResult(
      confidence: confidence,
      evidenceLevel: level,
      matchingReasons: matching,
      conflictingReasons: conflicting,
    );
  }

  // -- Factor calculation -------------------------------------------------

  Map<String, double> _calculateFactors(
    ItemModel lost,
    ItemModel found,
    MatchWeightProfile profile,
  ) {
    final lostAttrs = AttributeExtractor.extract(lost);
    final foundAttrs = AttributeExtractor.extract(found);

    final factors = <String, double>{
      'title': _compareTitle(lost.title, found.title, lostAttrs, foundAttrs),
      'category': _compareCategory(lost.category, found.category, lostAttrs, foundAttrs),
      'description': _compareDescription(lostAttrs.keywords, foundAttrs.keywords, lostAttrs, foundAttrs),
      'location': _calculateLocationMatch(lost.location, found.location),
      'date': _calculateDateProximity(lost.itemDate, found.itemDate),
      'brand': _compareBrand(lostAttrs.brands, foundAttrs.brands),
      'color': _compareColor(lostAttrs.colors, foundAttrs.colors),
      'model': _compareModel(lostAttrs.models, foundAttrs.models),
      'material': _compareMaterial(lostAttrs.materials, foundAttrs.materials),
    };

    return factors;
  }

  double _calculateTotalScore(
    Map<String, double> factors,
    MatchWeightProfile profile,
  ) {
    double total = 0;
    for (final entry in factors.entries) {
      final weight = profile[entry.key];
      total += entry.value * weight;
    }
    return (total * 100).clamp(0, 100);
  }

  // -- Attribute comparison ------------------------------------------------

  double _compareBrand(Set<String> brands1, Set<String> brands2) {
    if (brands1.isEmpty || brands2.isEmpty) return 0;
    for (final b1 in brands1) {
      for (final b2 in brands2) {
        if (b1 == b2) return 1.0;
        if (b1.contains(b2) || b2.contains(b1)) return 0.7;
      }
    }
    return 0;
  }

  double _compareColor(Set<String> colors1, Set<String> colors2) {
    if (colors1.isEmpty || colors2.isEmpty) return 0;
    for (final c1 in colors1) {
      for (final c2 in colors2) {
        if (c1 == c2) return 1.0;
      }
    }
    return 0;
  }

  double _compareModel(Set<String> models1, Set<String> models2) {
    if (models1.isEmpty || models2.isEmpty) return 0;
    for (final m1 in models1) {
      for (final m2 in models2) {
        if (m1 == m2) return 1.0;
        if (m1.contains(m2) || m2.contains(m1)) return 0.6;
      }
    }
    return 0;
  }

  double _compareMaterial(Set<String> mat1, Set<String> mat2) {
    if (mat1.isEmpty || mat2.isEmpty) return 0;
    for (final m1 in mat1) {
      for (final m2 in mat2) {
        if (m1 == m2) return 1.0;
      }
    }
    return 0;
  }

  double _compareTitle(
    String title1,
    String title2,
    ExtractedAttributes a1,
    ExtractedAttributes a2,
  ) {
    // Direct keyword overlap from title words
    final words1 = _tokenize(title1);
    final words2 = _tokenize(title2);
    if (words1.isEmpty && words2.isEmpty) return 0;

    int matches = 0;
    for (final w1 in words1) {
      for (final w2 in words2) {
        if (w1 == w2 || w1.contains(w2) || w2.contains(w1)) {
          matches++;
          break;
        }
      }
    }

    final wordScore = words1.isEmpty || words2.isEmpty
        ? 0.0
        : matches / (words1.length + words2.length - matches);

    // Attribute boost: matching brand/model in title boosts score
    double boost = 0;
    if (a1.brands.intersection(a2.brands).isNotEmpty) boost += 0.2;
    if (a1.models.intersection(a2.models).isNotEmpty) boost += 0.1;

    return (wordScore + boost).clamp(0.0, 1.0);
  }

  double _compareCategory(
    String cat1,
    String cat2,
    ExtractedAttributes a1,
    ExtractedAttributes a2,
  ) {
    if (cat1.isEmpty || cat2.isEmpty) return 0;
    if (cat1.toLowerCase() == cat2.toLowerCase()) return 1.0;

    final synonyms = {
      'electronics': ['phone', 'mobile', 'laptop', 'tablet', 'earbuds', 'headphones', 'watch', 'charger', 'camera'],
      'bags': ['backpack', 'handbag', 'purse', 'laptop bag'],
      'clothing': ['jacket', 'hoodie', 'shirt', 'pants', 'shoes', 'cap', 'hat'],
      'accessories': ['glasses', 'sunglasses', 'watch', 'ring', 'necklace', 'bracelet'],
      'documents': ['id', 'card', 'passport', 'license', 'notebook'],
      'keys': ['key', 'keychain', 'car key'],
      'id cards': ['id', 'student id', 'library card', 'badge'],
      'books': ['textbook', 'notebook', 'diary', 'journal'],
    };

    final c1 = cat1.toLowerCase();
    final c2 = cat2.toLowerCase();

    for (final entry in synonyms.entries) {
      final cats = [entry.key, ...entry.value];
      if (cats.contains(c1) && cats.contains(c2)) return 0.7;
    }

    return 0.1;
  }

  double _compareDescription(
    Set<String> kw1,
    Set<String> kw2,
    ExtractedAttributes a1,
    ExtractedAttributes a2,
  ) {
    if (kw1.isEmpty && kw2.isEmpty) return 0;

    // Jaccard on keyword sets
    final allKw = kw1.union(kw2);
    final intersection = kw1.intersection(kw2).length;
    final union = allKw.length;
    if (union == 0) return 0;
    final jaccard = intersection / union;

    // Attribute boost
    double boost = 0;
    if (a1.materials.intersection(a2.materials).isNotEmpty) boost += 0.1;
    if (a1.colors.intersection(a2.colors).isNotEmpty) boost += 0.05;

    return (jaccard + boost).clamp(0.0, 1.0);
  }

  double _calculateLocationMatch(String loc1, String loc2) {
    if (loc1.isEmpty || loc2.isEmpty) return 0;

    final n1 = LocationNormalizer.normalize(loc1);
    final n2 = LocationNormalizer.normalize(loc2);

    // Exact normalized match
    if (n1 == n2) return 1.0;

    // One contains the other after normalization
    if (n1.contains(n2) || n2.contains(n1)) return 0.9;

    // Word-level overlap on normalized forms
    final words1 = _tokenize(n1);
    final words2 = _tokenize(n2);

    if (words1.isEmpty || words2.isEmpty) return 0;

    int matches = 0;
    for (final w1 in words1) {
      for (final w2 in words2) {
        if (w1 == w2 || w1.contains(w2) || w2.contains(w1)) {
          matches++;
          break;
        }
      }
    }

    return matches > 0
        ? (matches / max(words1.length, words2.length)).clamp(0.0, 1.0)
        : 0;
  }

  double _calculateDateProximity(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return 0.5;

    final diff = (date1.difference(date2)).inDays.abs();

    if (diff == 0) return 1.0;
    if (diff == 1) return 0.9;
    if (diff <= 3) return 0.7;
    if (diff <= 7) return 0.5;
    if (diff <= 14) return 0.3;
    return 0.1;
  }

  // -- Change detection ---------------------------------------------------

  String _detectChangeReason(
    Map<String, double> oldFactors,
    Map<String, double> newFactors,
    double newScore,
    double oldScore,
  ) {
    if (oldScore == 0) return 'Initial match detected';

    final delta = (newScore - oldScore).abs();
    final direction = newScore > oldScore ? 'improved' : 'declined';

    if (delta < 1) return 'Minor score fluctuation ($direction)';

    // Find which factor changed the most
    String? biggestChangeAttr;
    double biggestChange = 0;
    for (final key in newFactors.keys) {
      final oldVal = oldFactors[key] ?? 0;
      final newVal = newFactors[key] ?? 0;
      final diff = (newVal - oldVal).abs();
      if (diff > biggestChange) {
        biggestChange = diff;
        biggestChangeAttr = key;
      }
    }

    if (biggestChangeAttr != null && biggestChange > 0.2) {
      return 'Score $direction: $biggestChangeAttr changed '
          '(${(oldFactors[biggestChangeAttr] ?? 0 * 100).round()}% → '
          '${(newFactors[biggestChangeAttr]! * 100).round()}%)';
    }

    if (delta >= 20) return 'Significant score $direction ($direction by ${delta.round()}%)';
    if (delta >= 10) return 'Moderate score $direction ($direction by ${delta.round()}%)';
    return 'Score $direction by ${delta.round()}%';
  }

  // -- Text utilities -----------------------------------------------------

  static const _stopWords = {
    'the', 'a', 'an', 'is', 'it', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'and', 'or', 'but', 'not', 'this', 'that',
    'was', 'are', 'be', 'has', 'had', 'have', 'from', 'i', 'my',
    'me', 'we', 'our', 'you', 'your', 'he', 'she', 'they', 'them',
    'its', 'his', 'her', 'will', 'can', 'may', 'shall', 'do', 'did',
    'if', 'so', 'no', 'yes', 'very', 'just', 'also', 'than', 'too',
    'about', 'been', 'being', 'into', 'over', 'such', 'after', 'before',
    'between', 'under', 'again', 'there', 'here', 'when', 'where',
    'how', 'all', 'each', 'every', 'both', 'few', 'more', 'most',
    'other', 'some', 'any', 'only', 'own', 'same', 'then', 'now',
    'once', 'twice', 'what', 'which', 'who', 'whom',
  };

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !_stopWords.contains(w))
        .toList();
  }
}
