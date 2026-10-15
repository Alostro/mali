import 'package:flutter_test/flutter_test.dart';
import 'package:mali/money.dart';

void main() {
  test('formats rand', () {
    expect(rand(0), 'R0');
    expect(rand(123456), 'R1 234.56');
    expect(rand(1500000), 'R15 000');
  });

  test('parses rand', () {
    expect(parseRand('150'), 15000);
    expect(parseRand('R1 250,50'), 125050);
    expect(parseRand('1,250.50'), 125050);
    expect(parseRand('abc'), null);
  });

  test('weekend payday moves to Friday', () {
    // 25 Oct 2026 is a Sunday.
    expect(payDateIn(2026, 10, 25, true), DateTime(2026, 10, 23));
    expect(payDateIn(2026, 10, 25, false), DateTime(2026, 10, 25));
    expect(payDateIn(2026, 2, 31, false), DateTime(2026, 2, 28));
  });

  test('cycle runs payday to payday', () {
    final c = cycleFor(DateTime(2026, 10, 15), 25, true);
    expect(c.start, DateTime(2026, 9, 25));
    expect(c.end, DateTime(2026, 10, 23));
  });
}
