import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../emergencies/domain/incident.dart';
import '../../../emergencies/data/emergency_repository.dart';
import '../../../emergencies/presentation/providers/emergency_provider.dart';
import '../../data/finance_repository.dart';

class StripePaymentScreen extends ConsumerStatefulWidget {
  final String incidentId;
  const StripePaymentScreen({super.key, required this.incidentId});

  @override
  ConsumerState<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends ConsumerState<StripePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;
  IncidentResponse? _incident;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIncidentDetails();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidentDetails() async {
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(emergencyRepositoryProvider);
      final incident = await repo.getIncident(widget.incidentId);
      if (mounted) {
        setState(() {
          _incident = incident;
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isFetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalToPay = _incident?.montoTotal ?? 0.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Pago con Tarjeta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isFetching
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3B82F6),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar detalles del cobro:\n$_errorMessage',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadIncidentDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('REINTENTAR', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjeta de Crédito Visual (Mock Premium)
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _cardNumberController,
                          _expiryController,
                          _cvcController,
                          _nameController
                        ]),
                        builder: (context, child) {
                          String cardNo = _cardNumberController.text.isEmpty
                              ? '•••• •••• •••• ••••'
                              : _cardNumberController.text;
                          String expiry = _expiryController.text.isEmpty
                              ? 'MM/YY'
                              : _expiryController.text;
                          String name = _nameController.text.isEmpty
                              ? 'NOMBRE DEL TITULAR'
                              : _nameController.text.toUpperCase();

                          return Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Smart Card',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Icon(
                                      Icons.payment,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      size: 32,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cardNo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'TITULAR',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontSize: 9,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'VENCE',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 9,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          expiry,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Formulario de Pago
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titular
                            const Text('Nombre en la Tarjeta', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ej. Juan Pérez',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese el titular' : null,
                            ),
                            const SizedBox(height: 16),

                            // Card Number
                            const Text('Número de Tarjeta (Stripe Test)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _cardNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(16),
                                _CardNumberFormatter(),
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '4242 4242 4242 4242',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: const Icon(Icons.credit_card_outlined, color: Colors.grey),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Ingrese el número';
                                final digits = val.replaceAll(' ', '');
                                if (digits.length != 16) return 'Número incompleto';
                                if (digits != '4242424242424242') {
                                  return 'Use la tarjeta de prueba 4242 4242 4242 4242';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Expiry & CVC
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Vencimiento', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _expiryController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                          _ExpiryFormatter(),
                                        ],
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'MM/YY',
                                          hintStyle: const TextStyle(color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF1E293B),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.isEmpty) return 'Requerido';
                                          if (val.length != 5) return 'Formato MM/YY';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CVC', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _cvcController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(3),
                                        ],
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: '123',
                                          hintStyle: const TextStyle(color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF1E293B),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.isEmpty) return 'Requerido';
                                          if (val.length != 3) return '3 dígitos';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Desglose final
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mano de obra', style: TextStyle(color: Colors.grey)),
                                Text('\$${(_incident?.manoDeObra ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Repuestos / Materiales', style: TextStyle(color: Colors.grey)),
                                Text('\$${(_incident?.repuestos ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(
                                  '\$${totalToPay.toStringAsFixed(2)} USD',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Botón
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading || totalToPay <= 0 ? null : _handleMockPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                )
                              : const Text(
                                  'CONFIRMAR PAGO',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'MODO SIMULACIÓN - TARJETA DE PRUEBAS STRIPE',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _handleMockPayment() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Simular procesamiento de pasarela por 2 segundos
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Notificar al backend de que se completó el pago simulado exitosamente
      await ref.read(financeRepositoryProvider).confirmMockPayment(widget.incidentId);

      // Completar incidente localmente y retornar estado limpio en cliente
      await ref.read(emergencyNotifierProvider.notifier).completeIncidentLocally(widget.incidentId);
      
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al finalizar el incidente: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 12),
            Text(
              '¡Pago Exitoso!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Su transacción ha sido procesada con éxito y confirmada por la pasarela de pagos. ¡Gracias por confiar en Smart Mechanic!',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.go('/');
            },
            child: const Text(
              'FINALIZAR',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
