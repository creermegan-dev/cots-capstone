import 'dart:convert';
import 'dart:io';

import 'package:cots_monitor/models/davao_gulf_geography.dart';

String _literal(String value) => "'${value.replaceAll("'", "''")}'";

void main() {
  final rows = <String>[];
  for (final municipality in DavaoGulfGeography.municipalities) {
    for (final barangay in municipality.barangays) {
      final reference = jsonEncode({
        'site_code': barangay.siteCode,
        'zone_code': barangay.zoneCode,
        'province': barangay.province,
        'centroid': {
          'latitude': barangay.centroid.latitude,
          'longitude': barangay.centroid.longitude,
        },
        'polygon': [
          for (final point in barangay.polygon)
            [point.latitude, point.longitude],
        ],
      });
      rows.add(
        '(${_literal(barangay.id)}, ${_literal(barangay.name)}, '
        '${_literal(municipality.name)}, ${_literal(barangay.name)}, '
        "'cots-davao-gulf-v1', ${_literal(reference)}::jsonb, true, true)",
      );
    }
  }
  final sql =
      '''-- Generated from DavaoGulfGeography. Do not edit rows manually.
begin;
insert into public.monitoring_areas
  (code,name,municipality,barangay,geography_version,geographic_reference,approximate_boundary,active)
values
${rows.join(',\n')}
on conflict (code) do update set
  name=excluded.name,
  municipality=excluded.municipality,
  barangay=excluded.barangay,
  geography_version=excluded.geography_version,
  geographic_reference=excluded.geographic_reference,
  approximate_boundary=excluded.approximate_boundary,
  active=excluded.active;
commit;
''';
  File('supabase/migrations/20261028000100_monitoring_areas.sql')
      .writeAsStringSync(sql);
  stdout.writeln('Generated ${rows.length} monitoring areas.');
}
