import 'package:flutter_test/flutter_test.dart';

import 'package:find_it/core/services/matching_service.dart';
import 'package:find_it/domain/models/item_model.dart';

void main() {
  late MatchingService service;

  setUp(() {
    service = MatchingService();
  });

  group('MatchingService', () {
    group('findMatches', () {
      test('returns empty when no lost items', () {
        final results = service.findMatches(
          lostItems: [],
          foundItems: [_foundItem('Phone')],
        );
        expect(results, isEmpty);
      });

      test('returns empty when no found items', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Phone')],
          foundItems: [],
        );
        expect(results, isEmpty);
      });

      test('finds exact title match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Blue Backpack')],
          foundItems: [_foundItem('Blue Backpack')],
        );
        expect(results.length, 1);
        expect(results.first.score, greaterThan(50));
        expect(results.first.lostItem.title, 'Blue Backpack');
        expect(results.first.foundItem.title, 'Blue Backpack');
      });

      test('finds similar title match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('iPhone 15 Pro Max')],
          foundItems: [_foundItem('iPhone 15 Pro Max 256GB')],
        );
        expect(results.length, 1);
        expect(results.first.score, greaterThan(30));
      });

      test('finds category synonym match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Samsung Phone', category: 'Electronics')],
          foundItems: [_foundItem('Samsung Phone', category: 'Phone')],
        );
        expect(results.length, 1);
        expect(results.first.score, greaterThan(30));
      });

      test('finds same location match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Keys', location: 'Library')],
          foundItems: [_foundItem('Keys', location: 'Library')],
        );
        expect(results.length, 1);
        expect(results.first.factors['location'], 1.0);
      });

      test('finds nearby location match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Keys', location: 'Main Library')],
          foundItems: [_foundItem('Keys', location: 'Library Entrance')],
        );
        expect(results.length, 1);
        expect(results.first.factors['location'], greaterThan(0));
      });

      test('finds same date match', () {
        final now = DateTime(2025, 6, 15);
        final results = service.findMatches(
          lostItems: [_lostItem('Phone', itemDate: now)],
          foundItems: [_foundItem('Phone', itemDate: now)],
        );
        expect(results.length, 1);
        expect(results.first.factors['date'], 1.0);
      });

      test('finds close date match', () {
        final now = DateTime(2025, 6, 15);
        final results = service.findMatches(
          lostItems: [_lostItem('Phone', itemDate: now)],
          foundItems: [_foundItem('Phone', itemDate: now.add(const Duration(days: 1)))],
        );
        expect(results.length, 1);
        expect(results.first.factors['date'], 0.9);
      });

      test('finds description match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Black Nike Backpack', desc: 'black nylon backpack with laptop sleeve')],
          foundItems: [_foundItem('Black Nike Backpack', desc: 'black nylon backpack found near gym')],
        );
        expect(results.length, 1);
        expect(results.first.factors['description'], greaterThan(0));
      });

      test('respects maxResults limit', () {
        final lost = [_lostItem('Phone')];
        final found = List.generate(10, (i) => _foundItem('Phone ${i + 1}'));

        final results = service.findMatches(
          lostItems: lost,
          foundItems: found,
          maxResults: 3,
        );
        expect(results.length, lessThanOrEqualTo(3));
      });

      test('scores are sorted descending', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Blue Backpack')],
          foundItems: [
            _foundItem('Blue Backpack'),
            _foundItem('Red Backpack'),
            _foundItem('Green Bag'),
          ],
        );

        for (int i = 0; i < results.length - 1; i++) {
          expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
        }
      });

      test('filters out items below 30 score threshold', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Completely unrelated item')],
          foundItems: [_foundItem('Totally different thing')],
        );
        // Score should be low enough to not match
        for (final result in results) {
          expect(result.score, greaterThanOrEqualTo(30));
        }
      });

      test('skips found items with non-found status', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Phone')],
          foundItems: [
            ItemModel(
              id: 'i1', title: 'Phone', category: 'Electronics',
              description: '', location: 'Library',
              contactNumber: '09123456789', type: 'found',
              status: 'claimed', createdBy: 'A', createdByUid: 'u1',
            ),
          ],
        );
        expect(results, isEmpty);
      });
    });

    group('findMatchesForItem', () {
      test('finds matches for a lost item', () {
        final lost = _lostItem('Phone');
        final results = service.findMatchesForItem(
          item: lost,
          oppositeItems: [_foundItem('Phone')],
        );
        expect(results.length, 1);
      });

      test('skips items from same user', () {
        final lost = _lostItem('Phone', uid: 'u1');
        final results = service.findMatchesForItem(
          item: lost,
          oppositeItems: [_foundItem('Phone', uid: 'u1')],
        );
        expect(results, isEmpty);
      });

      test('skips non-found items', () {
        final lost = _lostItem('Phone');
        final lostItem = ItemModel(
          id: 'i1', title: 'Phone', category: 'Electronics',
          description: '', location: 'Library',
          contactNumber: '09123456789', type: 'lost',
          status: 'lost', createdBy: 'A', createdByUid: 'u2',
        );
        final results = service.findMatchesForItem(
          item: lost,
          oppositeItems: [lostItem],
        );
        expect(results, isEmpty);
      });

      test('respects maxResults', () {
        final lost = _lostItem('Phone');
        final found = List.generate(10, (i) => _foundItem('Phone ${i + 1}'));

        final results = service.findMatchesForItem(
          item: lost,
          oppositeItems: found,
          maxResults: 2,
        );
        expect(results.length, lessThanOrEqualTo(2));
      });
    });

    group('MatchResult.explanation', () {
      test('generates explanation with high title match', () {
        final result = service.findMatches(
          lostItems: [_lostItem('Blue Backpack')],
          foundItems: [_foundItem('Blue Backpack')],
        );
        expect(result.isNotEmpty, isTrue);
        expect(result.first.explanation, isNotEmpty);
      });

      test('generates explanation with partial match', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Blue Backpack', location: 'Library')],
          foundItems: [_foundItem('Blue Backpack', location: 'Library')],
        );
        expect(results.isNotEmpty, isTrue);
        final explanation = results.first.explanation;
        expect(explanation, isA<String>());
        expect(explanation.isNotEmpty, isTrue);
      });

      test('returns fallback text for low matches', () {
        // Force low scores
        final result = MatchResult(
          lostItem: _lostItem('A'),
          foundItem: _foundItem('B'),
          score: 30,
          factors: {
            'title': 0.1,
            'category': 0.1,
            'description': 0.1,
            'location': 0.1,
            'date': 0.1,
          },
        );
        expect(result.explanation, 'Partial similarity across fields');
      });
    });

    group('_normalizedLevenshtein', () {
      test('identical strings return 1.0', () {
        final results = service.findMatches(
          lostItems: [_lostItem('same text')],
          foundItems: [_foundItem('same text')],
        );
        expect(results.first.factors['title'], greaterThan(0.9));
      });

      test('completely different strings return low score', () {
        final results = service.findMatches(
          lostItems: [_lostItem('aaa')],
          foundItems: [_foundItem('zzz')],
        );
        // Either no match at all, or score is low
        if (results.isNotEmpty) {
          expect(results.first.score, lessThan(80));
        }
      });
    });

    group('Edge cases', () {
      test('empty titles', () {
        final results = service.findMatches(
          lostItems: [_lostItem('')],
          foundItems: [_foundItem('')],
        );
        // Should not crash, score may be 0
        expect(results, isA<List<MatchResult>>());
      });

      test('empty descriptions', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Phone', desc: '')],
          foundItems: [_foundItem('Phone', desc: '')],
        );
        expect(results.length, 1);
      });

      test('null item dates', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Phone', itemDate: null)],
          foundItems: [_foundItem('Phone', itemDate: null)],
        );
        expect(results.length, 1);
        expect(results.first.factors['date'], 0.5);
      });

      test('empty locations', () {
        final results = service.findMatches(
          lostItems: [_lostItem('Phone', location: '')],
          foundItems: [_foundItem('Phone', location: '')],
        );
        expect(results.length, 1);
        expect(results.first.factors['location'], 0);
      });
    });
  });
}

ItemModel _lostItem(String title, {
  String category = 'Electronics',
  String desc = 'Test description',
  String location = 'Library',
  DateTime? itemDate,
  String uid = 'u_lost',
}) {
  return ItemModel(
    id: 'lost_${title.hashCode}',
    title: title,
    category: category,
    description: desc,
    location: location,
    contactNumber: '09123456789',
    type: 'lost',
    status: 'lost',
    createdBy: 'Lost User',
    createdByUid: uid,
    itemDate: itemDate,
  );
}

ItemModel _foundItem(String title, {
  String category = 'Electronics',
  String desc = 'Test description',
  String location = 'Library',
  DateTime? itemDate,
  String uid = 'u_found',
}) {
  return ItemModel(
    id: 'found_${title.hashCode}',
    title: title,
    category: category,
    description: desc,
    location: location,
    contactNumber: '09123456789',
    type: 'found',
    status: 'found',
    createdBy: 'Found User',
    createdByUid: uid,
    itemDate: itemDate,
  );
}
