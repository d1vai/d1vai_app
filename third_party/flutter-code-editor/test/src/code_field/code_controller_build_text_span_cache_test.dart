import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  testWidgets(
    'buildTextSpan reuses cached span when only selection changes',
    (wt) async {
      final controller = createController('void main() {\n  print(1);\n}\n');

      focusNode = FocusNode();
      await wt.pumpWidget(createApp(controller, focusNode));

      final context = wt.element(find.byType(CodeField));
      const style = TextStyle(fontSize: 14);

      final first = controller.buildTextSpan(
        context: context,
        style: style,
        withComposing: false,
      );

      controller.selection = const TextSelection.collapsed(offset: 4);

      final second = controller.buildTextSpan(
        context: context,
        style: style,
        withComposing: false,
      );

      expect(identical(first, second), isTrue);
    },
  );
}
