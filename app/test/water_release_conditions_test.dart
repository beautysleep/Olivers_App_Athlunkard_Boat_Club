import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/water_release_conditions.dart';

void main() {
  group('liveWaterReleaseFromDoc', () {
    test('maps a clear (no discharge expected) forecast', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {
          'discharge_classification': kNoDischargeExpected,
          'discharge_statement_raw':
              'It is expected that no additional discharge will be '
              'necessary at Parteen Weir over the next 5 days.',
        },
      });
      expect(w, isNotNull);
      expect(w!.classification, kNoDischargeExpected);
      expect(w.isClear, isTrue);
      expect(w.statementRaw, contains('no additional discharge'));
    });

    test('maps an unparsed forecast as not clear', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {
          'discharge_classification': kUnparsed,
          'discharge_statement_raw': 'some future wording never seen before',
        },
      });
      expect(w, isNotNull);
      expect(w!.classification, kUnparsed);
      expect(w.isClear, isFalse);
    });

    test('null document returns null', () {
      expect(liveWaterReleaseFromDoc(null), isNull);
    });

    test('missing parteen_forecast section returns null', () {
      expect(liveWaterReleaseFromDoc({'source': 'esbhydro'}), isNull);
    });

    test('missing classification returns null (nothing usable)', () {
      expect(
        liveWaterReleaseFromDoc({
          'parteen_forecast': {'discharge_statement_raw': 'text'},
        }),
        isNull,
      );
    });

    test('missing raw statement defaults to empty string, not null', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {'discharge_classification': kNoDischargeExpected},
      });
      expect(w!.statementRaw, '');
    });
  });
}
