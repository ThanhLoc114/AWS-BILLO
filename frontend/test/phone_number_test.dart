import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/utils/phone_number.dart';

void main() {
  test('normalizes Vietnamese local phone formats', () {
    expect(normalizePhoneNumber('0853555443'), '+84853555443');
    expect(normalizePhoneNumber('853555443'), '+84853555443');
    expect(normalizePhoneNumber('84853555443'), '+84853555443');
    expect(normalizePhoneNumber('+84853555443'), '+84853555443');
    expect(normalizePhoneNumber('+840853555443'), '+84853555443');
  });

  test('keeps valid explicit international number', () {
    expect(normalizePhoneNumber('+12065550101'), '+12065550101');
  });

  test('rejects invalid phone input', () {
    expect(() => normalizePhoneNumber('abc'), throwsFormatException);
    expect(() => normalizePhoneNumber('0123'), throwsFormatException);
  });
}
