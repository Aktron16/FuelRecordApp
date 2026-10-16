import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_records/services/unstructured_text_parser.dart';

void main() {
  group('UnstructuredTextParser Tests', () {
    test('Parses natural sentence with multiple alternate words', () {
      const text = 'Filled 42.5 L for \$78.20 at Shell on 15-Oct-26, odo: 54200km';
      final results = UnstructuredTextParser.parse(text);

      expect(results.length, 1);
      final r = results.first;
      expect(r.fuelAmount, 42.5);
      expect(r.totalPrice, 78.20);
      expect(r.gasStation, 'Shell');
      expect(r.odometer, 54200);
      expect(r.dateTime.day, 15);
      expect(r.dateTime.month, 10);
      expect(r.dateTime.year, 2026);
      expect(r.isFullTank, isTrue);
    });

    test('Parses relative date and fuel grade', () {
      const text = 'Yesterday topped up 10.5 gal at Chevron for \$38.00, odometer 120500 Premium 93';
      final results = UnstructuredTextParser.parse(text);

      expect(results.length, 1);
      final r = results.first;
      expect(r.fuelAmount, 10.5);
      expect(r.totalPrice, 38.00);
      expect(r.gasStation, 'Chevron');
      expect(r.odometer, 120500);
      expect(r.fuelType, 'Premium (93)');
      expect(r.isFullTank, isTrue);
    });

    test('Parses multi-line unstructured notes', () {
      const text = '''
        2026-10-10, 50000km, 45L, \$70, BP
        12-Oct-26 odo 50450 filled 40 litres cost: \$65 at Exxon full tank
        ''';
      final results = UnstructuredTextParser.parse(text);

      expect(results.length, 2);

      expect(results[0].odometer, 50000);
      expect(results[0].fuelAmount, 45);
      expect(results[0].totalPrice, 70);
      expect(results[0].gasStation, 'BP');

      expect(results[1].odometer, 50450);
      expect(results[1].fuelAmount, 40);
      expect(results[1].totalPrice, 65);
      expect(results[1].gasStation, 'Exxon');
      expect(results[1].isFullTank, isTrue);
    });

    test('Cleans up whitespace and handles partial tank note', () {
      const text = '   BP   station   @   61000   miles    qty:  15.2  gal   paid   55.00   partial  tank  ';
      final results = UnstructuredTextParser.parse(text);

      expect(results.length, 1);
      final r = results.first;
      expect(r.gasStation, 'BP');
      expect(r.odometer, 61000);
      expect(r.fuelAmount, 15.2);
      expect(r.totalPrice, 55.00);
      expect(r.isFullTank, isFalse);
    });

    test('Parses distance and kms synonyms for odometer, petrol, diesel, gas for fuel', () {
      const text1 = 'distance 48000 kms, petrol 40.5, paid \$65 at Shell';
      final r1 = UnstructuredTextParser.parse(text1).first;
      expect(r1.odometer, 48000);
      expect(r1.fuelAmount, 40.5);
      expect(r1.totalPrice, 65.0);
      expect(r1.gasStation, 'Shell');

      const text2 = 'dist: 72500, diesel: 42, cost: 60 at Total';
      final r2 = UnstructuredTextParser.parse(text2).first;
      expect(r2.odometer, 72500);
      expect(r2.fuelAmount, 42.0);
      expect(r2.totalPrice, 60.0);
      expect(r2.fuelType, 'Diesel');
      expect(r2.gasStation, 'Total');

      const text3 = '85000 distance, gas: 14 gal, spent \$52';
      final r3 = UnstructuredTextParser.parse(text3).first;
      expect(r3.odometer, 85000);
      expect(r3.fuelAmount, 14.0);
      expect(r3.totalPrice, 52.0);
    });

    test('Does not force numbers into columns when keywords or units are missing', () {
      const text = 'At Shell on 15-Oct-26, paid \$50, bought 2 coffees and snack 15';
      final results = UnstructuredTextParser.parse(text);

      expect(results.length, 1);
      final r = results.first;
      expect(r.gasStation, 'Shell');
      expect(r.totalPrice, 50.0);
      expect(r.odometer, isNull, reason: 'Odometer should not be forced without keyword or unit');
      expect(r.fuelAmount, isNull, reason: 'Fuel amount should not be forced without keyword or unit');
    });
  });
}

