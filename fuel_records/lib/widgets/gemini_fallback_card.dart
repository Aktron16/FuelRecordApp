import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_cleaner_constants.dart';

/// Clean, production-ready fallback card guiding users to Gemini / ChatGPT
/// when local parsers fail or data is too unstructured.
class GeminiFallbackCard extends StatefulWidget {
  final ValueChanged<String> onParseCsv;
  final bool isHighlighted;

  const GeminiFallbackCard({
    super.key,
    required this.onParseCsv,
    this.isHighlighted = false,
  });

  @override
  State<GeminiFallbackCard> createState() => _GeminiFallbackCardState();
}

class _GeminiFallbackCardState extends State<GeminiFallbackCard> {
  final TextEditingController _pasteController = TextEditingController();
  bool _isExpanded = true;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _copyPromptAndOpenGemini(BuildContext context) async {
    // 1. Copy prompt to system clipboard
    await Clipboard.setData(const ClipboardData(text: kGeminiCleanerPrompt));

    // 2. Show guidance SnackBar
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Instructions copied! Paste (Ctrl+V / Cmd+V) into Gemini, then send your messy data.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Color(0xFF1E3A8A),
      ),
    );

    // 3. Launch external browser / Gemini mobile app
    final uri = Uri.parse(kGeminiWebUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      // Fallback if browser launching fails
    }
  }

  Future<void> _openChatGpt(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kGeminiCleanerPrompt));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt copied and opening ChatGPT...'),
        duration: Duration(seconds: 3),
      ),
    );

    final uri = Uri.parse(getChatGptUrl());
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _pasteController.text = data.text!;
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

  void _triggerParse() {
    final rawInput = _pasteController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste the CSV data from Gemini first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Sanitize fences, invisible unicode, and noise
    final sanitized = cleanMarkdownFences(rawInput);
    if (sanitized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not extract CSV content. Ensure the text contains table rows.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    widget.onParseCsv(sanitized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = widget.isHighlighted
        ? const Color(0xFFF59E0B)
        : (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE));

    final cardBg = isDark
        ? (widget.isHighlighted ? const Color(0xFF272118) : const Color(0xFF1B2232))
        : (widget.isHighlighted ? const Color(0xFFFFFBEB) : const Color(0xFFF0F7FF));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: widget.isHighlighted ? 1.8 : 1.2),
        boxShadow: widget.isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Clean with AI',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Messy notes, SMS alerts, or receipts? Let AI format it.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Explanation Description
                  Text(
                    'If our built-in parser cannot read your format, tap below to copy our strict formatting prompt and open Gemini. Simply paste your raw fuel notes or receipt text to Gemini, then copy its output back here.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Required Disclaimer & Warning Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF382315) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF78350F) : const Color(0xFFFCD34D),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.privacy_tip_outlined, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Disclaimer: We are not responsible for any external data leaks, privacy disclosures, or third-party AI processing issues. Review your records carefully before accepting.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Step 1: Copy Prompt & Open Gemini / ChatGPT
                  const Text(
                    'Step 1: Get Clean CSV from AI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _copyPromptAndOpenGemini(context),
                          icon: const Icon(Icons.copy_all, size: 16),
                          label: const Text(
                            'Copy Prompt & Open Gemini',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openChatGpt(context),
                          icon: const Icon(Icons.open_in_new, size: 15),
                          label: const Text(
                            'ChatGPT',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Step 2: Paste Cleaned Data Here
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Step 2: Paste Cleaned Data Here',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste, size: 14),
                        label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _pasteController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Paste Gemini output code block here...\ne.g.\ndate,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes\n2026-10-15,84500,42.5,2.50,106.25,Shell,',
                      hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _triggerParse,
                    icon: const Icon(Icons.table_rows_outlined, size: 18),
                    label: const Text(
                      'Parse Pasted CSV',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
