import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/ai/data/datasources/ai_assistant_service.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';
import 'package:drivelink/features/ai/presentation/widgets/ai_response_card.dart';
import 'package:drivelink/features/ai/presentation/widgets/connectivity_indicator.dart';
import 'package:drivelink/features/ai/presentation/widgets/voice_indicator.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ensure AI is initialized
    Future.microtask(() => ref.read(aiInitProvider));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    final service = ref.read(aiAssistantServiceProvider);
    await service.processText(text);
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(aiStateProvider).valueOrNull ??
        const AiAssistantSnapshot();
    final service = ref.read(aiAssistantServiceProvider);

    // Navigate on response if needed
    ref.listen(aiStateProvider, (prev, next) {
      final snap = next.valueOrNull;
      if (snap?.lastResponse?.navigateTo != null &&
          snap?.state == AssistantState.ready) {
        final prevResponse = prev?.valueOrNull?.lastResponse;
        if (snap!.lastResponse != prevResponse) {
          context.push(snap.lastResponse!.navigateTo!);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.smart_toy, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Abidin',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
            const Spacer(),
            const ConnectivityIndicator(),
            const SizedBox(width: 6),
            _StatusChip(state: snapshot.state),
          ],
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Response history ───────────────────────────────────
          Expanded(
            child: snapshot.history.isEmpty
                ? _EmptyState(onHintTap: _sendText)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    itemCount: snapshot.history.length,
                    itemBuilder: (context, index) {
                      return AiResponseCard(response: snapshot.history[index]);
                    },
                  ),
          ),

          // ── Current state area ────────────────────────────────
          _BottomPanel(
            snapshot: snapshot,
            textController: _textController,
            onActivate: () => service.activate(),
            onCancel: () => service.cancel(),
            onSendText: _sendText,
          ),
        ],
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
  final AssistantState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      AssistantState.idle => ('Hazir degil', AppColors.textDisabled),
      AssistantState.initializing => ('Yukleniyor', AppColors.warning),
      AssistantState.ready => ('Hazir', AppColors.success),
      AssistantState.listening => ('Dinliyor', AppColors.primary),
      AssistantState.processing => ('Isliyor', AppColors.accent),
      AssistantState.speaking => ('Konusuyor', AppColors.info),
      AssistantState.error => ('Hata', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onHintTap});
  final ValueChanged<String> onHintTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                color: AppColors.textDisabled, size: 64),
            const SizedBox(height: 16),
            Text(
              'Abidin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Yol arkadasin',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mikrofona basarak sesli komut verebilir\n'
              'ya da asagiya yazabilirsin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _HintChips(onTap: onHintTap),
          ],
        ),
      ),
    );
  }
}

// ── Hint chips ─────────────────────────────────────────────────────────

class _HintChips extends StatelessWidget {
  const _HintChips({required this.onTap});
  final ValueChanged<String> onTap;

  static const _hints = [
    'Eve git',
    'Hizim kac?',
    'Muzik ac',
    'Motor nasil?',
    'Arac durumu',
    'En yakin benzinlik',
    'Merhaba',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _hints
          .map((hint) => GestureDetector(
                onTap: () => onTap(hint),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Bottom panel ───────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.snapshot,
    required this.textController,
    required this.onActivate,
    required this.onCancel,
    required this.onSendText,
  });

  final AiAssistantSnapshot snapshot;
  final TextEditingController textController;
  final VoidCallback onActivate;
  final VoidCallback onCancel;
  final ValueChanged<String> onSendText;

  @override
  Widget build(BuildContext context) {
    final isListening = snapshot.state == AssistantState.listening;
    final isProcessing = snapshot.state == AssistantState.processing;
    final isSpeaking = snapshot.state == AssistantState.speaking;
    final isActive = isListening || isProcessing || isSpeaking;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transcript display
            if (isActive) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snapshot.partialTranscript ?? snapshot.finalTranscript ?? '...',
                  style: TextStyle(
                    color: isListening
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontStyle:
                        isListening ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Voice indicator + text input row
            Row(
              children: [
                // Voice button
                VoiceIndicator(
                  isListening: isListening,
                  isProcessing: isProcessing || isSpeaking,
                  size: 56,
                  onTap: isActive ? onCancel : onActivate,
                ),
                const SizedBox(width: 8),

                // Text input
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            enabled: !isActive,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Abidin\'e bir sey sor...',
                              hintStyle: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              border: InputBorder.none,
                            ),
                            onSubmitted: onSendText,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send,
                              color: AppColors.primary, size: 20),
                          onPressed: isActive
                              ? null
                              : () => onSendText(textController.text),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
