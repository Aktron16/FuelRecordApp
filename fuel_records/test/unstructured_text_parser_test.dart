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
  });
}

