import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TicTacToeApp());
    expect(find.text('Tic Tac Toe'), findsAny);
  });
}
