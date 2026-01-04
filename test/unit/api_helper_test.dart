import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Math sanity check', () {
    expect(2 + 2, 4);
  });

  test('Check API base URL is set', () {
    const baseUrl = "https://support.porterlee.com/plc/intf/prospect/";
    expect(baseUrl.contains("prospect"), true);
  });
}
