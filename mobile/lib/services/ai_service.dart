import 'package:llamadart/llamadart.dart';

class AiService {
  static const modelSource =
      'hf://Qwen/Qwen2.5-1.5B-Instruct-GGUF/qwen2.5-1.5b-instruct-q4_k_m.gguf';

  LlamaEngine? _engine;
  ChatSession? _session;
  Future<void>? _loading;

  bool get isReady => _session != null;

  Future<void> _loadModel(void Function(double progress)? onProgress) async {
    final engine = await LlamaEngine.load(
      LlamaModel(ModelSource.parse(modelSource)),
      params: const ModelParams(
        contextSize: 2048,
        gpuLayers: 0,
      ),
      onProgress: (progress) {
        final fraction = progress.fraction;
        if (fraction != null) {
          onProgress?.call(fraction.clamp(0.0, 1.0));
        }
      },
    );

    _engine = engine;
    _session = ChatSession(
      engine,
      maxContextTokens: 2048,
      systemPrompt:
          'You are NOVA AI, a helpful, accurate assistant. Reply in the same language as the user. Prefer clear Arabic when the user writes Arabic. Be honest when you are unsure.',
    );
  }

  Future<void> ensureReady({
    void Function(double progress)? onDownloadProgress,
  }) async {
    if (isReady) return;

    _loading ??= _loadModel(onDownloadProgress);
    try {
      await _loading!;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<String> sendMessage(
    String text, {
    void Function(double progress)? onDownloadProgress,
  }) async {
    await ensureReady(onDownloadProgress: onDownloadProgress);
    final reply = await _session!.send(text);
    return reply.text.trim();
  }

  void resetChat() {
    _session?.reset();
  }

  Future<void> dispose() async {
    _session = null;
    final engine = _engine;
    _engine = null;
    _loading = null;
    if (engine != null) {
      await engine.dispose();
    }
  }
}
