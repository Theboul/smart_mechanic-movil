import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../garage/domain/vehicle.dart';
import '../../../garage/presentation/providers/vehicle_provider.dart';
import '../../domain/quotation.dart';
import '../providers/quotation_providers.dart';
import '../widgets/quotation_request_card.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _observationsController = TextEditingController();

  String? _selectedVehicleId;
  String _priority = 'MEDIA';
  bool _isCreating = false;
  bool _isCapturingLocation = false;
  double? _capturedLatitude;
  double? _capturedLongitude;
  String? _locationFeedback;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleListProvider);
    final myRequestsAsync = ref.watch(quotationMyRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B).withValues(alpha: 0.9),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreateTab(vehiclesAsync),
                      _buildRequestsTab(myRequestsAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COTIZACIONES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Envia una solicitud general para que talleres cercanos te respondan con propuestas.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue, width: 1.5),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'NUEVA SOLICITUD'),
          Tab(text: 'MIS SOLICITUDES'),
        ],
      ),
    );
  }

  Widget _buildCreateTab(AsyncValue<List<Vehicle>> vehiclesAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: 'Crear solicitud',
              subtitle:
                  'Describe el problema y envia la solicitud. Los talleres cercanos te responderan con sus propuestas.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  vehiclesAsync.when(
                    data: (vehicles) {
                      if (vehicles.isEmpty) {
                        return _buildEmptyNotice(
                          'No tienes vehiculos registrados para solicitar una cotizacion.',
                        );
                      }

                      if (_selectedVehicleId == null && vehicles.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedVehicleId == null) {
                            setState(() => _selectedVehicleId = vehicles.first.id);
                          }
                        });
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedVehicleId,
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: _inputDecoration('Vehiculo'),
                        items: vehicles
                            .map(
                              (vehicle) => DropdownMenuItem(
                                value: vehicle.id,
                                child: Text(
                                  '${vehicle.marca} ${vehicle.modelo} - ${vehicle.matricula}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedVehicleId = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Selecciona un vehiculo'
                            : null,
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.blueAccent),
                    ),
                    error: (err, _) => Text(
                      'Error al cargar vehiculos: $err',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _inputDecoration('Descripcion').copyWith(
                      hintText:
                          'Describe el problema del vehiculo y lo que necesita revisar el taller.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Describe el problema para enviar la solicitud';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observationsController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Observaciones').copyWith(
                      hintText: 'Referencia, horario o detalles adicionales.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLocationCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('BAJA'),
                        selected: _priority == 'BAJA',
                        onSelected: (_) => setState(() => _priority = 'BAJA'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('MEDIA'),
                        selected: _priority == 'MEDIA',
                        onSelected: (_) => setState(() => _priority = 'MEDIA'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('ALTA'),
                        selected: _priority == 'ALTA',
                        onSelected: (_) => setState(() => _priority = 'ALTA'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'ENVIAR SOLICITUD',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSectionCard(
              title: 'Como funciona',
              subtitle:
                  'La solicitud se envia a talleres cercanos compatibles. Tu eliges una propuesta solo cuando ya existan respuestas.',
              child: _buildEmptyNotice(
                'Solicitud enviada a talleres cercanos. Te notificaremos cuando recibas propuestas.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final hasLocation =
        _capturedLatitude != null && _capturedLongitude != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubicacion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _locationFeedback ??
                'Captura tu ubicacion actual para enviar la solicitud a talleres cercanos.',
            style: TextStyle(
              color: hasLocation ? Colors.greenAccent : Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCapturingLocation ? null : _loadCurrentLocation,
              icon: _isCapturingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                hasLocation ? 'Actualizar ubicacion' : 'Usar mi ubicacion actual',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.blueAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AsyncValue<List<QuotationRequestSummary>> myRequestsAsync) {
    return RefreshIndicator(
      color: Colors.blueAccent,
      onRefresh: () async {
        ref.invalidate(quotationMyRequestsProvider);
      },
      child: myRequestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No tienes solicitudes registradas',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return QuotationRequestCard(
                request: request,
                onTap: () {
                  context.push(
                    '/quotations/requests/${request.idSolicitudCotizacion}',
                    extra: request,
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error al cargar solicitudes: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Activa la ubicacion del dispositivo para continuar.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Necesitamos permiso de ubicacion para enviar la solicitud.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      setState(() {
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
        _locationFeedback = 'Ubicacion capturada correctamente.';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicacion capturada correctamente.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'No se pudo obtener la ubicacion actual.';
      setState(() {
        _locationFeedback = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un vehiculo'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_capturedLatitude == null || _capturedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes capturar tu ubicacion actual antes de enviar la solicitud.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ref
          .read(quotationCreateRequestControllerProvider.notifier)
          .createRequest(
            QuotationRequestCreate(
              vehicleId: _selectedVehicleId!,
              latitud: _capturedLatitude!,
              longitud: _capturedLongitude!,
              descripcion: _descriptionController.text.trim(),
              observaciones: _observationsController.text.trim().isEmpty
                  ? null
                  : _observationsController.text.trim(),
              prioridad: _priority,
              categoriaServicio: null,
              radiusKm: 10.0,
            ),
          );

      ref.invalidate(quotationMyRequestsProvider);
      _resetForm();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada a talleres cercanos. Te notificaremos cuando recibas propuestas.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear la solicitud: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedVehicleId = null;
      _priority = 'MEDIA';
      _capturedLatitude = null;
      _capturedLongitude = null;
      _locationFeedback = null;
    });
    _descriptionController.clear();
    _observationsController.clear();
  }
}
