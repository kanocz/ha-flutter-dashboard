class HomeAssistantInstance {
  final String id;
  final String name;
  final String url;
  bool isManuallyAdded;

  HomeAssistantInstance({
    required this.id,
    required this.name,
    required this.url,
    this.isManuallyAdded = false,
  });

  factory HomeAssistantInstance.fromJson(Map<String, dynamic> json) {
    return HomeAssistantInstance(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      isManuallyAdded: json['isManuallyAdded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'isManuallyAdded': isManuallyAdded,
    };
  }
}
