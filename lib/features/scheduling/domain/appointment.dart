class Appointment {
  final String idCita;
  final String? idIncidenteOrigen;
  final String idCliente;
  final String idVehiculo;
  final String idTaller;
  final String idSucursal;
  final String? idTecnico;
  final DateTime fechaHora;
  final int duracionMinutos;
  final String estado; // "PENDIENTE_CONFIRMACION", "CONFIRMADA", "REPROGRAMACION_SOLICITADA", "CANCELADA", "COMPLETADA"
  final String tipo; // "POST_AUXILIO", "DIRECTA"
  final String motivo;
  final String? observaciones;
  final String prioridad; // "BAJA", "MEDIA", "ALTA"
  final String creadoPor;
  final String rolCreador;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;

  // Enriched fields
  final String? clienteNombre;
  final String? vehiculoMatricula;
  final String? vehiculoMarca;
  final String? vehiculoModelo;
  final String? tecnicoNombre;
  final String? sucursalNombre;

  Appointment({
    required this.idCita,
    this.idIncidenteOrigen,
    required this.idCliente,
    required this.idVehiculo,
    required this.idTaller,
    required this.idSucursal,
    this.idTecnico,
    required this.fechaHora,
    required this.duracionMinutos,
    required this.estado,
    required this.tipo,
    required this.motivo,
    this.observaciones,
    required this.prioridad,
    required this.creadoPor,
    required this.rolCreador,
    required this.fechaCreacion,
    required this.fechaModificacion,
    this.clienteNombre,
    this.vehiculoMatricula,
    this.vehiculoMarca,
    this.vehiculoModelo,
    this.tecnicoNombre,
    this.sucursalNombre,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      idCita: json['id_cita'] ?? '',
      idIncidenteOrigen: json['id_incidente_origen'],
      idCliente: json['id_cliente'] ?? '',
      idVehiculo: json['id_vehiculo'] ?? '',
      idTaller: json['id_taller'] ?? '',
      idSucursal: json['id_sucursal'] ?? '',
      idTecnico: json['id_tecnico'],
      fechaHora: DateTime.parse(json['fecha_hora']).toLocal(),
      duracionMinutos: json['duracion_minutos'] ?? 60,
      estado: json['estado'] ?? '',
      tipo: json['tipo'] ?? '',
      motivo: json['motivo'] ?? '',
      observaciones: json['observaciones'],
      prioridad: json['prioridad'] ?? 'MEDIA',
      creadoPor: json['creado_por'] ?? '',
      rolCreador: json['rol_creador'] ?? '',
      fechaCreacion: DateTime.parse(json['fecha_creacion']).toLocal(),
      fechaModificacion: DateTime.parse(json['fecha_modificacion']).toLocal(),
      clienteNombre: json['cliente_nombre'],
      vehiculoMatricula: json['vehiculo_matricula'],
      vehiculoMarca: json['vehiculo_marca'],
      vehiculoModelo: json['vehiculo_modelo'],
      tecnicoNombre: json['tecnico_nombre'],
      sucursalNombre: json['sucursal_nombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_cita': idCita,
      'id_incidente_origen': idIncidenteOrigen,
      'id_cliente': idCliente,
      'id_vehiculo': idVehiculo,
      'id_taller': idTaller,
      'id_sucursal': idSucursal,
      'id_tecnico': idTecnico,
      'fecha_hora': fechaHora.toUtc().toIso8601String(),
      'duracion_minutos': duracionMinutos,
      'estado': estado,
      'tipo': tipo,
      'motivo': motivo,
      'observaciones': observaciones,
      'prioridad': prioridad,
      'creado_por': creadoPor,
      'rol_creador': rolCreador,
      'fecha_creacion': fechaCreacion.toUtc().toIso8601String(),
      'fecha_modificacion': fechaModificacion.toUtc().toIso8601String(),
    };
  }
}

class SlotAvailability {
  final DateTime fechaHora;
  final bool disponible;
  final String? motivo;

  SlotAvailability({
    required this.fechaHora,
    required this.disponible,
    this.motivo,
  });

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    return SlotAvailability(
      fechaHora: DateTime.parse(json['fecha_hora']).toLocal(),
      disponible: json['disponible'] ?? false,
      motivo: json['motivo'],
    );
  }
}
