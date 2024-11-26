import 'package:hive/hive.dart';

part 'most_visited_website_model.g.dart';

@HiveType(typeId: 10)
class MostVisitedWebsiteModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String domain;

  @HiveField(2)
  String faviconUrl;

  @HiveField(3)
  int visitCount;

  @HiveField(4)
  DateTime addedAt;

  @HiveField(5)
  bool isFavorite;

  @HiveField(6)
  String name;

  MostVisitedWebsiteModel({
    required this.id,
    required this.domain,
    required this.faviconUrl,
    required this.visitCount,
    required this.addedAt,
    required this.name,
    this.isFavorite = false,
  });
}
