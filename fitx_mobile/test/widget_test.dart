// Minimal placeholder test to verify FitXApp builds without errors.
import 'package:flutter_test/flutter_test.dart';

import 'package:fitx_mobile/main.dart';

void main() {
  test('FitXApp loads without errors', () {
    expect(() => FitXApp(), returnsNormally);
  });
}
