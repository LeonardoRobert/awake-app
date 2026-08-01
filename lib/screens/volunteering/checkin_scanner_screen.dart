import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/shift_provider.dart';

/// Tela do lider: escaneia o QR Code pessoal do membro para
/// confirmar presenca (check-in) numa escala especifica.
class CheckinScannerScreen extends ConsumerStatefulWidget {
  final String escalaId;
  const CheckinScannerScreen({super.key, required this.escalaId});

  @override
  ConsumerState<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends ConsumerState<CheckinScannerScreen> {
  bool _processing = false;
  String? _feedback;
  bool _feedbackIsError = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _processing = true;
      _feedback = null;
    });

    try {
      final nome = await ref.read(checkinServiceProvider).checkInByQrCode(
            qrCodeId: code,
            escalaId: widget.escalaId,
          );
      ref.invalidate(signupsForShiftProvider(widget.escalaId));
      setState(() {
        _feedback = 'Check-in confirmado: $nome';
        _feedbackIsError = false;
      });
    } catch (e) {
      setState(() {
        _feedback = 'Nao foi possivel confirmar: $e';
        _feedbackIsError = true;
      });
    } finally {
      // pequena pausa antes de permitir nova leitura
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          if (_feedback != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: _feedbackIsError ? Colors.red.shade100 : Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_feedback!, textAlign: TextAlign.center),
                ),
              ),
            ),
          if (_processing)
            const Positioned(
              top: 16,
              right: 16,
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
