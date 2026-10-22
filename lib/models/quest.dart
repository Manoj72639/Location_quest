class Quest {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int xpReward;
  final bool isActive;

  const Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.xpReward,
    required this.isActive,
  });

  factory Quest.fromMap(String id, Map<String, dynamic> data) {
    return Quest(
      id: id,
      name: data['name'] as String? ?? 'Unnamed quest',
      description: data['description'] as String? ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 50,
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 100,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
