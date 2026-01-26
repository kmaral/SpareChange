// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'denomination.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DenominationAdapter extends TypeAdapter<Denomination> {
  @override
  final int typeId = 0;

  @override
  Denomination read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Denomination(
      id: fields[0] as String,
      value: fields[1] as double,
      type: fields[2] as DenominationType,
      isActive: fields[3] as bool,
      createdAt: fields[4] as DateTime?,
      groupId: fields[5] as String,
      isAutoCreated: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Denomination obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.groupId)
      ..writeByte(6)
      ..write(obj.isAutoCreated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DenominationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DenominationTypeAdapter extends TypeAdapter<DenominationType> {
  @override
  final int typeId = 1;

  @override
  DenominationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DenominationType.coin;
      case 1:
        return DenominationType.note;
      default:
        return DenominationType.coin;
    }
  }

  @override
  void write(BinaryWriter writer, DenominationType obj) {
    switch (obj) {
      case DenominationType.coin:
        writer.writeByte(0);
        break;
      case DenominationType.note:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DenominationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
