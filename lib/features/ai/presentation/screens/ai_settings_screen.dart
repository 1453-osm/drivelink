import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/core/services/connectivity_service.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/features/ai/data/datasources/ai_assistant_service.dart';
import 'package:drivelink/features/ai/data/datasources/gemini_source.dart';
import 'package:drivelink/features/ai/data/datasources/groq_source.dart';
import 'package:drivelink/features/ai/data/datasources/openrouter_source.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _geminiKeyController = TextEditingController();
  final _openRouterKeyController = TextEditingController();
  final _groqKeyController = TextEditingController();
  bool _geminiKeyObscured = true;
  bool _openRouterKeyObscured = true;
  bool _groqKeyObscured = true;
  String? _testResult;
  bool _testing = false;
  bool _loadingGeminiModels = false;
  bool _loadingOpenRouterModels = false;
  bool _loadingGroqModels = false;
  String? _geminiModelsError;
  String? _openRouterModelsError;
  String? _groqModelsError;
  List<GeminiModelInfo> _geminiModels = const [];
  List<OpenRouterModelInfo> _openRouterModels = const [];
  List<GroqModelInfo> _groqModels = const [];
  String _selectedGeminiModel = GeminiSource.defaultModel;
  String _selectedOpenRouterModel = OpenRouterSource.defaultModel;
  String _selectedGroqModel = GroqSource.defaultModel;
  String _selectedChatProvider = 'gemini';
  bool _ttsDownloading = false;
  String _ttsStatus = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(settingsRepositoryProvider);
      final geminiKey = await repo.get(SettingsKeys.geminiApiKey);
      final geminiModel = await repo.get(SettingsKeys.geminiModel);
      final openRouterKey = await repo.get(SettingsKeys.openRouterApiKey);
      final openRouterModel = await repo.get(SettingsKeys.openRouterModel);
      final groqKey = await repo.get(SettingsKeys.groqApiKey);
      final groqModel = await repo.get(SettingsKeys.groqModel);
      final chatProvider = await repo.getOrDefault(
        SettingsKeys.chatProvider,
        'gemini',
      );
      final normalizedChatProvider = switch (chatProvider) {
        'openrouter' => 'openrouter',
        'groq' => 'groq',
        _ => 'gemini',
      };
      final service = ref.read(aiAssistantServiceProvider);

      if (mounted) {
        setState(() {
          if (geminiKey != null) _geminiKeyController.text = geminiKey;
          if (openRouterKey != null) {
            _openRouterKeyController.text = openRouterKey;
          }
          if (groqKey != null) {
            _groqKeyController.text = groqKey;
          }
          if (geminiModel != null && geminiModel.isNotEmpty) {
            _selectedGeminiModel = geminiModel;
          }
          if (openRouterModel != null && openRouterModel.isNotEmpty) {
            _selectedOpenRouterModel = openRouterModel;
          }
          if (groqModel != null && groqModel.isNotEmpty) {
            _selectedGroqModel = groqModel;
          }
          _selectedChatProvider = normalizedChatProvider;
        });
      }

      service.setGeminiApiKey(_geminiKeyController.text.trim());
      service.setOpenRouterApiKey(_openRouterKeyController.text.trim());
      service.setGroqApiKey(_groqKeyController.text.trim());
      service.setGeminiModel(_selectedGeminiModel);
      service.setOpenRouterModel(_selectedOpenRouterModel);
      service.setGroqModel(_selectedGroqModel);
      service.setChatProvider(normalizedChatProvider);

      if (_geminiKeyController.text.trim().isNotEmpty) {
        await _refreshGeminiModels();
      } else if (mounted) {
        setState(() {
          _geminiModels = _mergedGeminiModels(const []);
        });
      }

      if (_openRouterKeyController.text.trim().isNotEmpty) {
        await _refreshOpenRouterModels();
      } else if (mounted) {
        setState(() {
          _openRouterModels = _mergedOpenRouterModels(const []);
        });
      }

      if (_groqKeyController.text.trim().isNotEmpty) {
        await _refreshGroqModels();
      } else if (mounted) {
        setState(() {
          _groqModels = _mergedGroqModels(const []);
        });
      }
    });
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openRouterKeyController.dispose();
    _groqKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAll({
    bool showSnackBar = true,
    bool refreshModels = true,
  }) async {
    final repo = ref.read(settingsRepositoryProvider);
    final service = ref.read(aiAssistantServiceProvider);
    final geminiKey = _geminiKeyController.text.trim();
    final openRouterKey = _openRouterKeyController.text.trim();
    final groqKey = _groqKeyController.text.trim();

    await repo.set(SettingsKeys.geminiApiKey, geminiKey);
    await repo.set(SettingsKeys.openRouterApiKey, openRouterKey);
    await repo.set(SettingsKeys.groqApiKey, groqKey);
    await repo.set(SettingsKeys.geminiModel, _selectedGeminiModel);
    await repo.set(SettingsKeys.openRouterModel, _selectedOpenRouterModel);
    await repo.set(SettingsKeys.groqModel, _selectedGroqModel);
    await repo.set(SettingsKeys.chatProvider, _selectedChatProvider);

    service.setGeminiApiKey(geminiKey);
    service.setOpenRouterApiKey(openRouterKey);
    service.setGroqApiKey(groqKey);
    service.setGeminiModel(_selectedGeminiModel);
    service.setOpenRouterModel(_selectedOpenRouterModel);
    service.setGroqModel(_selectedGroqModel);
    service.setChatProvider(_selectedChatProvider);

    if (refreshModels &&
        _selectedChatProvider == 'gemini' &&
        geminiKey.isNotEmpty) {
      await _refreshGeminiModels(showFeedback: false);
    } else if (refreshModels &&
        _selectedChatProvider == 'openrouter' &&
        openRouterKey.isNotEmpty) {
      await _refreshOpenRouterModels(showFeedback: false);
    } else if (refreshModels &&
        _selectedChatProvider == 'groq' &&
        groqKey.isNotEmpty) {
      await _refreshGroqModels(showFeedback: false);
    }

    if (mounted && showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ayarlar kaydedildi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (_testing) return;

    setState(() {
      _testing = true;
      _testResult = null;
    });

    await _saveAll(showSnackBar: false, refreshModels: false);

    final service = ref.read(aiAssistantServiceProvider);
    final error = await switch (_selectedChatProvider) {
      'openrouter' => service.openRouter.testConnection(
        model: _selectedOpenRouterModel,
      ),
      'groq' => service.groq.testConnection(model: _selectedGroqModel),
      _ => service.gemini.testConnection(model: _selectedGeminiModel),
    };

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = error ?? 'Baglanti basarili!';
      });
    }
  }

  Future<void> _refreshGeminiModels({bool showFeedback = false}) async {
    final geminiKey = _geminiKeyController.text.trim();
    if (geminiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _geminiModels = _mergedGeminiModels(const []);
          _geminiModelsError =
              'API anahtarini girdikten sonra desteklenen modeller yuklenir.';
        });
      }
      return;
    }

    final service = ref.read(aiAssistantServiceProvider);
    service.setGeminiApiKey(geminiKey);
    service.setGeminiModel(_selectedGeminiModel);

    if (mounted) {
      setState(() {
        _loadingGeminiModels = true;
        _geminiModelsError = null;
      });
    }

    final models = await service.gemini.listAvailableModels();
    if (!mounted) return;

    setState(() {
      _loadingGeminiModels = false;
      _geminiModels = _mergedGeminiModels(models);
      _geminiModelsError = models.isEmpty
          ? 'Model listesi alinamadi. Anahtari kaydedip tekrar dene.'
          : null;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            models.isEmpty
                ? 'Model listesi alinamadi'
                : '${models.length} model yuklendi',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _refreshOpenRouterModels({bool showFeedback = false}) async {
    final openRouterKey = _openRouterKeyController.text.trim();
    if (openRouterKey.isEmpty) {
      if (mounted) {
        setState(() {
          _openRouterModels = _mergedOpenRouterModels(const []);
          _openRouterModelsError =
              'API anahtarini girdikten sonra Grok, Qwen ve ucretsiz modeller yuklenir.';
        });
      }
      return;
    }

    final service = ref.read(aiAssistantServiceProvider);
    service.setOpenRouterApiKey(openRouterKey);
    service.setOpenRouterModel(_selectedOpenRouterModel);

    if (mounted) {
      setState(() {
        _loadingOpenRouterModels = true;
        _openRouterModelsError = null;
      });
    }

    final models = await service.openRouter.listAvailableModels();
    if (!mounted) return;

    setState(() {
      _loadingOpenRouterModels = false;
      _openRouterModels = _mergedOpenRouterModels(models);
      _openRouterModelsError = models.isEmpty
          ? 'Grok, Qwen veya ucretsiz OpenRouter modeli bulunamadi. Anahtari kaydedip tekrar dene.'
          : null;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            models.isEmpty
                ? 'OpenRouter modeli alinamadi'
                : '${models.length} OpenRouter modeli yuklendi',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _refreshGroqModels({bool showFeedback = false}) async {
    final groqKey = _groqKeyController.text.trim();
    if (groqKey.isEmpty) {
      if (mounted) {
        setState(() {
          _groqModels = _mergedGroqModels(const []);
          _groqModelsError =
              'API anahtarini girdikten sonra Groq modelleri yuklenir.';
        });
      }
      return;
    }

    final service = ref.read(aiAssistantServiceProvider);
    service.setGroqApiKey(groqKey);
    service.setGroqModel(_selectedGroqModel);

    if (mounted) {
      setState(() {
        _loadingGroqModels = true;
        _groqModelsError = null;
      });
    }

    final models = await service.groq.listAvailableModels();
    if (!mounted) return;

    setState(() {
      _loadingGroqModels = false;
      _groqModels = _mergedGroqModels(models);
      _groqModelsError = models.isEmpty
          ? 'Groq model listesi alinamadi. Anahtari kaydedip tekrar dene.'
          : null;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            models.isEmpty
                ? 'Groq modeli alinamadi'
                : '${models.length} Groq modeli yuklendi',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  List<GeminiModelInfo> _mergedGeminiModels(List<GeminiModelInfo> models) {
    final merged = [...models];
    final hasSelected = merged.any((model) => model.id == _selectedGeminiModel);

    if (!hasSelected) {
      merged.insert(
        0,
        GeminiModelInfo(
          id: _selectedGeminiModel,
          displayName: _selectedGeminiModel,
          description: 'Kayitli model',
        ),
      );
    }

    return merged;
  }

  List<OpenRouterModelInfo> _mergedOpenRouterModels(
    List<OpenRouterModelInfo> models,
  ) {
    final merged = [...models];
    final hasSelected = merged.any(
      (model) => model.id == _selectedOpenRouterModel,
    );

    if (!hasSelected) {
      merged.insert(
        0,
        OpenRouterModelInfo(
          id: _selectedOpenRouterModel,
          displayName: _selectedOpenRouterModel,
          description: 'Kayitli model',
        ),
      );
    }

    return merged;
  }

  List<GroqModelInfo> _mergedGroqModels(List<GroqModelInfo> models) {
    final merged = [...models];
    final hasSelected = merged.any((model) => model.id == _selectedGroqModel);

    if (!hasSelected) {
      merged.insert(
        0,
        GroqModelInfo(
          id: _selectedGroqModel,
          displayName: _selectedGroqModel,
        ),
      );
    }

    return merged;
  }

  GroqModelInfo? _currentGroqModelInfo() {
    for (final model in _groqModels) {
      if (model.id == _selectedGroqModel) return model;
    }
    return null;
  }

  GeminiModelInfo? _currentGeminiModelInfo() {
    for (final model in _geminiModels) {
      if (model.id == _selectedGeminiModel) return model;
    }
    return null;
  }

  OpenRouterModelInfo? _currentOpenRouterModelInfo() {
    for (final model in _openRouterModels) {
      if (model.id == _selectedOpenRouterModel) return model;
    }
    return null;
  }

  String _formatTokenLimit(int? value) {
    if (value == null) return '-';
    if (value >= 1000000 && value % 1000000 == 0) {
      return '${value ~/ 1000000}M';
    }
    if (value >= 1000 && value % 1000 == 0) {
      return '${value ~/ 1000}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        ref.watch(aiStateProvider).valueOrNull ?? const AiAssistantSnapshot();
    final service = ref.read(aiAssistantServiceProvider);
    final online =
        ref.watch(isOnlineProvider).valueOrNull ??
        ref.read(connectivityServiceProvider).isOnline;
    final selectedGeminiInfo = _currentGeminiModelInfo();
    final selectedOpenRouterInfo = _currentOpenRouterModelInfo();
    final selectedGroqInfo = _currentGroqModelInfo();
    final isOpenRouterSelected = _selectedChatProvider == 'openrouter';
    final isGroqSelected = _selectedChatProvider == 'groq';
    final selectedProviderLabel = isOpenRouterSelected
        ? 'OpenRouter ($_selectedOpenRouterModel)'
        : isGroqSelected
        ? 'Groq ($_selectedGroqModel)'
        : 'Gemini ($_selectedGeminiModel)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'AI Ayarlari',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsivePageBody(
        maxWidth: 1024,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: 'Ses Tanima'),
            _StatusTile(
              icon: Icons.mic,
              title: 'Vosk Turkce Model',
              subtitle: _voskStatus(snapshot.state),
              color:
                  snapshot.state == AssistantState.ready ||
                      snapshot.state == AssistantState.idle
                  ? AppColors.success
                  : snapshot.state == AssistantState.error
                  ? AppColors.error
                  : AppColors.warning,
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Wake Word'),
            _ToggleTile(
              icon: Icons.hearing,
              title: '"Abidin" Wake Word',
              subtitle: snapshot.wakeWordActive
                  ? 'Dinliyor - "abidin" deyince aktiflesir'
                  : 'Kapali',
              value: snapshot.wakeWordActive,
              onChanged: (val) => service.toggleWakeWord(val),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Sohbet Servisi'),
            _ChatProviderCard(
              value: _selectedChatProvider,
              onChanged: (value) {
                if (value == null) return;
                final shouldLoadGemini =
                    value == 'gemini' &&
                    _geminiModels.isEmpty &&
                    _geminiKeyController.text.trim().isNotEmpty;
                final shouldLoadOpenRouter =
                    value == 'openrouter' &&
                    _openRouterModels.isEmpty &&
                    _openRouterKeyController.text.trim().isNotEmpty;
                final shouldLoadGroq =
                    value == 'groq' &&
                    _groqModels.isEmpty &&
                    _groqKeyController.text.trim().isNotEmpty;
                setState(() {
                  _selectedChatProvider = value;
                  _testResult = null;
                });
                if (shouldLoadGemini) {
                  _refreshGeminiModels();
                } else if (shouldLoadOpenRouter) {
                  _refreshOpenRouterModels();
                } else if (shouldLoadGroq) {
                  _refreshGroqModels();
                }
              },
            ),
            const SizedBox(height: 12),
            _ApiKeyCard(
              title: 'Gemini API Anahtari',
              controller: _geminiKeyController,
              obscured: _geminiKeyObscured,
              onToggleObscure: () =>
                  setState(() => _geminiKeyObscured = !_geminiKeyObscured),
              hint: 'AIza...',
              instructions:
                  'ai.google.dev > Get API Key\nAnahtari kaydedince desteklenen modeller API uzerinden yuklenir.',
              infoText:
                  'Tum generateContent destekli Gemini ve Gemma modelleri listelenir.',
            ),
            const SizedBox(height: 12),
            _ApiKeyCard(
              title: 'OpenRouter API Anahtari',
              controller: _openRouterKeyController,
              obscured: _openRouterKeyObscured,
              onToggleObscure: () => setState(
                () => _openRouterKeyObscured = !_openRouterKeyObscured,
              ),
              hint: 'sk-or-v1-...',
              instructions:
                  'openrouter.ai > Keys\nSohbet saglayicisi olarak OpenRouter secilirse bu anahtar kullanilir.',
              infoText:
                  'Grok ve Qwen modelleri ustte tutulur; diger seceneklerde ucretsiz modeller listelenir.',
            ),
            const SizedBox(height: 12),
            _ApiKeyCard(
              title: 'Groq API Anahtari',
              controller: _groqKeyController,
              obscured: _groqKeyObscured,
              onToggleObscure: () =>
                  setState(() => _groqKeyObscured = !_groqKeyObscured),
              hint: 'gsk_...',
              instructions:
                  'console.groq.com > API Keys\nSohbet saglayicisi olarak Groq secilirse bu anahtar kullanilir.',
              infoText:
                  'Groq hesabinin erisebildigi tum modeller listelenir, istediginizi secebilirsiniz.',
            ),
            const SizedBox(height: 8),
            if (isGroqSelected) ...[
              _GroqModelCard(
                models: _groqModels,
                selectedModel: _selectedGroqModel,
                selectedInfo: selectedGroqInfo,
                loading: _loadingGroqModels,
                errorText: _groqModelsError,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedGroqModel = value;
                    _testResult = null;
                  });
                },
                onRefresh: _loadingGroqModels
                    ? null
                    : () => _refreshGroqModels(showFeedback: true),
              ),
              const SizedBox(height: 8),
            ] else if (!isOpenRouterSelected) ...[
              _GeminiModelCard(
                models: _geminiModels,
                selectedModel: _selectedGeminiModel,
                selectedInfo: selectedGeminiInfo,
                loading: _loadingGeminiModels,
                errorText: _geminiModelsError,
                tokenSummary:
                    'Girdi: ${_formatTokenLimit(selectedGeminiInfo?.inputTokenLimit)} | Cikti: ${_formatTokenLimit(selectedGeminiInfo?.outputTokenLimit)}',
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedGeminiModel = value;
                    _testResult = null;
                  });
                },
                onRefresh: _loadingGeminiModels
                    ? null
                    : () => _refreshGeminiModels(showFeedback: true),
              ),
              const SizedBox(height: 8),
            ] else ...[
              _OpenRouterModelCard(
                models: _openRouterModels,
                selectedModel: _selectedOpenRouterModel,
                selectedInfo: selectedOpenRouterInfo,
                loading: _loadingOpenRouterModels,
                errorText: _openRouterModelsError,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedOpenRouterModel = value;
                    _testResult = null;
                  });
                },
                onRefresh: _loadingOpenRouterModels
                    ? null
                    : () => _refreshOpenRouterModels(showFeedback: true),
              ),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _saveAll(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _testing ? null : _testConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        _testing ? 'Test ediliyor...' : 'Baglanti Testi',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult == 'Baglanti basarili!'
                        ? AppColors.success
                        : AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Ses Motoru'),
            Builder(
              builder: (context) {
                final tts = ref.read(ttsServiceProvider);
                final sherpaReady = tts.isSherpaReady;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusTile(
                      icon: Icons.record_voice_over,
                      title: sherpaReady
                          ? 'Piper Fahrettin (aktif)'
                          : 'Android Sistem Sesi',
                      subtitle: sherpaReady
                          ? 'Dogal Turkce ses, offline'
                          : 'Robotik ses - Piper modelini indirerek iyilestir',
                      color: sherpaReady
                          ? AppColors.success
                          : AppColors.textDisabled,
                    ),
                    if (!sherpaReady) ...[
                      const SizedBox(height: 8),
                      if (_ttsDownloading)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _ttsStatus,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton.icon(
                            onPressed: _extractTtsModel,
                            icon: const Icon(Icons.build, size: 16),
                            label: const Text('Ses Motorunu Hazirla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Internet Baglantisi'),
            _StatusTile(
              icon: online ? Icons.wifi : Icons.wifi_off,
              title: online ? 'Cevrimici' : 'Cevrimdisi',
              subtitle: online
                  ? 'Sohbet ozelligi kullanilabilir'
                  : 'Komutlar ve arac sorulari yine calisir',
              color: online ? AppColors.success : AppColors.textDisabled,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                '- Telefonundan WiFi hotspot ac, bu cihazi baglat\n'
                '- Bluetooth tethering: Telefon > Hotspot > Bluetooth\n'
                '- USB WiFi dongle kullanabilirsin',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                onPressed: _openWifiSettings,
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('WiFi Ayarlarini Ac'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Bilgi'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow('Ses tanima', 'Vosk (offline Turkce)'),
                  _InfoRow('Wake word', '"Abidin" (Vosk grammar)'),
                  _InfoRow(
                    'Sohbet',
                    snapshot.chatAvailable
                        ? selectedProviderLabel
                        : online
                        ? 'API anahtari gerekli'
                        : 'Cevrimdisi',
                  ),
                  _InfoRow('Komutlar', 'Her zaman calisir (offline)'),
                  _InfoRow('TTS', 'Android Turkce'),
                  const SizedBox(height: 8),
                  Text(
                    'Komutlar ve arac sorulari internet olmadan calisir. '
                    'Sohbet icin internet + API anahtari gerekir.',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractTtsModel() async {
    if (_ttsDownloading) return;
    setState(() {
      _ttsDownloading = true;
      _ttsStatus = 'Hazirlaniyor...';
    });

    final tts = ref.read(ttsServiceProvider);
    final ok = await tts.sherpaEngine.extractModel(
      onStatus: (status) {
        if (mounted) setState(() => _ttsStatus = status);
      },
    );

    if (ok) {
      await tts.sherpaEngine.initialize();
    }

    if (mounted) {
      setState(() => _ttsDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Ses motoru hazir!' : 'Hazirlama basarisiz'),
        ),
      );
    }
  }

  void _openWifiSettings() {
    const platform = MethodChannel('com.drivelink.drivelink/settings');
    platform.invokeMethod('openWifiSettings').catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WiFi ayarlarini manuel olarak acin')),
        );
      }
    });
  }

  String _voskStatus(AssistantState state) {
    return switch (state) {
      AssistantState.idle => 'Baslatilmadi',
      AssistantState.initializing => 'Yukleniyor...',
      AssistantState.ready => 'Hazir',
      AssistantState.listening => 'Dinliyor...',
      AssistantState.processing => 'Isliyor...',
      AssistantState.speaking => 'Konusuyor...',
      AssistantState.error => 'Hata',
    };
  }
}

class _ChatProviderCard extends StatelessWidget {
  const _ChatProviderCard({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktif Saglayici',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              isDense: true,
            ),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
              DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter')),
              DropdownMenuItem(value: 'groq', child: Text('Groq')),
            ],
            onChanged: onChanged,
          ),
          const SizedBox(height: 6),
          Text(
            'Kaydet ve test et islemleri secili saglayiciya gore calisir.',
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  const _ApiKeyCard({
    required this.title,
    required this.controller,
    required this.obscured,
    required this.onToggleObscure,
    required this.hint,
    required this.instructions,
    required this.infoText,
  });

  final String title;
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final String hint;
  final String instructions;
  final String infoText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscured,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  obscured ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            instructions,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          Text(
            infoText,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeminiModelCard extends StatelessWidget {
  const _GeminiModelCard({
    required this.models,
    required this.selectedModel,
    required this.selectedInfo,
    required this.loading,
    required this.errorText,
    required this.tokenSummary,
    required this.onChanged,
    required this.onRefresh,
  });

  final List<GeminiModelInfo> models;
  final String selectedModel;
  final GeminiModelInfo? selectedInfo;
  final bool loading;
  final String? errorText;
  final String tokenSummary;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final selectedValue = models.any((model) => model.id == selectedModel)
        ? selectedModel
        : (models.isNotEmpty ? models.first.id : null);
    final info = selectedInfo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gemini Modeli',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(loading ? 'Yukleniyor' : 'Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedValue,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              isDense: true,
            ),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: models
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.id, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: models.isEmpty ? null : onChanged,
          ),
          const SizedBox(height: 8),
          Text(
            selectedInfo?.displayName ?? selectedValue ?? selectedModel,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tokenSummary,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            selectedInfo?.supportsThinking == true
                ? 'Thinking destegi var'
                : 'Thinking bilgisi yok veya desteklenmiyor',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          if (selectedInfo?.description != null &&
              selectedInfo!.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              selectedInfo!.description!,
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Liste Gemini API hesabinin gorebildigi tum generateContent modellerinden gelir.',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenRouterModelCard extends StatelessWidget {
  const _OpenRouterModelCard({
    required this.models,
    required this.selectedModel,
    required this.selectedInfo,
    required this.loading,
    required this.errorText,
    required this.onChanged,
    required this.onRefresh,
  });

  final List<OpenRouterModelInfo> models;
  final String selectedModel;
  final OpenRouterModelInfo? selectedInfo;
  final bool loading;
  final String? errorText;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final selectedValue = models.any((model) => model.id == selectedModel)
        ? selectedModel
        : (models.isNotEmpty ? models.first.id : null);
    final info = selectedInfo;
    final contextLength = info?.contextLength;
    final isFree = info?.isFree;
    final description = info?.description;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'OpenRouter Modeli',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(loading ? 'Yukleniyor' : 'Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedValue,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              isDense: true,
            ),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: models
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.id, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: models.isEmpty ? null : onChanged,
          ),
          const SizedBox(height: 8),
          Text(
            info?.displayName ?? selectedValue ?? selectedModel,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contextLength != null
                ? 'Baglam: $contextLength'
                : 'Baglam bilgisi yok',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            isFree == null
                ? 'Fiyat bilgisi yok'
                : isFree
                ? 'Ucretsiz model'
                : 'Ucretli model',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Grok ve Qwen modelleri sabit olarak ustte kalir. Diger seceneklerde ucretsiz modeller listelenir.',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.success : AppColors.textDisabled;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success.withValues(alpha: 0.5),
            activeThumbColor: AppColors.success,
            inactiveTrackColor: AppColors.surfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
