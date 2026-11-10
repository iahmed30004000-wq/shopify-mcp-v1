import '../../../core/i18n/gen/app_localizations.dart';
import 'packing.dart';

/// Generic packing lists offered from the empty templates screen (never
/// seeded on their own: a fresh install starts empty). Names and items are
/// written in the UI language at the moment they are added, and are then
/// ordinary, editable, deletable templates.
List<({String name, List<PackingTemplateItem> items})> starterTemplates(L10n l) {
  PackingTemplateItem i(String body, String category) => PackingTemplateItem(body, category);
  const docs = PackingCategories.documents;
  const clothes = PackingCategories.clothes;
  const care = PackingCategories.toiletries;
  const health = PackingCategories.health;
  const tech = PackingCategories.electronics;
  const prayer = PackingCategories.prayer;
  const misc = PackingCategories.misc;
  return [
    (
      name: l.travelStarterEssentials,
      items: [
        i(l.travelSeedPassport, docs),
        i(l.travelSeedTickets, docs),
        i(l.travelSeedWallet, docs),
        i(l.travelSeedCash, docs),
        i(l.travelSeedClothes, clothes),
        i(l.travelSeedSleepwear, clothes),
        i(l.travelSeedToothbrush, care),
        i(l.travelSeedMiswak, care),
        i(l.travelSeedDeodorant, care),
        i(l.travelSeedMeds, health),
        i(l.travelSeedFirstAid, health),
        i(l.travelSeedCharger, tech),
        i(l.travelSeedPowerBank, tech),
        i(l.travelSeedAdapter, tech),
        i(l.travelSeedPrayerMat, prayer),
        i(l.travelSeedQuran, prayer),
      ],
    ),
    (
      name: l.travelStarterBusiness,
      items: [
        i(l.travelSeedCards, docs),
        i(l.travelSeedFormal, clothes),
        i(l.travelSeedLaptop, tech),
        i(l.travelSeedNotebook, misc),
      ],
    ),
    (
      name: l.travelStarterUmrah,
      items: [
        i(l.travelSeedPermit, docs),
        i(l.travelSeedIhram, clothes),
        i(l.travelSeedIhramBelt, clothes),
        i(l.travelSeedSandals, clothes),
        i(l.travelSeedUnscented, care),
        i(l.travelSeedUmbrella, misc),
        i(l.travelSeedWater, misc),
        i(l.travelSeedShoeBag, misc),
        i(l.travelSeedDuas, prayer),
      ],
    ),
    (
      name: l.travelStarterWinter,
      items: [
        i(l.travelSeedCoat, clothes),
        i(l.travelSeedScarf, clothes),
        i(l.travelSeedThermal, clothes),
        i(l.travelSeedLipBalm, care),
      ],
    ),
  ];
}
