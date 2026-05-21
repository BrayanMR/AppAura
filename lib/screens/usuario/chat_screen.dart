import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/chat_service.dart';
import '../../services/mental_health_triage_service.dart';
import '../../services/chat_ia_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Cargar historial y memoria IA desde Firestore
  Future<void> _loadIaChatHistory() async {
    final userId = _uidUsuario ?? _documentoUsuario;
    if (userId == null || userId.trim().isEmpty) {
      // Si no hay identificador, solo mensaje de bienvenida
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text:
                'Hola $_nombreUsuario. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      return;
    }
    try {
      final data = await ChatIaService.getOrCreateUserChatIa(userId);
      final List<dynamic> msgs = data['messages'] ?? [];
      final String memory = data['memory'] ?? '';
      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (msgs.isNotEmpty) {
          _messages.addAll(
            msgs.map(
              (m) => _ChatMessage(
                text: m['texto'] ?? '',
                isUser: (m['autor'] ?? '') == 'usuario',
                timestamp:
                    DateTime.tryParse(m['fecha'] ?? '') ?? DateTime.now(),
              ),
            ),
          );
        } else {
          _messages.add(
            _ChatMessage(
              text:
                  'Hola $_nombreUsuario. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
        _conversationMemory = memory;
      });
    } catch (_) {
      // Si falla, solo mensaje de bienvenida
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text:
                'Hola $_nombreUsuario. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final List<Map<String, dynamic>> _myChats = <Map<String, dynamic>>[];

  bool _initialized = false;
  String? _documentoUsuario;
  String? _uidUsuario;
  String _nombreUsuario = 'Usuario Aura';
  bool _isSending = false;
  bool _isCreatingReferral = false;
  bool _isLoadingChats = false;
  String? _chatsError;
  String _chatQuery = '';
  MentalHealthTriageResult? _lastTriage;
  String _conversationMemory = '';

  String get _memoryStorageKey {
    final base = [
      _documentoUsuario?.trim(),
      _uidUsuario?.trim(),
      _nombreUsuario.trim(),
    ].where((value) => value != null && value!.isNotEmpty).join('_');
    final safe = base.isEmpty
        ? 'anonimo'
        : base
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'_+'), '_')
              .replaceAll(RegExp(r'^_|_$'), '');
    return 'ai_memory_$safe';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;
    _documentoUsuario = _readString(mapArgs, const [
      'documentoUsuario',
      'documento',
      'Documento',
      'uid',
    ]);
    _uidUsuario = _readString(mapArgs, const ['uid', 'uidUsuario']);

    final name = _readString(mapArgs, const ['nombreUsuario', 'nombre']);
    if (name.isNotEmpty) {
      _nombreUsuario = name;
    }

    // Fallback: obtener UID de Firebase si no vinieron en argumentos
    if (_uidUsuario == null || _uidUsuario!.isEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _uidUsuario = currentUser.uid;
        debugPrint('[CHAT] UID obtenido de Firebase: $_uidUsuario');
      }
    }

    _loadIaChatHistory();
    _loadMyChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncConversationMemory(MentalHealthTriageResult triage) async {
    final memory = triage.memory.trim();
    if (memory.isEmpty || memory == _conversationMemory.trim()) return;
    if (!mounted) return;
    setState(() {
      _conversationMemory = memory;
    });
  }

  List<Map<String, String>> _recentConversationContext({int limit = 8}) {
    if (_messages.isEmpty) return const <Map<String, String>>[];

    final startIndex = _messages.length > limit ? _messages.length - limit : 0;
    return _messages.sublist(startIndex).map((message) {
      return <String, String>{
        'role': message.isUser ? 'user' : 'assistant',
        'text': message.text.trim(),
      };
    }).toList();
  }

  Future<void> _sendMessage() async {
    // Guardar historial y memoria IA en Firestore
    Future<void> _saveIaChatHistory() async {
      final userId = _uidUsuario ?? _documentoUsuario;
      debugPrint(
        '[IA-MEMORY] Intentando guardar memoria IA para userId: '
        '${userId ?? 'null'}',
      );
      if (userId == null || userId.trim().isEmpty) {
        debugPrint('[IA-MEMORY] userId vacío, no se guarda memoria.');
        return;
      }
      final messagesToSave = _messages
          .map(
            (m) => {
              'autor': m.isUser ? 'usuario' : 'ia',
              'texto': m.text,
              'fecha': m.timestamp.toIso8601String(),
            },
          )
          .toList();
      debugPrint('[IA-MEMORY] Payload a guardar:');
      debugPrint('messages: ' + messagesToSave.length.toString());
      debugPrint('memory: ' + _conversationMemory);
      try {
        await ChatIaService.saveUserChatIa(
          userId: userId,
          messages: messagesToSave,
          memory: _conversationMemory,
        );
        debugPrint('[IA-MEMORY] Guardado exitoso en Firestore para $userId');
      } catch (e, st) {
        debugPrint('[IA-MEMORY][ERROR] No se pudo guardar memoria IA: $e');
        debugPrint(st.toString());
      }
    }

    final text = _messageController.text.trim();
    if (_isSending) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, escribe un mensaje antes de enviar.'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _messages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _messageController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final triage = await MentalHealthTriageService.analyze(
        text,
        recentConversation: _recentConversationContext(),
        conversationMemory: _conversationMemory,
      );
      if (!mounted) return;
      setState(() {
        _lastTriage = triage;
        _messages.add(
          _ChatMessage(
            text: triage.reply,
            isUser: false,
            timestamp: DateTime.now(),
            highlight: triage.crisis,
          ),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      await _syncConversationMemory(triage);
      // Guardar memoria IA después de actualizar _conversationMemory
      await _saveIaChatHistory();
      if (triage.crisis && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si estás en peligro inmediato, busca ayuda presencial o llama a emergencias ahora.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'No pude analizar tu mensaje ahora mismo: $error',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _createReferral() async {
    final triage = _lastTriage;
    if (triage == null || triage.psychologist == null) return;

    final documentoUsuario = _documentoUsuario;
    if (documentoUsuario == null || documentoUsuario.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falta el documento del usuario para crear la derivación.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validar nombre del psicólogo
    final psicologo = triage.psychologist!;
    if (psicologo.name == null || psicologo.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede crear la derivación: falta el nombre del psicólogo.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isCreatingReferral = true;
    });

    try {
      final psicologo = triage.psychologist!;
      print(
        '[DEBUG] Enviando a createReferralChat: documentoUsuario=$documentoUsuario, documentoPsicologo=${psicologo.documento}, nombrePsicologo=${psicologo.name}, nombreUsuario=$_nombreUsuario',
      );
      final chatId = await ChatService.createReferralChat(
        documentoUsuario: documentoUsuario,
        documentoPsicologo: psicologo.documento,
        uidPsicologo: psicologo.uid,
        motivo: triage.label,
        categoria: triage.category,
        mensajeInicial: _messages.isNotEmpty ? _messages.last.text : null,
        nombrePsicologo: psicologo.name,
        nombreUsuario: _nombreUsuario,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatId.isNotEmpty
                ? 'Derivación creada con ${psicologo.name}.'
                : 'Derivación creada.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear la derivación: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingReferral = false;
        });
      }

      await _loadMyChats();
    }
  }

  Future<void> _loadMyChats() async {
    final documento = _documentoUsuario;
    final uid = _uidUsuario;

    if ((documento == null || documento.trim().isEmpty) &&
        (uid == null || uid.trim().isEmpty)) {
      return;
    }

    setState(() {
      _isLoadingChats = true;
      _chatsError = null;
    });

    try {
      final chats = await ChatService.fetchChats(
        documento: documento,
        uid: uid,
      );

      if (!mounted) return;

      if (!mounted) return;
      setState(() {
        _myChats
          ..clear()
          ..addAll(chats);
      });
    } catch (error) {
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _chatsError = error.toString();
      });
    } finally {
      if (mounted) {
        if (!mounted) return;
        setState(() {
          _isLoadingChats = false;
        });
      }
    }
  }

  String _resolvePsychologistName(Map<String, dynamic> chat) {
    final nombre = (chat['nombre_psicologo'] ?? '').toString().trim();
    if (nombre.isNotEmpty) return nombre;

    final documento = (chat['Documento_psicologo'] ?? '').toString().trim();
    return documento.isNotEmpty ? documento : 'Sin psicólogo asignado';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, dynamic>> get _filteredChats {
    final query = _chatQuery.trim().toLowerCase();
    if (query.isEmpty) return _myChats;

    return _myChats.where((chat) {
      final motivo = (chat['Motivo'] ?? '').toString().toLowerCase();
      final categoria = (chat['Categoria'] ?? '').toString().toLowerCase();
      final mensaje = (chat['Mensaje'] ?? '').toString().toLowerCase();
      final psicologo = (chat['Documento_psicologo'] ?? '')
          .toString()
          .toLowerCase();
      return motivo.contains(query) ||
          categoria.contains(query) ||
          mensaje.contains(query) ||
          psicologo.contains(query);
    }).toList();
  }

  Future<void> _openConversationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ConversationPage(
          nombreUsuario: _nombreUsuario,
          documentoUsuario: _documentoUsuario,
          uidUsuario: FirebaseAuth.instance.currentUser?.uid,
          onReferralCreated: _loadMyChats,
        ),
      ),
    );
  }

  Future<void> _openExistingChat(Map<String, dynamic> chat) async {
    final chatId = (chat['id'] ?? '').toString().trim();
    if (chatId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExistingChatPage(
          chatId: chatId,
          psychologistName: _resolvePsychologistName(chat),
        ),
      ),
    );

    await _loadMyChats();
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavSpace = MediaQuery.of(context).padding.bottom + 88;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, bottomNavSpace),
          child: Column(
            children: [
              _ChatHeader(name: _nombreUsuario),
              const SizedBox(height: 12),
              _SearchBar(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _chatQuery = value;
                  });
                },
              ),

              const SizedBox(height: 12),
              Expanded(
                child: _ChatsListPanel(
                  chats: _filteredChats,
                  isLoading: _isLoadingChats,
                  errorMessage: _chatsError,
                  onRefresh: _loadMyChats,
                  onStartChat: _openConversationPage,
                  onOpenChat: _openExistingChat,
                  resolvePsychologistName: _resolvePsychologistName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class _ChatHeader extends StatelessWidget {
  final String name;

  const _ChatHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.42),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.rolePsicologo.withOpacity(0.18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(name, style: AppTextStyles.headlineMedium)],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge.copyWith(color: const Color(0xFF4B4860)),
      decoration: InputDecoration(
        hintText: 'Buscar chats',
        hintStyle: AppTextStyles.bodyLarge.copyWith(
          color: const Color.fromARGB(255, 95, 85, 123),
        ),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF6E6A7A)),
        filled: true,
        fillColor: const Color(0xFFF4ECFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFB89BEA), width: 1.2),
        ),
      ),
    );
  }
}

