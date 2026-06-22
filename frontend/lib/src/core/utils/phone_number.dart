String normalizePhoneNumber(String input, {String defaultCountryCode = '+84'}) {
  var value = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (value.startsWith('00')) value = '+${value.substring(2)}';

  if (value.startsWith('+')) {
    if (value.startsWith('+840')) value = '+84${value.substring(4)}';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      throw const FormatException('Số điện thoại không hợp lệ');
    }
    return value;
  }

  if (!RegExp(r'^\d+$').hasMatch(value)) {
    throw const FormatException('Số điện thoại chỉ được chứa chữ số');
  }

  if (defaultCountryCode == '+84') {
    if (value.startsWith('84')) {
      value = value.substring(2);
    }
    if (value.startsWith('0')) {
      value = value.substring(1);
    }
  } else if (value.startsWith('0')) {
    value = value.substring(1);
  }

  final normalized = '$defaultCountryCode$value';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
    throw const FormatException('Số điện thoại không hợp lệ');
  }
  return normalized;
}
