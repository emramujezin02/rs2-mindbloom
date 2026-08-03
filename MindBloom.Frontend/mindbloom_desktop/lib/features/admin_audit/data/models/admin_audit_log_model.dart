class AdminAuditLogModel {
  final int id;
  final int? adminUserId;
  final String adminName;
  final String adminEmail;
  final String action;
  final String entityType;
  final String? entityId;
  final String httpMethod;
  final String requestPath;
  final DateTime occurredAtUtc;
  final String? previousValues;
  final String? newValues;
  final String? ipAddress;
  final String correlationId;
  final bool isSuccessful;
  final int statusCode;
  final String? resultMessage;

  const AdminAuditLogModel({
    required this.id,
    required this.adminUserId,
    required this.adminName,
    required this.adminEmail,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.httpMethod,
    required this.requestPath,
    required this.occurredAtUtc,
    required this.previousValues,
    required this.newValues,
    required this.ipAddress,
    required this.correlationId,
    required this.isSuccessful,
    required this.statusCode,
    required this.resultMessage,
  });

  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogModel(
      id: _toInt(json['id']),
      adminUserId: _toNullableInt(json['adminUserId']),
      adminName: json['adminName']?.toString() ?? 'Administrator',
      adminEmail: json['adminEmail']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? '',
      entityId: json['entityId']?.toString(),
      httpMethod: json['httpMethod']?.toString() ?? '',
      requestPath: json['requestPath']?.toString() ?? '',
      occurredAtUtc: DateTime.parse(json['occurredAtUtc'].toString()).toUtc(),
      previousValues: json['previousValues']?.toString(),
      newValues: json['newValues']?.toString(),
      ipAddress: json['ipAddress']?.toString(),
      correlationId: json['correlationId']?.toString() ?? '',
      isSuccessful: json['isSuccessful'] == true,
      statusCode: _toInt(json['statusCode']),
      resultMessage: json['resultMessage']?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
