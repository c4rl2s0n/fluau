import 'package:flutter_test/flutter_test.dart';
import 'package:skills_lint/skills_lint.dart';

void main() {
  test('skills pass skills_lint', () async {
    final Configuration config = await ConfigParser.loadConfig();
    expect(
      config.parsingErrors,
      isEmpty,
      reason: 'Fix the skills_lint.yaml errors listed in this failure.',
    );
    expect(
      config.directoryConfigs,
      isNotEmpty,
      reason: 'skills_lint.yaml must list at least one skills directory.',
    );

    final bool passed = await validateSkills(config: config);

    expect(
      passed,
      isTrue,
      reason: 'skills_lint found errors. Its findings are printed above.',
    );
  });
}
