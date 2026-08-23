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

    test('maps a discharging forecast as a hard no-row, with its range', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {
          'discharge_classification': kDischargeExpected,
          'discharge_statement_raw':
              'It is expected that a discharge ranging between 55 and '
              '170m3/s will be necessary at Parteen Weir over the next 5 '
              'days based on current weather forecast.',
          'expected_discharge_min_m3s': 55.0,
          'expected_discharge_max_m3s': 170.0,
        },
      });
      expect(w, isNotNull);
      expect(w!.classification, kDischargeExpected);
      expect(w.isClear, isFalse);
      expect(w.isDischarging, isTrue);
      expect(w.expectedRangeM3s, '55–170');
    });

    test('a discharging forecast without a range still blocks rowing', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {
          'discharge_classification': kDischargeExpected,
          'discharge_statement_raw': 'a discharge will be necessary',
        },
      });
      expect(w!.isDischarging, isTrue);
      expect(w.isClear, isFalse);
      expect(w.expectedRangeM3s, isNull);
    });

    test('an unparsed forecast is neither clear nor discharging', () {
      final w = liveWaterReleaseFromDoc({
        'parteen_forecast': {
          'discharge_classification': kUnparsed,
          'discharge_statement_raw': 'some future wording never seen before',
        },
      });
      expect(w!.isClear, isFalse);
      expect(w.isDischarging, isFalse);
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
