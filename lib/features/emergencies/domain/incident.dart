class IncidentCreate {
  final String vehicleId;
  final String? descripcion;
  final String? telefono;
  final double? latitud;
  final double? longitud;
  final String prioridad;

  IncidentCreate({
    required this.vehicleId,
    this.descripcion,
    this.telefono,
    this.latitud,
    this.longitud,
    this.prioridad = 'MEDIA',
  });

  Map<String, dynamic> toJson() {
    return {
      'id_vehiculo': vehicleId,
      'descripcion': descripcion,
      'telefono': telefono,
      'latitud': latitud,
      'longitud': longitud,
      'prioridad': prioridad,
    };
  }
}

class IncidentResponse {
  final String id;
  final String vehicleId;
  final String? workshopId;
  final String? technicianId;
  final String? workshopName;
  final String? technicianName;
  final String? technicianPhone;
  final String? branchName;
  final String? descripcion;
  final String? telefono;
  final String estado;
  final String prioridad;
  final String? fecha;
  final double? latitud;
  final double? longitud;
  final String? resumenIa;
  final String? analisisConsolidado;
  final List<dynamic>? historial;
  final String? verificationStatus;
  final String? verificationCode;
  final double? montoTotal;
  final double? manoDeObra;
  final double? repuestos;
  final String? observaciones;

  final String? clientName;
  final String? clientPhone;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleColor;
  final int? vehicleYear;

  IncidentResponse({
    required this.id,
    required this.vehicleId,
    this.workshopId,
    this.technicianId,
    this.workshopName,
    this.technicianName,
    this.technicianPhone,
    this.branchName,
    this.descripcion,
    this.telefono,
    required this.estado,
    required this.prioridad,
    this.fecha,
    this.latitud,
    this.longitud,
    this.resumenIa,
    this.analisisConsolidado,
    this.clientName,
    this.clientPhone,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
    this.vehicleYear,
    this.historial,
    this.verificationStatus,
    this.verificationCode,
    this.montoTotal,
    this.manoDeObra,
    this.repuestos,
    this.observaciones,
  });

  factory IncidentResponse.fromJson(Map<String, dynamic> json) {
    return IncidentResponse(
      id: json['id_incidente'] as String,
      vehicleId: json['id_vehiculo'] as String,
      workshopId: json['id_taller'] as String?,
      technicianId: json['id_tecnico'] as String?,
      workshopName: json['workshop_name'] as String?,
      technicianName: json['technician_name'] as String?,
      technicianPhone: json['technician_phone'] as String?,
      branchName: json['branch_name'] as String?,
      descripcion: json['descripcion'] as String?,
      telefono: json['telefono'] as String?,
      estado: json['estado_incidente'] as String,
      prioridad: json['prioridad_incidente'] as String,
      fecha: json['fecha_reporte'] as String?,
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
      resumenIa: json['resumen_ia'] as String?,
      analisisConsolidado: json['analisis_consolidado'] as String?,
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehicleYear: _toInt(json['vehicle_year']),
      historial: json['historial'] as List<dynamic>?,
      verificationStatus: json['verification_status'] as String?,
      verificationCode: json['verification_code'] as String?,
      montoTotal: _toDouble(json['monto_total']),
      manoDeObra: _toDouble(json['mano_de_obra']),
      repuestos: _toDouble(json['repuestos']),
      observaciones: json['observaciones'] as String?,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(',', '.').trim();
    return double.tryParse(cleaned);
  }
  return null;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    if (value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }
  return null;
}
