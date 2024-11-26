// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'most_visited_website_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MostVisitedWebsiteModelAdapter extends TypeAdapter<MostVisitedWebsiteModel> {
  @override
  final int typeId = 10;

  @override
  MostVisitedWebsiteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MostVisitedWebsiteModel(
      id: fields[0] as String,
      domain: fields[1] as String,
      faviconUrl: fields[2] as String,
      visitCount: fields[3] as int,
      addedAt: fields[4] as DateTime,
      isFavorite: fields[5] as bool,
      name: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MostVisitedWebsiteModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.domain)
      ..writeByte(2)
      ..write(obj.faviconUrl)
      ..writeByte(3)
      ..write(obj.visitCount)
      ..writeByte(4)
      ..write(obj.addedAt)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MostVisitedWebsiteModelAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}
