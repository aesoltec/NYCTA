import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Signature manuscrite à main levée, plein écran.
/// Renvoie les octets PNG via [onDone] ; null si annulé.
class SignaturePad extends StatefulWidget {
  final ValueChanged<Uint8List?> onDone;
  const SignaturePad({super.key, required this.onDone});

  static Future<void> ouvrir(BuildContext context, ValueChanged<Uint8List?> onDone) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignaturePad(onDone: onDone)),
    );
  }

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF1A2B4C),
    exportBackgroundColor: Colors.transparent,
  );
  bool _exporting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    setState(() => _exporting = true);
    Uint8List? bytes;
    try {
      bytes = await _controller.toPngBytes();
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signez d'abord dans le cadre")));
      return;
    }
    Navigator.of(context).pop();
    widget.onDone(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature à main levée'),
        actions: [
          IconButton(
            tooltip: 'Effacer',
            icon: const Icon(Icons.undo_rounded),
            onPressed: () => _controller.clear(),
          ),
        ],
      ),
      body: Column(children: [
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDone(null);
                },
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: _exporting
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: const Text('Utiliser cette signature'),
                onPressed: _exporting ? null : _valider,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
