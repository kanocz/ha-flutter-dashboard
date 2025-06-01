class EntityState {
  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final String lastUpdated;
  final String lastChanged;

  EntityState({
    required this.entityId,
    required this.state,
    required this.attributes,
    required this.lastUpdated,
    required this.lastChanged,
  });

  factory EntityState.fromJson(Map<String, dynamic> json) {
    // Defensive: handle missing/null fields for boolean entities
    return EntityState(
      entityId: json['entity_id'] ?? '',
      state: json['state']?.toString() ?? '',
      attributes: json['attributes'] != null ? Map<String, dynamic>.from(json['attributes']) : <String, dynamic>{},
      lastUpdated: json['last_updated']?.toString() ?? '',
      lastChanged: json['last_changed']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entity_id': entityId,
      'state': state,
      'attributes': attributes,
      'last_updated': lastUpdated,
      'last_changed': lastChanged,
    };
  }
}
