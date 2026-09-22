/// Dakar Bus - Groupe 11
/// DataSourceInfo : métadonnées source réelle, aucune heure inventée

class DataSourceInfo {
  final String sourceId;
  final String? sourceType;
  final String? sourceName;
  final DateTime? retrievedAt;
  final String? trustLevel;

  const DataSourceInfo({
    required this.sourceId,
    this.sourceType,
    this.sourceName,
    this.retrievedAt,
    this.trustLevel,
  });

  @override
  String toString() => 'DataSourceInfo($sourceId, ${sourceType ?? 'unknown'})';
}
