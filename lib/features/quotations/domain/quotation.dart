class QuotationWorkshopOption {
  final String idTaller;
  final String idSucursalRepresentante;
  final String? workshopName;
  final String? branchName;
  final double? distanciaKm;

  const QuotationWorkshopOption({
    required this.idTaller,
    required this.idSucursalRepresentante,
    this.workshopName,
    this.branchName,
    this.distanciaKm,
  });

  factory QuotationWorkshopOption.fromJson(Map<String, dynamic> json) {
    return QuotationWorkshopOption(
      idTaller: json['id_taller'] as String,
      idSucursalRepresentante: json['id_sucursal_representante'] as String,
      workshopName: json['workshop_name'] as String?,
      branchName: json['branch_name'] as String?,
      distanciaKm: _toDouble(json['distancia_km']),
    );
  }
}

class QuotationRequestCreate {
  final String vehicleId;
  final double latitud;
  final double longitud;
  final String? descripcion;
  final String? observaciones;
  final String prioridad;
  final String? categoriaServicio;
  final double radiusKm;

  const QuotationRequestCreate({
    required this.vehicleId,
    required this.latitud,
    required this.longitud,
    this.descripcion,
    this.observaciones,
    this.prioridad = 'MEDIA',
    this.categoriaServicio,
    this.radiusKm = 10.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_vehiculo': vehicleId,
      'latitud': latitud,
      'longitud': longitud,
      'descripcion': descripcion,
      'observaciones': observaciones,
      'prioridad': prioridad,
      'categoria_servicio': categoriaServicio,
      'radius_km': radiusKm,
    };
  }
}

class QuotationRequest {
  final String idSolicitudCotizacion;
  final String idCliente;
  final String idVehiculo;
  final String? clientName;
  final String? clientPhone;
  final String? vehicleLabel;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? descripcion;
  final String? observaciones;
  final String prioridad;
  final String? categoriaServicio;
  final String estado;
  final DateTime fechaVencimiento;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final List<QuotationWorkshopOption> compatibleWorkshops;

  const QuotationRequest({
    required this.idSolicitudCotizacion,
    required this.idCliente,
    required this.idVehiculo,
    this.clientName,
    this.clientPhone,
    this.vehicleLabel,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    required this.prioridad,
    required this.estado,
    required this.fechaVencimiento,
    required this.fechaCreacion,
    required this.fechaModificacion,
    required this.compatibleWorkshops,
    this.descripcion,
    this.observaciones,
    this.categoriaServicio,
  });

  factory QuotationRequest.fromJson(Map<String, dynamic> json) {
    final workshops = (json['compatible_workshops'] as List<dynamic>? ?? const [])
        .map((item) => QuotationWorkshopOption.fromJson(item as Map<String, dynamic>))
        .toList();

    return QuotationRequest(
      idSolicitudCotizacion: json['id_solicitud_cotizacion'] as String,
      idCliente: json['id_cliente'] as String,
      idVehiculo: json['id_vehiculo'] as String,
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      vehicleLabel: json['vehicle_label'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      descripcion: json['descripcion'] as String?,
      observaciones: json['observaciones'] as String?,
      prioridad: json['prioridad'] as String,
      categoriaServicio: json['categoria_servicio'] as String?,
      estado: json['estado'] as String,
      fechaVencimiento: DateTime.parse(json['fecha_vencimiento'] as String),
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaModificacion: DateTime.parse(json['fecha_modificacion'] as String),
      compatibleWorkshops: workshops,
    );
  }

  QuotationRequestSummary toSummary() {
    return QuotationRequestSummary(
      idSolicitudCotizacion: idSolicitudCotizacion,
      estado: estado,
      prioridad: prioridad,
      idVehiculo: idVehiculo,
      clientName: clientName,
      clientPhone: clientPhone,
      vehicleLabel: vehicleLabel,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehiclePlate: vehiclePlate,
      descripcion: descripcion,
      observaciones: observaciones,
      fechaVencimiento: fechaVencimiento,
      fechaCreacion: fechaCreacion,
      fechaModificacion: fechaModificacion,
      compatibleWorkshops: compatibleWorkshops,
    );
  }
}

class QuotationRequestSummary {
  final String idSolicitudCotizacion;
  final String estado;
  final String prioridad;
  final String idVehiculo;
  final String? clientName;
  final String? clientPhone;
  final String? vehicleLabel;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? descripcion;
  final String? observaciones;
  final DateTime fechaVencimiento;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final List<QuotationWorkshopOption> compatibleWorkshops;

  const QuotationRequestSummary({
    required this.idSolicitudCotizacion,
    required this.estado,
    required this.prioridad,
    required this.idVehiculo,
    this.clientName,
    this.clientPhone,
    this.vehicleLabel,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    required this.fechaVencimiento,
    required this.fechaCreacion,
    required this.fechaModificacion,
    required this.compatibleWorkshops,
    this.descripcion,
    this.observaciones,
  });

