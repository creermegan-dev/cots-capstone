import 'dart:io';

import 'package:cots_monitor/models/davao_gulf_geography.dart';

/// Loads the bundled monitoring map from the project's asset files (tests run
/// from the project folder).
void loadTestMap() {
  if (DavaoGulfGeography.isLoaded) return;
  DavaoGulfGeography.loadFromData(
    partsJson: File('assets/map/parts.json').readAsStringSync(),
    areasJson: File('assets/map/areas.json').readAsStringSync(),
    outlinesJson: File('assets/map/part_outlines.json').readAsStringSync(),
    lookup: File('assets/map/lookup.bin').readAsBytesSync(),
  );
}
