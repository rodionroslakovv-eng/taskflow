import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/validators/validators.dart';

void main() {
  test('userName / email', () {
    expect(Validators.userName(' '), isA<ValidationFailure>());
    expect(Validators.userName('Анна'), isNull);
    expect(Validators.email('bad'), isA<ValidationFailure>());
    expect(Validators.email('a@mail.com'), isNull);
  });

  test('projectName / taskTitle / commentBody / fileName', () {
    expect(Validators.projectName(''), isA<ValidationFailure>());
    expect(Validators.projectName('P'), isNull);
    expect(Validators.taskTitle('  '), isA<ValidationFailure>());
    expect(Validators.taskTitle('T'), isNull);
    expect(Validators.commentBody(' '), isA<ValidationFailure>());
    expect(Validators.commentBody('hi'), isNull);
    expect(Validators.fileName(''), isA<ValidationFailure>());
    expect(Validators.fileName('a.txt'), isNull);
  });
}
