import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vehicle.dart';
import '../services/fuel_app_state.dart';
import '../theme/app_theme.dart';
import 'import_preview_screen.dart';

/// Screen where user inputs unstructured text with full descriptions and examples.
class TextImportScreen extends StatefulWidget {
  final Vehicle vehicle;
  final FuelAppState appState;

  const TextImportScreen({
    super.key,
    required this.vehicle,
    required this.appState,
  });

  @override
  State<TextImportScreen> createState() => _TextImportScreenState();
}

class _TextImportScreenState extends State<TextImportScreen> {
  final _textController = TextEditingController();

  final List<String> _sampleSnippets = const [
    'Filled 45.2 L for \$82.50 at Shell on 15-Oct-26, odo 54200km',
    'Chevron 12.0 gal for \$42.00, odometer 120500 Premium 93 full tank',
    '2026-10-10, 50000km, 40L, \$72, BP\n2026-10-16, 50520km, 42L, \$76, Exxon',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasted text from clipboard')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
    }
  }

  void _parseAndReview() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or paste some text first.')),
      );
      return;
    }

    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => ImportPreviewScreen(
          vehicle: widget.vehicle,
          appState: widget.appState,
          initialText: rawText,
        ),
      ),
    ).then((accepted) {
      if (accepted == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data from Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Description Card
          // 1. Description Card (Maximum 1 paragraph, non-technical simple words)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceColor(context) : const Color(0xFFF5FAF6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.borderColor(context) : const Color(0xFF86EFAC),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Easily add your past fill-ups all at once. Paste your notes or receipts below, match your details, and review everything before saving to your records.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Example Chips
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              const Text('Quick Example Templates:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('SMS / Receipt Note', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _textController.text = _sampleSnippets[0];
                    });
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.local_gas_station_outlined, size: 14),
                  label: const Text('Gallons / US Style', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _textController.text = _sampleSnippets[1];
                    });
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.view_headline, size: 14),
                  label: const Text('Multi-line Batch', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _textController.text = _sampleSnippets[2];
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Text Input Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Raw Unstructured Text:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.content_paste, size: 20),
                            tooltip: 'Paste from Clipboard',
                            onPressed: _pasteFromClipboard,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            tooltip: 'Clear',
                            onPressed: () => setState(() => _textController.clear()),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Paste or type unstructured text here...\n\nExample:\nFilled 42.5 L for \$78.20 at Shell on 15-Oct-26, odo 54200km\n\n(You can paste single sentences or multi-line notes)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF8FAFC),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Primary Parse Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _parseAndReview,
            icon: const Icon(Icons.grid_on, size: 20),
            label: const Text(
              'Parse & Review in Data Grid',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

