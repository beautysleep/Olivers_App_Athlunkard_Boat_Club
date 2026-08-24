import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/water_release_conditions.dart';

void main() {
  group('liveWaterReleaseFromDocument', () {
    test('maps a clear (no discharge expected) forecast', () {
      final w = liveWaterReleaseFromDocument({
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

    test('carries the ESB source URL through so the coach can verify it', () {
      final w = liveWaterReleaseFromDocument({
        'parteen_forecast': {
          'discharge_classification': kNoDischargeExpected,
          'source_url':
              'http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf',
        },
      });
      expect(w!.sourceUrl, contains('01-Shannon-Hydro-Forecast.pdf'));
    });

    test('a document with no source URL yields null, not a guessed one', () {
      final w = liveWaterReleaseFromDocument({
        'parteen_forecast': {
          'discharge_classification': kNoDischargeExpected,
        },
      });
      expect(w!.sourceUrl, isNull);
    });

    test('maps a discharging forecast as a hard no-row, with its range', () {
      final w = liveWaterReleaseFromDocument({
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
      final w = liveWaterReleaseFromDocument({
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
      final w = liveWaterReleaseFromDocument({
        'parteen_forecast': {
          'discharge_classification': kUnparsed,
          'discharge_statement_raw': 'some future wording never seen before',
        },
      });
      expect(w!.isClear, isFalse);
      expect(w.isDischarging, isFalse);
    });

    test('maps an unparsed forecast as not clear', () {
      final w = liveWaterReleaseFromDocument({
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
      expect(liveWaterReleaseFromDocument(null), isNull);
    });

    test('missing parteen_forecast section returns null', () {
      expect(liveWaterReleaseFromDocument({'source': 'esbhydro'}), isNull);
    });

    test('missing classification returns null (nothing usable)', () {
      expect(
        liveWaterReleaseFromDocument({
          'parteen_forecast': {'discharge_statement_raw': 'text'},
        }),
        isNull,
      );
    });

    test('missing raw statement defaults to empty string, not null', () {
      final w = liveWaterReleaseFromDocument({
        'parteen_forecast': {'discharge_classification': kNoDischargeExpected},
      });
      expect(w!.statementRaw, '');
    });
  });

  group('LiveWaterRelease.summaryLabel', () {
    LiveWaterRelease build(String c, {double? min, double? max}) =>
        LiveWaterRelease(
          classification: c,
          statementRaw: '',
          expectedMinM3s: min,
          expectedMaxM3s: max,
        );

    test('discharging reads as the action plus the range', () {
      expect(
        build(kDischargeExpected, min: 55, max: 170).summaryLabel,
        'No row \u00b7 55\u2013170 m\u00b3/s',
      );
    });

    test('discharging without a range still states the action', () {
      expect(build(kDischargeExpected).summaryLabel, 'No row');
    });

    test('clear is stated plainly', () {
      expect(build(kNoDischargeExpected).summaryLabel, 'Clear');
    });

    test('unparsed tells the coach to check the source themselves', () {
      expect(build(kUnparsed).summaryLabel, 'Unknown \u2014 check ESB');
    });
  });
}
