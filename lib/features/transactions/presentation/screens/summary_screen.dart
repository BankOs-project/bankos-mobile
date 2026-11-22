import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../accounts/presentation/providers/bottom_nav_provider.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/transaction_models.dart';
import '../providers/transactions_providers.dart';
import '../widgets/receipt_ticket_card.dart';

typedef HistoricalReceipt = ({AuthSession session, OperationReceipt receipt});

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, this.historicalReceipt});

  final HistoricalReceipt? historicalReceipt;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt(OperationReceipt record) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _captureReceiptPng();
      final text = record.toShareableText();

      if (pngBytes != null) {
        final file = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'comprobante_${record.id}.png',
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [file],
            text: text,
            subject: 'Comprobante BankOs · ${record.id}',
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Comprobante BankOs · ${record.id}'),
        );
      }
    } catch (_) {
      // Fallback limpio al portapapeles si el entorno no soporta share sheet.
      await Clipboard.setData(ClipboardData(text: record.toShareableText()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprobante copiado al portapapeles.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<Uint8List?> _captureReceiptPng() async {
    final renderObject = _receiptBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 3.0);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _copyReceiptText(OperationReceipt record) async {
    await Clipboard.setData(ClipboardData(text: record.toShareableText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen del comprobante copiado al portapapeles.'),
      ),
    );
  }

  void _openOperations() {
    ref.read(bottomNavIndexProvider.notifier).state = 2;
    context.go('/operations');
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.historicalReceipt;
    final record = selected == null
        ? ref.watch(activeReceiptProvider)
        : identical(selected.session, ref.watch(activeSessionProvider))
        ? selected.receipt
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              ref.read(bottomNavIndexProvider.notifier).state = 3;
              context.go('/history');
            }
          },
        ),
        title: const Text('Comprobante'),
        actions: [
          if (record != null)
            IconButton(
              tooltip: 'Copiar resumen',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () => _copyReceiptText(record),
            ),
        ],
      ),
      body: SafeArea(
        child: record == null
            ? _EmptyReceiptState(onNewTransfer: _openOperations)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReceiptTicketCard(
                      record: record,
                      boundaryKey: _receiptBoundaryKey,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      key: const Key('share_receipt_button'),
                      onPressed: _isSharing
                          ? null
                          : () => _shareReceipt(record),
                      icon: _isSharing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: Text(
                        _isSharing
                            ? 'Preparando comprobante...'
                            : 'Compartir comprobante',
                      ),
                    ),
                    if (selected == null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('go_to_history_button'),
                              onPressed: () {
                                ref
                                        .read(bottomNavIndexProvider.notifier)
                                        .state =
                                    3;
                                context.go('/history');
                              },
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Movimientos'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('go_to_dashboard_button'),
                              onPressed: () {
                                ref
                                        .read(bottomNavIndexProvider.notifier)
                                        .state =
                                    0;
                                context.go('/dashboard');
                              },
                              icon: const Icon(Icons.home_outlined, size: 18),
                              label: const Text('Inicio'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _openOperations,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Realizar otra operación'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyReceiptState extends StatelessWidget {
  final VoidCallback onNewTransfer;

  const _EmptyReceiptState({required this.onNewTransfer});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            const Text(
              'Aún no hay comprobantes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando el servidor confirme una operación, podrás consultar su comprobante aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onNewTransfer,
              child: const Text('Realizar una operación'),
            ),
          ],
        ),
      ),
    );
  }
}
