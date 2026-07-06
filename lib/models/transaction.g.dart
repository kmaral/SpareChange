// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CurrencyTransactionAdapter extends TypeAdapter<CurrencyTransaction> {
  @override
  final int typeId = 3;

  @override
  CurrencyTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CurrencyTransaction(
      id: fields[0] as String,
      denominationValue: fields[3] as double,
      denominationId: fields[11] as String,
      quantity: fields[4] as int,
      transactionType: fields[5] as TransactionType,
      totalAmount: fields[6] as double,
      reason: fields[7] as String?,
      timestamp: fields[8] as DateTime?,
      lastModified: fields[9] as DateTime?,
      currencyCode: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CurrencyTransaction obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.denominationValue)
      ..writeByte(11)
      ..write(obj.denominationId)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.transactionType)
      ..writeByte(6)
      ..write(obj.totalAmount)
      ..writeByte(7)
      ..write(obj.reason)
      ..writeByte(8)
      ..write(obj.timestamp)
      ..writeByte(9)
      ..write(obj.lastModified)
      ..writeByte(12)
      ..write(obj.currencyCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 4;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.added;
      case 1:
        return TransactionType.taken;
      default:
        return TransactionType.added;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.added:
        writer.writeByte(0);
        break;
      case TransactionType.taken:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