class _ChatsListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> chats;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onStartChat;
  final Future<void> Function(Map<String, dynamic>) onOpenChat;
  final String Function(Map<String, dynamic>) resolvePsychologistName;

  const _ChatsListPanel({
    super.key,
    required this.chats,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onStartChat,
    required this.onOpenChat,
    required this.resolvePsychologistName,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No pude cargar tus chats',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(errorMessage!, style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (chats.isEmpty) {
      return _StartChatPrompt(onStartChat: onStartChat, emptyState: true);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 92),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              return _ChatSummaryTile(
                chat: chats[index],
                onTap: () => onOpenChat(chats[index]),
                psychologistName: resolvePsychologistName(chats[index]),
              );
            },
          ),
        ),
        Positioned(
          right: 8,
          bottom: 12,
          child: _StartChatPrompt(onStartChat: onStartChat, emptyState: false),
        ),
      ],
    );
  }
}

class _StartChatPrompt extends StatelessWidget {
  final VoidCallback onStartChat;
  final bool emptyState;

  const _StartChatPrompt({required this.onStartChat, required this.emptyState});

  @override
  Widget build(BuildContext context) {
    final promptColor = emptyState ? Colors.transparent : Colors.white;

    return Container(
      padding: emptyState
          ? const EdgeInsets.fromLTRB(8, 8, 8, 18)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: promptColor,
        borderRadius: BorderRadius.circular(emptyState ? 0 : 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: onStartChat,
            iconSize: 42,
            icon: const Icon(Icons.mark_chat_unread_rounded),
            color: const Color(0xFF1F9AA8),
            tooltip: 'Iniciar conversación',
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ExistingChatPage extends StatefulWidget {
  final String chatId;
  final String psychologistName;

  const _ExistingChatPage({
    required this.chatId,
    required this.psychologistName,
  });

  @override
  State<_ExistingChatPage> createState() => _ExistingChatPageState();
}

class _ExistingChatPageState extends State<_ExistingChatPage> {
  // ...existing code...
  String _displayPsychologistName = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAndSetPsychologistName();
  }

  void _resolveAndSetPsychologistName() {
    if (_displayPsychologistName.isNotEmpty) return;
    if (!mounted) return;
    setState(() {
      _displayPsychologistName = widget.psychologistName;
    });
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _threadMessages = <_ChatMessage>[];
  Timer? _pollingTimer;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _lastMessageKey = '';
  Map<String, dynamic> _chat = <String, dynamic>{};

  String get _historyStorageKey => 'chat_history_usuario_${widget.chatId}';

  @override
  void initState() {
    super.initState();
    _loadChat();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Forzar scroll al fondo cada vez que se construye la vista
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _sending) return;
      _loadChat(showLoader: false);
    });
  }

  Future<void> _loadChat({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final chat = await ChatService.getChatById(widget.chatId);
      if (!mounted) return;

      setState(() {
        _chat = chat;
        _syncMessages(chat);
      });
    } catch (error) {
      if (!mounted) return;
      if (showLoader) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final draft = text;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final optimisticTimestamp = DateTime.now();

    if (!mounted) return;
    setState(() {
      _sending = true;
      _messageController.clear();
      _threadMessages.add(
        _ChatMessage(text: text, isUser: true, timestamp: optimisticTimestamp),
      );
      _lastMessageKey =
          '${optimisticTimestamp.toIso8601String()}|$currentUid|${text.toLowerCase()}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      await ChatService.updateChatMessage(
        chatId: widget.chatId,
        message: text,
        authorUid: currentUid,
        authorRole: 'usuario',
      );
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _chat['Mensaje'] = text;
        _chat['UltimoAutorUid'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        _chat['updatedAt'] = DateTime.now().toIso8601String();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje enviado al psicólogo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        if (_threadMessages.isNotEmpty) {
          _threadMessages.removeLast();
        }
        _messageController.text = draft;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        if (!mounted) return;
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  DateTime? _parseDate(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  void _syncMessages(Map<String, dynamic> chat) {
    final rawMessages = chat['Mensajes'];
    if (rawMessages is List && rawMessages.isNotEmpty) {
      _threadMessages
        ..clear()
        ..addAll(
          rawMessages
              .whereType<Map>()
              .map((item) {
                final map = Map<String, dynamic>.from(item as Map);
                final text = (map['texto'] ?? map['Mensaje'] ?? '')
                    .toString()
                    .trim();
                final authorUid = (map['autorUid'] ?? map['Uid'] ?? '')
                    .toString()
                    .trim();
                final timestamp =
                    _parseDate(
                      map['fecha'] ?? map['timestamp'] ?? map['Fecha'],
                    ) ??
                    DateTime.now();
                final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final isUser =
                    currentUid.isNotEmpty &&
                    authorUid.isNotEmpty &&
                    currentUid == authorUid;

                return _ChatMessage(
                  text: text,
                  isUser: isUser,
                  timestamp: timestamp,
                );
              })
              .where((msg) => msg.text.isNotEmpty),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }

    final text = (chat['Mensaje'] ?? '').toString().trim();
    if (text.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final authorUid = (chat['UltimoAutorUid'] ?? '').toString().trim();
    final timestamp =
        _parseDate(chat['updatedAt'] ?? chat['Fecha_inicio']) ?? DateTime.now();
    final key =
        '${timestamp.toIso8601String()}|$authorUid|${text.toLowerCase()}';
    if (_lastMessageKey == key) return;

    _lastMessageKey = key;
    final isFromUser =
        currentUid.isNotEmpty &&
        authorUid.isNotEmpty &&
        authorUid == currentUid;

    if (_threadMessages.isNotEmpty) {
      final last = _threadMessages.last;
      final sameAuthor = last.isUser == isFromUser;
      final sameText = last.text.trim().toLowerCase() == text.toLowerCase();
      final closeTime =
          timestamp.difference(last.timestamp).inSeconds.abs() <= 15;
      if (sameAuthor && sameText && closeTime) {
        return;
      }
    }

    _threadMessages.add(
      _ChatMessage(text: text, isUser: isFromUser, timestamp: timestamp),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _displayPsychologistName.isEmpty
              ? 'Psicólogo Jaime'
              : _displayPsychologistName,
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('No se pudo abrir el chat\n$_error'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _threadMessages.isEmpty
                          ? ListView(
                              controller: _scrollController,
                              children: [
                                _ChatBubble(
                                  message: _ChatMessage(
                                    text: 'Sin mensajes aún',
                                    isUser: false,
                                    timestamp: DateTime.now(),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: _threadMessages.length,
                              itemBuilder: (context, index) {
                                return _ChatBubble(
                                  message: _threadMessages[index],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              style: AppTextStyles.titleLarge.copyWith(
                                color: const Color(0xFF4B4860),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Escribe....',
                                hintStyle: AppTextStyles.titleLarge.copyWith(
                                  color: const Color(0xFF6E6A7A),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFB89BEA),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: _sending ? null : _sendMessage,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ConversationPage extends StatefulWidget {
  final String nombreUsuario;
  final String? documentoUsuario;
  final String? uidUsuario;
  final Future<void> Function() onReferralCreated;

  const _ConversationPage({
    required this.nombreUsuario,
    required this.documentoUsuario,
    required this.uidUsuario,
    required this.onReferralCreated,
  });

  @override
  State<_ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<_ConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _isSending = false;
  bool _isCreatingReferral = false;
  bool _hasSuggestedReferral = false;
  MentalHealthTriageResult? _lastTriage;
  String _conversationMemory = '';

  String? get _storageUserId {
    final uid = widget.uidUsuario?.trim();
    if (uid != null && uid.isNotEmpty) return uid;

    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUid != null && currentUid.isNotEmpty) return currentUid;

    final documento = widget.documentoUsuario?.trim();
    if (documento != null && documento.isNotEmpty) return documento;

    return null;
  }

  String get _memoryStorageKey {
    final base = [
      _storageUserId,
      widget.nombreUsuario.trim(),
    ].where((value) => value != null && value!.isNotEmpty).join('_');
    final safe = base.isEmpty
        ? 'anonimo'
        : base
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'_+'), '_')
              .replaceAll(RegExp(r'^_|_$'), '');
    return 'ai_memory_$safe';
  }

  bool _isDuplicateAssistantMessage(String text) {
    if (_messages.isEmpty) return false;
    final last = _messages.last;
    if (last.isUser) return false;
    return last.text.trim().toLowerCase() == text.trim().toLowerCase();
  }

  bool _isMemoryRecallIntent(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    return normalized.contains('te acuerdas') ||
        normalized.contains('recuerdas') ||
        normalized.contains('recordas') ||
        normalized.contains('hablabamos') ||
        normalized.contains('hablamos') ||
        normalized.contains('del tema');
  }

  String? _extractNameFromMemory(String memory) {
    final lines = memory
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      final lowered = line.toLowerCase();
      if (lowered.startsWith('nombre:') || lowered.startsWith('name:')) {
        final name = line.split(':').sublist(1).join(':').trim();
        if (name.isNotEmpty) return name;
      }
    }

    return null;
  }

  bool _areTextsTooSimilar(String a, String b) {
    final normalize = (String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final textA = normalize(a);
    final textB = normalize(b);
    if (textA.isEmpty || textB.isEmpty) return false;
    if (textA == textB || textA.contains(textB) || textB.contains(textA)) {
      return true;
    }

    final wordsA = textA.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = textB.split(' ').where((w) => w.length > 2).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;

    final overlap = wordsA.where(wordsB.contains).length;
    final ratioA = overlap / wordsA.length;
    final ratioB = overlap / wordsB.length;
    return ratioA >= 0.65 || ratioB >= 0.65;
  }

  void _addAssistantMessage(
    String text, {
    bool highlight = false,
    bool isError = false,
  }) {
    if (text.trim().isEmpty) return;
    if (_isDuplicateAssistantMessage(text)) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          highlight: highlight,
          isError: isError,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _syncConversationMemory(MentalHealthTriageResult triage) async {
    final memory = triage.memory.trim();
    if (memory.isEmpty || memory == _conversationMemory.trim()) return;
    if (!mounted) return;
    if (!mounted) return;
    setState(() {
      _conversationMemory = memory;
    });
  }

  Future<void> _loadIaChatHistory() async {
    final userId =
        widget.uidUsuario?.trim() ?? FirebaseAuth.instance.currentUser?.uid;
    final legacyUserId = widget.documentoUsuario?.trim();
    debugPrint(
      '[IA-MEMORY] Cargando historial para userId: ${userId ?? "null"}',
    );
    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..add(
            _ChatMessage(
              text:
                  'Hola ${widget.nombreUsuario}. Cuéntame cómo te sientes y yo te ayudo a orientarte',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
      });
      return;
    }

    try {
      final data = await ChatIaService.getOrCreateUserChatIa(userId);
      final List<dynamic> msgs = data['messages'] ?? [];
      final String memory = data['memory'] ?? '';

      final shouldMigrateLegacyData =
          (msgs.isEmpty && memory.trim().isEmpty) &&
          legacyUserId != null &&
          legacyUserId.isNotEmpty &&
          legacyUserId != userId;

      if (shouldMigrateLegacyData) {
        final legacyData = await ChatIaService.getOrCreateUserChatIa(
          legacyUserId,
        );
        final List<dynamic> legacyMsgs = legacyData['messages'] ?? [];
        final String legacyMemory = legacyData['memory'] ?? '';

        if (legacyMsgs.isNotEmpty || legacyMemory.trim().isNotEmpty) {
          await ChatIaService.saveUserChatIa(
            userId: userId,
            messages: List<Map<String, dynamic>>.from(
              legacyMsgs.whereType<Map>().map(
                (item) => Map<String, dynamic>.from(item),
              ),
            ),
            memory: legacyMemory,
          );

          if (!mounted) return;
          setState(() {
            _messages.clear();
            _messages.addAll(
              legacyMsgs.map(
                (m) => _ChatMessage(
                  text: m['texto'] ?? '',
                  isUser: (m['autor'] ?? '') == 'usuario',
                  timestamp:
                      DateTime.tryParse(m['fecha'] ?? '') ?? DateTime.now(),
                ),
              ),
            );

            if (_messages.isEmpty) {
              final name =
                  _extractNameFromMemory(legacyMemory) ?? widget.nombreUsuario;
              _messages.add(
                _ChatMessage(
                  text:
                      'Hola $name. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
            }

            _conversationMemory = legacyMemory;
          });
          _scrollToBottom();
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (msgs.isNotEmpty) {
          _messages.addAll(
            msgs.map(
              (m) => _ChatMessage(
                text: m['texto'] ?? '',
                isUser: (m['autor'] ?? '') == 'usuario',
                timestamp:
                    DateTime.tryParse(m['fecha'] ?? '') ?? DateTime.now(),
              ),
            ),
          );
        }

        if (_messages.isEmpty) {
          final name = _extractNameFromMemory(memory) ?? widget.nombreUsuario;
          _messages.add(
            _ChatMessage(
              text:
                  'Hola $name. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }

        _conversationMemory = memory;
      });
      _scrollToBottom();
    } catch (e, st) {
      debugPrint('[IA-MEMORY][ERROR] No se pudo cargar historial: $e');
      debugPrint(st.toString());
      if (!mounted) return;
      setState(() {
        final name =
            _extractNameFromMemory(_conversationMemory) ?? widget.nombreUsuario;
        _messages
          ..clear()
          ..add(
            _ChatMessage(
              text:
                  'Hola $name. Cuéntame cómo te sientes y yo te ayudo a orientarte. Si detecto que necesitas apoyo profesional, te conecto con un psicólogo adecuado.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
      });
    }
  }

  Future<void> _saveIaChatHistory() async {
    final userId = _storageUserId;
    debugPrint(
      '[IA-MEMORY] Intentando guardar para userId: ${userId ?? "null"}',
    );
    if (userId == null || userId.trim().isEmpty) return;
    try {
      final messagesToSave = _messages
          .map(
            (m) => {
              'autor': m.isUser ? 'usuario' : 'ia',
              'texto': m.text,
              'fecha': m.timestamp.toIso8601String(),
            },
          )
          .toList();
      await ChatIaService.saveUserChatIa(
        userId: userId,
        messages: messagesToSave,
        memory: _conversationMemory,
      );
      debugPrint('[IA-MEMORY] Guardado exitoso');
    } catch (e) {
      debugPrint('[IA-MEMORY][ERROR] $e');
    }
  }

  String get _partnerName {
    // En esta vista siempre debe mostrarse la IA.
    // El nombre del psicólogo se muestra en _ExistingChatPage.
    return 'Asistente Aura';
  }

  bool _isReferralConfirmation(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    const confirmations = <String>[
      'confirmo derivacion',
      'confirmo derivación',
      'confirmo',
      'si confirmo',
      'sí confirmo',
      'conectame',
      'conéctame',
      'conectame con psicologo',
      'conéctame con psicólogo',
      'gracias dale',
      'dale',
      'si dale',
      'sí dale',
      'ok dale',
      'de una',
      'hazlo',
      'derivame',
      'derívame',
      'enviame con psicologo',
      'envíame con psicólogo',
      'quiero hablar con psicologo',
      'quiero hablar con psicólogo',
      'quiero hablar con una persona',
      'quiero hablar con alguien',
    ];

    return confirmations.any(normalized.contains);
  }

  bool _isReferralAffirmation(String text) {
    final normalized = text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-záéíóúüñ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized == 'si' || normalized == 'sí';
  }

  bool _isNegativePsychologistRequest(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    const negativePhrases = <String>[
      'no quiero hablar con psicologo',
      'no quiero hablar con psicólogo',
      'no quiero un psicologo',
      'no quiero un psicólogo',
      'no quiero ir con un psicologo',
      'no quiero ir con un psicólogo',
      'no quiero con un psicologo',
      'no quiero con un psicólogo',
      'no quiero hablar con una persona',
      'no quiero hablar con alguien',
      'no me mandes con psicologo',
      'no me mandes con psicólogo',
      'no me mandes con una persona',
      'no me redirijas',
    ];

    return negativePhrases.any(normalized.contains);
  }

  bool _isDirectPsychologistRequest(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    if (_isNegativePsychologistRequest(normalized)) {
      return false;
    }

    const directRequests = <String>[
      'quiero hablar con una persona',
      'quiero hablar con alguien',
      'quiero ver al psicologo',
      'quiero ver al psicólogo',
      'quiero hablar con el psicologo',
      'quiero hablar con el psicólogo',
      'quiero un psicologo',
      'quiero un psicólogo',
      'quiero una psicologa',
      'quiero una psicóloga',
      'quiero una persona',
      'pasame al psicologo',
      'pásame al psicólogo',
      'pasame con una persona',
      'pásame con una persona',
      'pasame con alguien',
      'pásame con alguien',
      'conectame con el psicologo',
      'conéctame con el psicólogo',
      'conectame con una persona',
      'conéctame con una persona',
      'conectame con alguien',
      'conéctame con alguien',
      'de una con psicologo',
      'de una con psicólogo',
      'de una con una persona',
      'de una con alguien',
      'necesito hablar con alguien',
      'necesito hablar con una persona',
      'necesito un psicologo',
      'necesito un psicólogo',
      'quiero ayuda profesional',
      'quiero ayuda de un psicologo',
      'quiero ayuda de un psicólogo',
      'quiero ayuda con psicologo',
      'quiero ayuda con psicólogo',
      'necesito ayuda profesional',
      'necesito ayuda de un psicologo',
      'necesito ayuda de un psicólogo',
      'ayuda de psicologo',
      'ayuda de un psicologo',
      'ayuda de psicólogo',
      'ayuda de un psicólogo',
    ];

    if (directRequests.any(normalized.contains)) {
      return true;
    }

    return normalized.contains('ayuda') && normalized.contains('psicolog');
  }

  bool _shouldSuggestReferral(
    MentalHealthTriageResult triage, {
    String lastUserMessage = '',
  }) {
    final category = triage.category.trim().toLowerCase();
    final normalizedMessage = lastUserMessage.toLowerCase().trim();
    if (triage.psychologist == null) return false;
    if (triage.crisis) return true;

    // Fuera de crisis, solo sugiere derivación cuando el usuario insinúa apoyo humano.
    final hintedHumanSupport =
        normalizedMessage.contains('psicolog') ||
        normalizedMessage.contains('persona') ||
        normalizedMessage.contains('alguien') ||
        normalizedMessage.contains('ayuda profesional') ||
        normalizedMessage.contains('deriv');

    return category.isNotEmpty && category != 'general' && hintedHumanSupport;
  }

  bool _alreadyGuidesNextStep(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    return text.contains('?') ||
        normalized.contains('si quieres') ||
        normalized.contains('cuentame') ||
        normalized.contains('cuéntame') ||
        normalized.contains('dime ') ||
        normalized.contains('que ocurr') ||
        normalized.contains('que paso') ||
        normalized.contains('que te preocupa') ||
        normalized.contains('siguiente paso');
  }

  String _buildCoachingFollowUp(
    MentalHealthTriageResult triage, {
    String lastUserMessage = '',
  }) {
    final category = triage.category.trim().toLowerCase();
    final normalized = lastUserMessage.toLowerCase().trim();
    final violenceInHome =
        normalized.contains('pega') ||
        normalized.contains('golpea') ||
        normalized.contains('maltrata') ||
        normalized.contains('agrede');

    switch (category) {
      case 'ansiedad':
        return 'Si te sirve, probemos algo corto: inhala 4 segundos, sostén 4 y exhala 6, tres veces. Luego me dices si bajó un poco la tensión.';
      case 'estres':
        return 'Podemos ordenar esto juntos: dime qué te está drenando más hoy y lo dividimos en pasos pequeños para que se sienta manejable.';
      case 'tristeza':
        return 'Gracias por contarlo. Si puedes, cuéntame qué momento del día se te hace más pesado y buscamos una acción concreta para ese momento.';
      case 'familiar':
        if (violenceInHome) {
          return '¿Tu mamá está a salvo ahora mismo? Si no, busca a un adulto de confianza o un lugar seguro y pide ayuda de inmediato.';
        }

        return 'Cuéntame qué pasó primero y quiénes estaban ahí. Así te ayudo a pensar qué hacer sin enredarnos.';
      case 'sueno':
        return 'Para el sueño, podemos empezar hoy con una rutina mínima: sin pantalla 30 minutos antes y respiración suave. ¿Te cuesta más conciliar o te despiertas varias veces?';
      case 'crisis':
        return 'Estoy contigo. Vamos paso a paso y priorizando tu seguridad mientras buscamos apoyo profesional inmediato.';
      default:
        if (violenceInHome) {
          return '¿Tu mamá está a salvo ahora mismo? Si no, busca a un adulto de confianza o un lugar seguro y pide ayuda de inmediato.';
        }
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadIaChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!mounted) return;
    if (!mounted) return;
    setState(() {
      _isSending = true;
      _messages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _messageController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Si el usuario pide psicólogo de forma directa desde el primer mensaje,
    // crea/recupera la derivación y abre inmediatamente ese chat.
    final directHumanSupportRequest =
        _isDirectPsychologistRequest(text) ||
        text.toLowerCase().contains('quiero hablar con una persona') ||
        text.toLowerCase().contains('quiero hablar con alguien');

    if (directHumanSupportRequest) {
      if (_lastTriage?.psychologist == null) {
        try {
          final triage = await MentalHealthTriageService.analyze(
            text,
            recentConversation: _recentConversationContext(),
            conversationMemory: _conversationMemory,
            forceMatchPsychologist: true,
          );
          if (!mounted) return;
          if (mounted) {
            if (!mounted) return;
            setState(() {
              _lastTriage = triage;
            });
          }
          await _syncConversationMemory(triage);
        } catch (_) {
          // Si falla el análisis, continúa con el flujo normal.
        }
      }

      if (_lastTriage?.psychologist != null) {
        final chatId = await _createReferral();
        if (!mounted) return;

        if (chatId != null) {
          if (mounted) {
            if (!mounted) return;
            setState(() {
              _addAssistantMessage(
                'Listo, te estoy conectando ahora mismo con el psicólogo.',
              );
            });
          }
          _scrollToBottom();
          await _openPsychologistChat(chatId);
          if (mounted) {
            setState(() {
              _isSending = false;
            });
          }
          return;
        }
      }

      if (directHumanSupportRequest) {
        if (mounted) {
          setState(() {
            _addAssistantMessage(
              'Lo siento, ahora mismo no encontré un psicólogo disponible para conectarte. Si quieres, seguimos por aquí y te acompaño en lo que estás viviendo.',
            );
          });
        }
        await _saveIaChatHistory();
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
        _scrollToBottom();
        return;
      }
    }

    if (_isNegativePsychologistRequest(text)) {
      try {
        final triage = await MentalHealthTriageService.analyze(
          text,
          recentConversation: _recentConversationContext(),
          conversationMemory: _conversationMemory,
        );
        if (!mounted) return;

        if (mounted) {
          setState(() {
            _lastTriage = triage;
            _addAssistantMessage(
              'Está bien, no te voy a llevar con un psicólogo ahora. Te sigo leyendo y me quedo contigo por aquí.',
              highlight: triage.crisis,
            );
          });
        }

        await _syncConversationMemory(triage);
        await _saveIaChatHistory();
        _scrollToBottom();
      } catch (_) {
        // Si falla el análisis, continúa con el flujo normal.
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
      return;
    }

    if ((_isReferralConfirmation(text) ||
            (_hasSuggestedReferral && _isReferralAffirmation(text))) &&
        _lastTriage?.psychologist != null) {
      final chatId = await _createReferral();
      if (!mounted) return;

      if (mounted) {
        if (!mounted) return;
        setState(() {
          _addAssistantMessage(
            chatId != null
                ? 'Perfecto, ya te conecté con el psicólogo recomendado. Te acompaño mientras sigues contándome lo que te pasa.'
                : 'Intenté hacer la derivación, pero no pude completarla. Si quieres, lo intento de nuevo.',
          );

          if (chatId != null) {
            _addAssistantMessage(
              'Cuéntame un poco más de lo que estás viviendo hoy para seguir apoyándote mientras esperas esa derivación.',
            );
          }
        });
      }

      _scrollToBottom();
      if (chatId != null) {
        await _openPsychologistChat(chatId);
      }
      if (mounted) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
        });
      }
      return;
    }

    try {
      final triage = await MentalHealthTriageService.analyze(
        text,
        recentConversation: _recentConversationContext(),
        conversationMemory: _conversationMemory,
      );
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _lastTriage = triage;
          final primaryReply = triage.reply.trim();
          _addAssistantMessage(primaryReply, highlight: triage.crisis);

          final shouldOfferReferral =
              !directHumanSupportRequest &&
              !_hasSuggestedReferral &&
              _shouldSuggestReferral(triage, lastUserMessage: text);

          if (!directHumanSupportRequest &&
              !_isNegativePsychologistRequest(text) &&
              !_isMemoryRecallIntent(text) &&
              !shouldOfferReferral &&
              !_alreadyGuidesNextStep(primaryReply)) {
            final coaching = _buildCoachingFollowUp(
              triage,
              lastUserMessage: text,
            );
            if (coaching.trim().isNotEmpty &&
                !_areTextsTooSimilar(primaryReply, coaching)) {
              _addAssistantMessage(coaching);
            }
          }

          if (shouldOfferReferral) {
            _hasSuggestedReferral = true;
            _addAssistantMessage(
              'Si quieres que te conecte ahora mismo con el psicólogo recomendado, respóndeme: "confirmo derivación", "sí" o "sí, conéctame".',
            );
          }
        });
      }

      await _syncConversationMemory(triage);
      await _saveIaChatHistory();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      if (mounted) {
        setState(() {
          final errorText = 'No pude analizar tu mensaje ahora mismo: $error';
          if (!_isDuplicateAssistantMessage(errorText)) {
            _messages.add(
              _ChatMessage(
                text: errorText,
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      _scrollToBottom();
    }
  }

  List<Map<String, String>> _recentConversationContext({int limit = 8}) {
    if (_messages.isEmpty) return const <Map<String, String>>[];

    final startIndex = _messages.length > limit ? _messages.length - limit : 0;
    return _messages.sublist(startIndex).map((message) {
      return <String, String>{
        'role': message.isUser ? 'user' : 'assistant',
        'text': message.text.trim(),
      };
    }).toList();
  }

  Future<String?> _createReferral() async {
    final triage = _lastTriage;
    if (triage == null || triage.psychologist == null) return null;

    final documentoUsuario = widget.documentoUsuario;
    if (documentoUsuario == null || documentoUsuario.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falta el documento del usuario para crear la derivación.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    if (!mounted) return null;
    setState(() {
      _isCreatingReferral = true;
    });

    try {
      final psicologo = triage.psychologist!;
      final chatId = await ChatService.createReferralChat(
        documentoUsuario: documentoUsuario,
        documentoPsicologo: psicologo.documento,
        uidPsicologo: psicologo.uid,
        motivo: triage.label,
        categoria: triage.category,
        mensajeInicial: _messages.isNotEmpty ? _messages.last.text : null,
        nombrePsicologo: psicologo.name,
        nombreUsuario: widget.nombreUsuario,
      );

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatId.isNotEmpty
                ? 'Derivación creada con ${psicologo.name}.'
                : 'Derivación creada.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await widget.onReferralCreated();
      return chatId.isNotEmpty
          ? chatId
          : await _findReferralChatId(psicologo.documento, psicologo.uid);
    } catch (error) {
      if (!mounted) return null;

      final errorText = error.toString().toLowerCase();
      if (errorText.contains('ya existe un chat')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya existe un chat activo con este psicólogo. Te conecté con ese chat.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await widget.onReferralCreated();
        final psicologo = triage.psychologist!;
        return await _findReferralChatId(psicologo.documento, psicologo.uid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear la derivación: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingReferral = false;
        });
      }
    }

    return null;
  }

  Future<String?> _findReferralChatId(
    String documentoPsicologo,
    String uidPsicologo,
  ) async {
    final documento = widget.documentoUsuario;
    if (documento == null || documento.trim().isEmpty) return null;

    final chats = await ChatService.fetchChats(documento: documento);

    for (final chat in chats) {
      final chatDocumento = (chat['Documento_psicologo'] ?? '')
          .toString()
          .trim();
      final chatUid = (chat['Uid_psicologo'] ?? '').toString().trim();
      if (chatDocumento == documentoPsicologo ||
          (uidPsicologo.isNotEmpty && chatUid == uidPsicologo)) {
        return (chat['id'] ?? '').toString().trim();
      }
    }

    return null;
  }

  Future<void> _openPsychologistChat(String chatId) async {
    if (!mounted || chatId.isEmpty) return;

    final psychologistName = _lastTriage?.psychologist?.name.trim() ?? '';
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _ExistingChatPage(
          chatId: chatId,
          psychologistName: psychologistName,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            14 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Text(
                      _partnerName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _ConversationPanel(
                  messages: _messages,
                  controller: _scrollController,
                ),
              ),
              const SizedBox(height: 12),
              _ComposerBar(
                messageController: _messageController,
                isSending: _isSending,
                onSubmit: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  final List<_ChatMessage> messages;
  final ScrollController controller;

  const _ConversationPanel({
    super.key,
    required this.messages,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients && messages.isNotEmpty) {
        controller.animateTo(
          controller.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _ChatBubble(message: messages[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController messageController;
  final bool isSending;
  final VoidCallback onSubmit;

  const _ComposerBar({
    required this.messageController,
    required this.isSending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              style: AppTextStyles.titleLarge.copyWith(
                color: const Color(0xFF4B4860),
              ),
              decoration: InputDecoration(
                hintText: 'Escribe..',
                hintStyle: AppTextStyles.titleLarge.copyWith(
                  color: const Color(0xFF6E6A7A),
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFB89BEA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: isSending ? null : onSubmit,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool highlight;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.highlight = false,
    this.isError = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isUser
        ? const Color(0xFFA88AD2)
        : message.isError
        ? AppColors.error.withOpacity(0.18)
        : message.highlight
        ? AppColors.warning.withOpacity(0.2)
        : const Color(0xFF8FC5D8);

    final textColor = message.isUser ? Colors.white : const Color(0xFF3E4D5A);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.bodyLarge.copyWith(color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(message.timestamp.toLocal()),
              style: AppTextStyles.caption.copyWith(
                color: textColor.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriageBanner extends StatelessWidget {
  final MentalHealthTriageResult triage;

  const _TriageBanner({required this.triage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: triage.crisis
            ? AppColors.error.withOpacity(0.12)
            : const Color(0xFF8FC5D8).withOpacity(0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: triage.crisis
              ? AppColors.error.withOpacity(0.25)
              : const Color(0xFF5AA3B8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clasificación: ${triage.label}',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Especialidad sugerida: ${triage.recommendedSpecialty}',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PsychologistCard extends StatelessWidget {
  final PsychologistMatch psychologist;
  final bool isCreatingReferral;
  final VoidCallback onCreateReferral;

  const _PsychologistCard({
    required this.psychologist,
    required this.isCreatingReferral,
    required this.onCreateReferral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.rolePsicologo.withOpacity(0.18),
                child: const Icon(Icons.person, color: AppColors.rolePsicologo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(psychologist.name, style: AppTextStyles.titleLarge),
                    Text(
                      psychologist.displaySubtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isCreatingReferral ? null : onCreateReferral,
              icon: isCreatingReferral
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                isCreatingReferral
                    ? 'Creando derivación...'
                    : 'Derivar a este psicólogo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSummaryTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final String psychologistName;

  const _ChatSummaryTile({
    required this.chat,
    required this.onTap,
    required this.psychologistName,
  });

  @override
  Widget build(BuildContext context) {
    final category = (chat['Categoria'] ?? '').toString().trim();
    final motivo = (chat['Motivo'] ?? '').toString().trim();
    final mensaje = (chat['Mensaje'] ?? '').toString().trim();
    final fechaRaw = (chat['Fecha_inicio'] ?? '').toString().trim();
    final fecha = DateTime.tryParse(fechaRaw);

    final title = motivo.isNotEmpty ? motivo : 'Chat';
    final subtitle = mensaje.isNotEmpty
        ? mensaje
        : (category.isNotEmpty ? category : 'Sin mensaje inicial');

    // Mostrar el nombre del psicólogo si está disponible, si no, mostrar el documento
    String displayPsychologist = psychologistName;
    if (displayPsychologist.isEmpty) {
      final doc = (chat['Documento_psicologo'] ?? '').toString().trim();
      displayPsychologist = doc.isNotEmpty ? doc : 'Sin psicólogo asignado';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF9BCBDD),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF4E6A79)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: const Color(0xFF496170),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: const Color(0xFF4E6A79),
                      ),
                    ),
                    Text(
                      'Psicólogo: $displayPsychologist',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF5B7481),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    fecha != null ? DateFormat('HH:mm').format(fecha) : '--:--',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF5B7481),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.arrow_circle_right_outlined,
                    color: Color(0xFF5B7481),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