  factory QuotationRequestSummary.fromJson(Map<String, dynamic> json) {
    final workshops = (json['compatible_workshops'] as List<dynamic>? ?? const [])
        .map((item) => QuotationWorkshopOption.fromJson(item as Map<String, dynamic>))
        .toList();

    return QuotationRequestSummary(
      idSolicitudCotizacion: json['id_solicitud_cotizacion'] as String,
      estado: json['estado'] as String,
      prioridad: json['prioridad'] as String,
      idVehiculo: json['id_vehiculo'] as String,
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
      vehicleLabel: json['vehicle_label'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      descripcion: json['descripcion'] as String?,
      observaciones: json['observaciones'] as String?,
      fechaVencimiento: DateTime.parse(json['fecha_vencimiento'] as String),
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaModificacion: DateTime.parse(json['fecha_modificacion'] as String),
      compatibleWorkshops: workshops,
    );
  }
}

class QuotationWorkshopInboxItemResponse {
  final String idSolicitudTaller;
  final String idSolicitudCotizacion;
  final String idTaller;
  final String idSucursalRepresentante;
  final String? workshopName;
  final String? branchName;
  final String estadoEnvio;
  final DateTime fechaEnvio;
  final DateTime fechaActualizacion;
  final QuotationRequestSummary request;

  const QuotationWorkshopInboxItemResponse({
    required this.idSolicitudTaller,
    required this.idSolicitudCotizacion,
    required this.idTaller,
    required this.idSucursalRepresentante,
    this.workshopName,
    this.branchName,
    required this.estadoEnvio,
    required this.fechaEnvio,
    required this.fechaActualizacion,
    required this.request,
  });

  factory QuotationWorkshopInboxItemResponse.fromJson(Map<String, dynamic> json) {
    return QuotationWorkshopInboxItemResponse(
      idSolicitudTaller: json['id_solicitud_taller'] as String,
      idSolicitudCotizacion: json['id_solicitud_cotizacion'] as String,
      idTaller: json['id_taller'] as String,
      idSucursalRepresentante: json['id_sucursal_representante'] as String,
      workshopName: json['workshop_name'] as String?,
      branchName: json['branch_name'] as String?,
      estadoEnvio: json['estado_envio'] as String,
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
      fechaActualizacion: DateTime.parse(json['fecha_actualizacion'] as String),
      request: QuotationRequestSummary.fromJson(json['request'] as Map<String, dynamic>),
    );
  }
}

class QuotationQuote {
  final String idCotizacion;
  final String idSolicitudCotizacion;
  final String idSolicitudTaller;
  final String idTaller;
  final String idSucursalRepresentante;
  final String idAdminResponde;
  final double manoObraEstimado;
  final double repuestosEstimado;
  final double totalEstimado;
  final int tiempoEstimadoMinutos;
  final String? observaciones;
  final DateTime vigenciaHasta;
  final String estado;
  final String? idIncidenteGenerado;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final String? workshopName;
  final String? branchName;
  final String? responderName;

  const QuotationQuote({
    required this.idCotizacion,
    required this.idSolicitudCotizacion,
    required this.idSolicitudTaller,
    required this.idTaller,
    required this.idSucursalRepresentante,
    required this.idAdminResponde,
    required this.manoObraEstimado,
    required this.repuestosEstimado,
    required this.totalEstimado,
    required this.tiempoEstimadoMinutos,
    required this.vigenciaHasta,
    required this.estado,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.observaciones,
    this.idIncidenteGenerado,
    this.workshopName,
    this.branchName,
    this.responderName,
  });

  factory QuotationQuote.fromJson(Map<String, dynamic> json) {
    return QuotationQuote(
      idCotizacion: json['id_cotizacion'] as String,
      idSolicitudCotizacion: json['id_solicitud_cotizacion'] as String,
      idSolicitudTaller: json['id_solicitud_taller'] as String,
      idTaller: json['id_taller'] as String,
      idSucursalRepresentante: json['id_sucursal_representante'] as String,
      idAdminResponde: json['id_admin_responde'] as String,
      manoObraEstimado: _toDouble(json['mano_obra_estimado']) ?? 0,
      repuestosEstimado: _toDouble(json['repuestos_estimado']) ?? 0,
      totalEstimado: _toDouble(json['total_estimado']) ?? 0,
      tiempoEstimadoMinutos: _toInt(json['tiempo_estimado_minutos']) ?? 0,
      observaciones: json['observaciones'] as String?,
      vigenciaHasta: DateTime.parse(json['vigencia_hasta'] as String),
      estado: json['estado'] as String,
      idIncidenteGenerado: json['id_incidente_generado'] as String?,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      fechaModificacion: DateTime.parse(json['fecha_modificacion'] as String),
      workshopName: json['workshop_name'] as String?,
      branchName: json['branch_name'] as String?,
      responderName: json['responder_name'] as String?,
    );
  }
}

class QuotationIncident {
  final String idIncidente;
  final String? idTaller;
  final String? idSucursal;
  final String? idCotizacionOrigen;
  final String? origen;
  final String estadoIncidente;
  final String prioridadIncidente;

  const QuotationIncident({
    required this.idIncidente,
    required this.estadoIncidente,
    required this.prioridadIncidente,
    this.idTaller,
    this.idSucursal,
    this.idCotizacionOrigen,
    this.origen,
  });

  factory QuotationIncident.fromJson(Map<String, dynamic> json) {
    return QuotationIncident(
      idIncidente: json['id_incidente'] as String,
      idTaller: json['id_taller'] as String?,
      idSucursal: json['id_sucursal'] as String?,
      idCotizacionOrigen: json['id_cotizacion_origen'] as String?,
      origen: json['origen'] as String?,
      estadoIncidente: json['estado_incidente'] as String,
      prioridadIncidente: json['prioridad_incidente'] as String,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(',', '.').trim();
    return double.tryParse(cleaned);
  }
  return null;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}
