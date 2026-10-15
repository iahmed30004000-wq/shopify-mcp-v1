// Her few settings, and the owner's switch that stays off.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/sufra/sufra.dart';

void main() {
  test('a fresh install: two weeks, three days of expiry warning, no diet mode', () {
    const s = SufraSettings();
    expect(s.noRepeatDays, 14);
    expect(s.expiryWarningDays, 3);
    expect(s.nearlyLimit, 3);
    expect(s.defaultPeople, isNull);
    expect(s.dietMode, isFalse);
  });

  test('it survives JSON both ways', () {
    const s = SufraSettings(noRepeatDays: 7, expiryWarningDays: 1, nearlyLimit: 5, defaultPeople: 6, dietMode: true);
    expect(SufraSettings.fromJson(s.toJson()), s);
  });

  test('rubbish in the store reads as the defaults, never as an error', () {
    expect(SufraSettings.fromJson(null), const SufraSettings());
    expect(SufraSettings.fromJson('nope'), const SufraSettings());
    expect(SufraSettings.fromJson({'noRepeatDays': 'x'}), const SufraSettings());
  });

  test('an impossible window is clamped, and a negative one turns the rule off', () {
    expect(SufraSettings.fromJson({'noRepeatDays': -3}).noRepeatDays, 0);
    expect(SufraSettings.fromJson({'noRepeatDays': 99999}).noRepeatDays, NoRepeat.maxWindowDays);
    expect(const SufraSettings().copyWith(noRepeatDays: -1).noRepeatDays, 0);
  });

  test('«كم واحد ياكل» can be cleared back to "she did not say"', () {
    const s = SufraSettings(defaultPeople: 6);
    expect(s.copyWith(clearDefaultPeople: true).defaultPeople, isNull);
  });

  test('the two list hosts are the ones Part 3b addresses', () {
    expect(PantryLists.houseTable, 'pantry');
    expect(PantryLists.houseId, 'house');
    expect(PantryLists.recipesTable, 'recipes');
  });
}
