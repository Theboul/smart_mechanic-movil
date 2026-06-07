class OfflineEmergencyDraft {
  final String localId;
  final String vehicleId;
  final String description;
  final String? phone;
  final double latitude;
  final double longitude;
  final String? locationReference;
  final String priority;
  final DateTime createdAt;
  final DateTime? lastSyncAttemptAt;
  final int syncAttempts;
  final String syncStatus;
  final String? backendIncidentId;
  final String? lastError;

  const OfflineEmergencyDraft({
    required this.localId,
    required this.vehicleId,
    required this.description,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.locationReference,
    required this.priority,
    required this.createdAt,
    this.lastSyncAttemptAt,
    required this.syncAttempts,
    required this.syncStatus,
    this.backendIncidentId,
    this.lastError,
  });

  OfflineEmergencyDraft copyWith({
    String? localId,
    String? vehicleId,
    String? description,
    String? phone,
    double? latitude,
    double? longitude,
    String? locationReference,
    String? priority,
    DateTime? createdAt,
    DateTime? lastSyncAttemptAt,
    int? syncAttempts,
    String? syncStatus,
    String? backendIncidentId,
    String? lastError,
  }) {
    return OfflineEmergencyDraft(
      localId: localId ?? this.localId,
      vehicleId: vehicleId ?? this.vehicleId,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationReference: locationReference ?? this.locationReference,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncStatus: syncStatus ?? this.syncStatus,
      backendIncidentId: backendIncidentId ?? this.backendIncidentId,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'local_id': localId,
      'vehicle_id': vehicleId,
      'description': description,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'location_reference': locationReference,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'last_sync_attempt_at': lastSyncAttemptAt?.toIso8601String(),
      'sync_attempts': syncAttempts,
      'sync_status': syncStatus,
      'backend_incident_id': backendIncidentId,
      'last_error': lastError,
    };
  }

  factory OfflineEmergencyDraft.fromMap(Map<String, Object?> map) {
    return OfflineEmergencyDraft(
      localId: map['local_id'] as String,
      vehicleId: map['vehicle_id'] as String,
      description: map['description'] as String? ?? '',
      phone: map['phone'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationReference: map['location_reference'] as String?,
      priority: map['priority'] as String? ?? 'CRITICA',
      createdAt: DateTime.parse(map['created_at'] as String),
      lastSyncAttemptAt: map['last_sync_attempt_at'] != null
          ? DateTime.parse(map['last_sync_attempt_at'] as String)
          : null,
      syncAttempts: (map['sync_attempts'] as num?)?.toInt() ?? 0,
      syncStatus: map['sync_status'] as String? ?? 'PENDING_SYNC',
      backendIncidentId: map['backend_incident_id'] as String?,
      lastError: map['last_error'] as String?,
    );
  }
}
