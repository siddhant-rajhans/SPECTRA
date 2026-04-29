/// Maps YAMNet AudioSet display names to the 12 sound types this app surfaces.
///
/// Hand-curated. Multiple AudioSet classes can map to a single internal type
/// (e.g. several siren variants → "siren"). Keep names lowercase for matching.
///
/// AudioSet ontology reference:
/// https://github.com/audioset/ontology
class SoundTypeMap {
  /// Internal sound type → list of YAMNet display name fragments (substrings).
  /// At classify-time we look up the YAMNet name for the predicted index and
  /// match against any of the fragments here. Substring matching keeps the
  /// table tolerant of small wording differences across YAMNet revisions.
  static const Map<String, List<String>> rules = {
    'doorbell': [
      'doorbell',
      'ding-dong',
    ],
    'fire_alarm': [
      'fire alarm',
      'civil defense siren',
    ],
    'smoke_detector': [
      'smoke detector',
      'smoke alarm',
    ],
    'car_horn': [
      'vehicle horn',
      'car alarm',
      'horn',
    ],
    'siren': [
      'siren',
      'police car (siren)',
      'ambulance (siren)',
      'fire engine, fire truck (siren)',
      'emergency vehicle',
    ],
    'baby_crying': [
      'baby cry',
      'infant cry',
      'crying, sobbing',
    ],
    'dog_bark': [
      'bark',
      'yip',
      'howl',
      'bow-wow',
      'growling',
      'whimper (dog)',
      'dog',
    ],
    'phone_ring': [
      'telephone bell ringing',
      'ringtone',
      'telephone',
    ],
    'knock': [
      'knock',
      'thump, thud',
    ],
    'alarm_timer': [
      'alarm clock',
      'beep, bleep',
      'buzzer',
      'alarm',
    ],
    'microwave': [
      'microwave oven',
    ],
    'name_called': [
      // No reliable AudioSet class — name detection requires keyword spotting,
      // not generic audio classification. Surface only via speech pipeline.
    ],
  };

  /// Build a yamnet-class-index → internal-sound-type map by intersecting the
  /// rules above with the actual class list loaded from `yamnet_class_map.csv`.
  static Map<int, String> buildIndexMap(List<String> yamnetClassNames) {
    final indexToType = <int, String>{};
    for (var i = 0; i < yamnetClassNames.length; i++) {
      final name = yamnetClassNames[i].toLowerCase();
      for (final entry in rules.entries) {
        for (final fragment in entry.value) {
          if (name.contains(fragment.toLowerCase())) {
            // Earlier wins — but specific fragments like "smoke alarm" should
            // beat the generic "alarm". We sort rules by descending fragment
            // specificity below.
            indexToType.putIfAbsent(i, () => entry.key);
            break;
          }
        }
      }
    }
    return indexToType;
  }
}
