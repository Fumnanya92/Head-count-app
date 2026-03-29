// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resident.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ResidentAdapter extends TypeAdapter<Resident> {
  @override
  final int typeId = 0;

  @override
  Resident read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Resident(
      id: fields[0] as int,
      houseAddress: fields[1] as String,
      zoneBlock: fields[2] as String?,
      houseType: fields[3] as String?,
      unitFlat: fields[4] as String?,
      occupancyStatus: fields[5] as String,
      recordStatus: fields[6] as String?,
      householdsCount: fields[7] as int,
      monthlyDue: fields[8] as int,
      paymentStatus: fields[9] as String?,
      lastPaymentDate: fields[10] as String?,
      adults: fields[11] as int,
      children: fields[12] as int,
      totalHeadcount: fields[13] as int,
      mainContactName: fields[14] as String?,
      contactRole: fields[15] as String?,
      phoneNumber: fields[16] as String?,
      whatsappNumber: fields[17] as String?,
      email: fields[18] as String?,
      appRegistered: fields[19] as String?,
      phoneType: fields[20] as String?,
      notes: fields[21] as String?,
      visitDate: fields[22] as String?,
      visitedBy: fields[23] as String?,
      dataVerified: fields[24] as String?,
      followUpNeeded: fields[25] as String?,
      followUpDate: fields[26] as String?,
      isModified: fields[27] as bool,
      updatedAt: fields[28] as DateTime?,
      totalFlatsInCompound: fields[29] as int?,
      dataSource: fields[30] as String?,
      verificationStatus: fields[31] as String?,
      firstVerifiedDate: fields[32] as String?,
      lastUpdatedBy: fields[33] as String?,
      avatarImagePath: fields[34] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Resident obj) {
    writer
      ..writeByte(35)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.houseAddress)
      ..writeByte(2)
      ..write(obj.zoneBlock)
      ..writeByte(3)
      ..write(obj.houseType)
      ..writeByte(4)
      ..write(obj.unitFlat)
      ..writeByte(5)
      ..write(obj.occupancyStatus)
      ..writeByte(6)
      ..write(obj.recordStatus)
      ..writeByte(7)
      ..write(obj.householdsCount)
      ..writeByte(8)
      ..write(obj.monthlyDue)
      ..writeByte(9)
      ..write(obj.paymentStatus)
      ..writeByte(10)
      ..write(obj.lastPaymentDate)
      ..writeByte(11)
      ..write(obj.adults)
      ..writeByte(12)
      ..write(obj.children)
      ..writeByte(13)
      ..write(obj.totalHeadcount)
      ..writeByte(14)
      ..write(obj.mainContactName)
      ..writeByte(15)
      ..write(obj.contactRole)
      ..writeByte(16)
      ..write(obj.phoneNumber)
      ..writeByte(17)
      ..write(obj.whatsappNumber)
      ..writeByte(18)
      ..write(obj.email)
      ..writeByte(19)
      ..write(obj.appRegistered)
      ..writeByte(20)
      ..write(obj.phoneType)
      ..writeByte(21)
      ..write(obj.notes)
      ..writeByte(22)
      ..write(obj.visitDate)
      ..writeByte(23)
      ..write(obj.visitedBy)
      ..writeByte(24)
      ..write(obj.dataVerified)
      ..writeByte(25)
      ..write(obj.followUpNeeded)
      ..writeByte(26)
      ..write(obj.followUpDate)
      ..writeByte(27)
      ..write(obj.isModified)
      ..writeByte(28)
      ..write(obj.updatedAt)
      ..writeByte(29)
      ..write(obj.totalFlatsInCompound)
      ..writeByte(30)
      ..write(obj.dataSource)
      ..writeByte(31)
      ..write(obj.verificationStatus)
      ..writeByte(32)
      ..write(obj.firstVerifiedDate)
      ..writeByte(33)
      ..write(obj.lastUpdatedBy)
      ..writeByte(34)
      ..write(obj.avatarImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResidentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
