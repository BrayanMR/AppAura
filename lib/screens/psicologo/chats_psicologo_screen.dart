import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';

class ChatsPsicologoScreen extends StatefulWidget {
  final String? uid;
  final String? nombreUsuario;
  final String? documentoUsuario;

  const ChatsPsicologoScreen({
    super.key,
    this.uid,
    this.nombreUsuario,
    this.documentoUsuario,
  });

  @override
  State<ChatsPsicologoScreen> createState() => _ChatsPsicologoScreenState();
}

class _ChatsPsicologoScreenState extends State<ChatsPsicologoScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _creatingChat = false;
  String? _error;
  String _nombre = 'Psicólogo/a';
  String? _uid;
  String? _documento;
  String _query = '';
  List<Map<String, dynamic>> _chats = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _uid = widget.uid?.trim().isNotEmpty == true
          ? widget.uid!.trim()
          : FirebaseAuth.instance.currentUser?.uid;

      _documento = widget.documentoUsuario?.trim();
      if ((_documento == null || _documento!.isEmpty) &&
          _uid != null &&
          _uid!.isNotEmpty) {
        _documento = await _resolvePsychologistDocumento(_uid!);
      }

      _nombre = widget.nombreUsuario?.trim().isNotEmpty == true
          ? widget.nombreUsuario!.trim()
          : FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty ==
                true
          ? FirebaseAuth.instance.currentUser!.displayName!.trim()
          : _nombre;

      if ((_uid == null || _uid!.isEmpty) &&
          (_documento == null || _documento!.isEmpty)) {
        throw Exception('No hay datos del psicólogo para cargar chats');
      }

      final chats = await ChatService.fetchChats(
        documento: _documento,
        uid: _uid,
      );

      if (!mounted) return;
      setState(() {
        _chats = chats;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _resolvePsychologistDocumento(String uid) async {
    try {
      final doc = await FirestoreService.getDocument('usuarios', uid);
      final value = (doc['documento'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    } catch (_) {}

    try {
      final docs = await FirestoreService.query(
        'usuarios',
        field: 'uid',
        operator: '==',
        value: uid,
      );
      if (docs.isNotEmpty) {
        final value = (docs.first['documento'] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}

    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchUsersForNewChat() async {
    final users = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> addFromCollection(String collection) async {
      final docs = await FirestoreService.getCollection(collection);
      for (final raw in docs) {
        final role = _readString(raw, const ['role', 'rol']).toLowerCase();
        if (role != 'usuario') continue;

        final documento = _readString(raw, const [
          'documento',
          'Documento',
          'documentoUsuario',
        ]);
        final uid = _readString(raw, const ['uid', 'Uid', 'uidUsuario']);
        final nombre = _readString(raw, const [
          'nombre',
          'displayName',
          'nombreUsuario',
        ]);
        final apellido = _readString(raw, const ['apellido']);
        final nombreCompleto = ([
          nombre,
          apellido,
        ]..removeWhere((e) => e.trim().isEmpty)).join(' ').trim();

        final key = documento.isNotEmpty
            ? 'doc:$documento'
            : (uid.isNotEmpty ? 'uid:$uid' : 'id:${raw['id'] ?? ''}');
        if (key.trim().isEmpty || seen.contains(key)) continue;

        if (_documento != null &&
            _documento!.isNotEmpty &&
            documento == _documento) {
          continue;
        }

        seen.add(key);
        users.add(<String, dynamic>{
          'documento': documento,
          'uid': uid,
          'nombre': nombreCompleto.isNotEmpty ? nombreCompleto : 'Usuario',
          'correo': _readString(raw, const ['correo', 'email']),
        });
      }
    }

    for (final collection in const ['usuarios', 'Usuarios', 'users', 'Users']) {
      try {
        await addFromCollection(collection);
      } catch (_) {
        continue;
      }
    }

    users.sort(
      (a, b) => (a['nombre'] ?? '').toString().toLowerCase().compareTo(
        (b['nombre'] ?? '').toString().toLowerCase(),
      ),
    );
    return users;
  }

  Future<String?> _findExistingChatIdForUser(String documentoUsuario) async {
    String? fromList() {
      for (final chat in _chats) {
        final doc = (chat['Documento_usuario'] ?? '').toString().trim();
        final id = (chat['id'] ?? '').toString().trim();
        if (doc == documentoUsuario && id.isNotEmpty) return id;
      }
      return null;
    }

    final local = fromList();
    if (local != null) return local;

    await _loadChats();
    return fromList();
  }

  Future<void> _createOrOpenChatFromUser(Map<String, dynamic> user) async {
    if (_creatingChat) return;

    final documentoUsuario = (user['documento'] ?? '').toString().trim();
    if (documentoUsuario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El usuario seleccionado no tiene documento.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final documentoPsicologo = _documento?.trim() ?? '';
    if (documentoPsicologo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el documento del psicólogo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _creatingChat = true);
    try {
      String chatId = '';
      try {
        chatId = await ChatService.createReferralChat(
          documentoUsuario: documentoUsuario,
          documentoPsicologo: documentoPsicologo,
          uidPsicologo: _uid,
          nombrePsicologo: _nombre,
          nombreUsuario: (user['nombre'] ?? '').toString().trim(),
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('ya existe un chat')) rethrow;
      }

      if (chatId.isEmpty) {
        chatId = await _findExistingChatIdForUser(documentoUsuario) ?? '';
      }

      if (chatId.isEmpty) {
        throw Exception('No se pudo resolver el chat para este usuario.');
      }

      if (!mounted) return;
      final chatLike = <String, dynamic>{
        'id': chatId,
        'Documento_usuario': documentoUsuario,
        'nombre_usuario': (user['nombre'] ?? '').toString().trim(),
      };
      await _openConversation(chatLike);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear/abrir el chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingChat = false);
      }
    }
  }

  Future<void> _openNewChatPicker() async {
    final users = await _fetchUsersForNewChat();
    if (!mounted) return;

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        String localQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = users.where((user) {
              final q = localQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              final nombre = (user['nombre'] ?? '').toString().toLowerCase();
              final documento = (user['documento'] ?? '')
                  .toString()
                  .toLowerCase();
              final correo = (user['correo'] ?? '').toString().toLowerCase();
              return nombre.contains(q) ||
                  documento.contains(q) ||
                  correo.contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nuevo chat', style: AppTextStyles.headlineMedium),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) =>
                            setModalState(() => localQuery = value),
                        decoration: InputDecoration(
                          hintText:
                              'Buscar usuario por nombre, documento o correo',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay usuarios para mostrar',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final user = filtered[index];
                                  final nombre = (user['nombre'] ?? 'Usuario')
                                      .toString()
                                      .trim();
                                  final documento = (user['documento'] ?? '')
                                      .toString()
                                      .trim();
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      onTap: () =>
                                          Navigator.of(context).pop(user),
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFFE7DAFB),
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.rolePsicologo,
                                        ),
                                      ),
                                      title: Text(
                                        nombre,
                                        style: AppTextStyles.titleLarge,
                                      ),
                                      subtitle: Text(
                                        documento.isEmpty
                                            ? 'Sin documento'
                                            : 'Doc: $documento',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      await _createOrOpenChatFromUser(selected);
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _chats;

    return _chats.where((chat) {
      final motivo = (chat['Motivo'] ?? '').toString().toLowerCase();
      final categoria = (chat['Categoria'] ?? '').toString().toLowerCase();
      final mensaje = (chat['Mensaje'] ?? '').toString().toLowerCase();
      final usuario = _resolvePatientName(chat).toLowerCase();
      return motivo.contains(query) ||
          categoria.contains(query) ||
          mensaje.contains(query) ||
          usuario.contains(query);
    }).toList();
  }

  String _resolvePatientName(Map<String, dynamic> chat) {
    final explicitName = _readString(chat, const [
      'nombre_usuario',
      'nombreUsuario',
      'Nombre_usuario',
      'Paciente_nombre',
      'pacienteNombre',
    ]);
    if (explicitName.isNotEmpty) return explicitName;

    final documento = (chat['Documento_usuario'] ?? '').toString().trim();
    if (documento.isNotEmpty) return documento;
    return 'Paciente sin nombre';
  }

  String _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return '';
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      appBar: AppBar(
        title: const Text('Chats de pacientes'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _creatingChat ? null : _openNewChatPicker,
            icon: _creatingChat
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_comment_outlined),
            label: const Text('Nuevo chat'),
          ),
          IconButton(onPressed: _loadChats, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(nombre: _nombre, documento: _documento),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar por motivo, categoría o documento',
                hintStyle: AppTextStyles.bodyLarge.copyWith(
                  color: const Color(0xFF6E6A7A),
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
                  borderSide: const BorderSide(
                    color: Color(0xFFB89BEA),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        'No se pudieron cargar los chats\n$_error',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    )
                  : _filteredChats.isEmpty
                  ? Center(
                      child: Text(
                        'No hay chats para mostrar',
                        style: AppTextStyles.titleLarge,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          return _ChatItem(
                            chat: chat,
                            patientName: _resolvePatientName(chat),
                            onTap: () => _openConversation(chat),
                            onInfoTap: () => _showDetails(chat),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openConversation(Map<String, dynamic> chat) async {
    final chatId = (chat['id'] ?? '').toString().trim();
    if (chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este chat no tiene un identificador válido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PsychologistConversationPage(
          chatId: chatId,
          initialPatientName: _resolvePatientName(chat),
        ),
      ),
    );
    await _loadChats();
  }

  void _showDetails(Map<String, dynamic> chat) {
    final usuario = _resolvePatientName(chat);
    final motivo = (chat['Motivo'] ?? '').toString().trim();
    final categoria = (chat['Categoria'] ?? '').toString().trim();
    final mensaje = (chat['Mensaje'] ?? '').toString().trim();
    final fechaRaw = (chat['Fecha_inicio'] ?? '').toString().trim();
    final fecha = DateTime.tryParse(fechaRaw);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalle del chat', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 12),
              Text('Paciente: $usuario', style: AppTextStyles.bodyLarge),
              Text('Motivo: $motivo', style: AppTextStyles.bodyLarge),
              Text('Categoría: $categoria', style: AppTextStyles.bodyLarge),
              if (fecha != null)
                Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}',
                  style: AppTextStyles.bodyLarge,
                ),
              const SizedBox(height: 12),
              Text('Mensaje:', style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              Text(mensaje.isEmpty ? 'Sin mensaje' : mensaje),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String nombre;
  final String? documento;

  const _HeaderCard({required this.nombre, required this.documento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E5EE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rolePsicologo.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.healing_outlined,
              color: AppColors.rolePsicologo,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Color(0xFF2E2E3A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  documento == null || documento!.isEmpty
                      ? 'Revisa tus derivaciones y pacientes'
                      : 'Documento: $documento',
                  style: const TextStyle(
                    color: Color(0xFF7C7B8E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String patientName;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _ChatItem({
    required this.chat,
    required this.patientName,
    required this.onTap,
    required this.onInfoTap,
  });

  LinearGradient _generateAvatarGradient(String name) {
    final hash = name.hashCode;
    final index1 = hash.abs() % 5;
    final index2 = (hash.abs() + 2) % 5;

    final colors = [
      [
        const Color.fromARGB(255, 168, 112, 186),
        const Color.fromARGB(255, 145, 129, 237),
      ],
      [
        const Color.fromARGB(255, 153, 118, 189),
        const Color.fromARGB(255, 153, 116, 201),
      ],
      [
        const Color.fromARGB(255, 131, 108, 185),
        const Color.fromARGB(255, 110, 98, 167),
      ],
      [
        const Color.fromARGB(255, 160, 108, 156),
        const Color.fromARGB(255, 197, 111, 205),
      ],
      [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)],
    ];

    return LinearGradient(
      colors: [colors[index1][0], colors[index2][1]],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final motivo = (chat['Motivo'] ?? '').toString().trim();
    final categoria = (chat['Categoria'] ?? '').toString().trim();
    final mensaje = (chat['Mensaje'] ?? '').toString().trim();
    final fechaRaw = (chat['Fecha_inicio'] ?? '').toString().trim();
    final fecha = DateTime.tryParse(fechaRaw);

    final title = patientName.isNotEmpty ? patientName : 'Paciente sin nombre';
    final subtitle = mensaje.isNotEmpty
        ? mensaje
        : (categoria.isNotEmpty ? categoria : 'Sin mensaje inicial');

    final initials = title
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    const cardBg = Colors.white;
    const borderCol = Color(0xFFE8E5EE);
    const textTitleCol = Color(0xFF2E2E3A);
    const textSubCol = Color(0xFF5B7481);

    return Semantics(
      label:
          'Conversación con el paciente $title sobre ${motivo.isNotEmpty ? motivo : "terapia"}.',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderCol, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onInfoTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _generateAvatarGradient(title),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials.isNotEmpty ? initials : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textTitleCol,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textSubCol,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.roleUsuario.withOpacity(
                                    0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Paciente',
                                  style: TextStyle(
                                    color: AppColors.roleUsuario,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (motivo.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0E8F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    motivo,
                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fecha != null
                              ? DateFormat('HH:mm').format(fecha)
                              : '--:--',
                          style: TextStyle(
                            color: textSubCol.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: textSubCol.withOpacity(0.35),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PsychologistConversationPage extends StatefulWidget {
  final String chatId;
  final String? initialPatientName;

  const _PsychologistConversationPage({
    required this.chatId,
    this.initialPatientName,
  });

  @override
  State<_PsychologistConversationPage> createState() =>
      _PsychologistConversationPageState();
}

class _PsychologistConversationPageState
    extends State<_PsychologistConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_PsychChatMessage> _messages = <_PsychChatMessage>[];
  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _currentUid = '';
  String _patientName = '';
  String _lastMessageKey = '';
  Map<String, dynamic> _chat = <String, dynamic>{};

  String get _historyStorageKey => 'chat_history_psicologo_${widget.chatId}';

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _patientName = widget.initialPatientName?.trim() ?? '';
    _restoreLocalHistory();
    _loadChat();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
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
        _patientName = _resolvePatientNameFromChat(chat);
        _syncMessages(chat);
      });
    } catch (error) {
      if (!mounted) return;
      if (showLoader) {
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
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final draft = text;
    final optimisticTimestamp = DateTime.now();

    setState(() {
      _sending = true;
      _messageController.clear();
      _messages.add(
        _PsychChatMessage(
          text: text,
          isFromPatient: false,
          timestamp: optimisticTimestamp,
        ),
      );
      _lastMessageKey =
          '${optimisticTimestamp.toIso8601String()}|$_currentUid|${text.toLowerCase()}';
    });
    _saveLocalHistory();

    _scrollToBottom();

    try {
      await ChatService.updateChatMessage(
        chatId: widget.chatId,
        message: text,
        authorUid: _currentUid,
        authorRole: 'psicologo',
      );
      if (!mounted) return;
      setState(() {
        _chat['Mensaje'] = text;
        _chat['UltimoAutorUid'] = _currentUid;
        _chat['updatedAt'] = DateTime.now().toIso8601String();
      });
      await _loadChat(showLoader: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje guardado en el chat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty) {
          _messages.removeLast();
        }
        _messageController.text = draft;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      });
      _saveLocalHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
      _scrollToBottom();
    }
  }

  DateTime? _parseDate(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _resolvePatientNameFromChat(Map<String, dynamic> chat) {
    final direct = _readString(chat, const [
      'Nombre_usuario',
      'nombreUsuario',
      'Paciente_nombre',
      'pacienteNombre',
    ]);
    if (direct.isNotEmpty) return direct;

    if (_patientName.trim().isNotEmpty) return _patientName.trim();
    return 'Paciente';
  }

  String _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return '';
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _syncMessages(Map<String, dynamic> chat) {
    final rawMessages = chat['Mensajes'];
    if (rawMessages is List && rawMessages.isNotEmpty) {
      final oldLast = _messages.isNotEmpty ? _messages.last : null;
      _messages
        ..clear()
        ..addAll(_mapMessages(chat));
      _saveLocalHistory();
      // Scroll solo si llegó un mensaje nuevo
      final newLast = _messages.isNotEmpty ? _messages.last : null;
      if (oldLast != null &&
          newLast != null &&
          (oldLast.text != newLast.text ||
              oldLast.timestamp != newLast.timestamp)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      return;
    }

    final text = (chat['Mensaje'] ?? '').toString().trim();
    if (text.isEmpty) {
      return;
    }

    final authorUid = (chat['UltimoAutorUid'] ?? '').toString().trim();
    final timestamp =
        _parseDate(chat['updatedAt'] ?? chat['Fecha_inicio']) ?? DateTime.now();
    final key =
        '${timestamp.toIso8601String()}|$authorUid|${text.toLowerCase()}';
    if (_lastMessageKey == key) {
      return;
    }

    _lastMessageKey = key;
    final isFromPatient =
        _currentUid.isEmpty || authorUid.isEmpty || authorUid != _currentUid;

    if (_messages.isNotEmpty) {
      final last = _messages.last;
      final sameAuthor = last.isFromPatient == isFromPatient;
      final sameText = last.text.trim().toLowerCase() == text.toLowerCase();
      final closeTime =
          timestamp.difference(last.timestamp).inSeconds.abs() <= 15;
      if (sameAuthor && sameText && closeTime) {
        return;
      }
    }

    final wasAtBottom =
        _scrollController.hasClients &&
        (_scrollController.position.maxScrollExtent -
                _scrollController.offset <=
            20);
    _messages.add(
      _PsychChatMessage(
        text: text,
        isFromPatient: isFromPatient,
        timestamp: timestamp,
      ),
    );
    _saveLocalHistory();
    if (wasAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _restoreLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_historyStorageKey);
      if (encoded == null || encoded.trim().isEmpty) return;

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;

      final restored = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) {
            final text = (item['text'] ?? '').toString().trim();
            if (text.isEmpty) {
              return null;
            }
            return _PsychChatMessage(
              text: text,
              isFromPatient: item['isFromPatient'] == true,
              timestamp: _parseDate(item['timestamp']) ?? DateTime.now(),
            );
          })
          .whereType<_PsychChatMessage>()
          .toList();

      if (!mounted || restored.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      // Si falla lectura local, continúa flujo normal.
    }
  }

  Future<void> _saveLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _messages
          .map(
            (message) => <String, dynamic>{
              'text': message.text,
              'isFromPatient': message.isFromPatient,
              'timestamp': message.timestamp.toIso8601String(),
            },
          )
          .toList();
      await prefs.setString(_historyStorageKey, jsonEncode(payload));
    } catch (_) {
      // Ignorar errores de guardado local.
    }
  }

  List<_PsychChatMessage> _mapMessages(Map<String, dynamic> chat) {
    final rawMessages = chat['Mensajes'];
    if (rawMessages is! List || rawMessages.isEmpty) {
      final text = (chat['Mensaje'] ?? '').toString().trim();
      if (text.isEmpty) return <_PsychChatMessage>[];

      final authorUid = (chat['UltimoAutorUid'] ?? '').toString().trim();
      final isFromPatient =
          _currentUid.isEmpty || authorUid.isEmpty || authorUid != _currentUid;

      return <_PsychChatMessage>[
        _PsychChatMessage(
          text: text,
          isFromPatient: isFromPatient,
          timestamp:
              _parseDate(chat['updatedAt'] ?? chat['Fecha_inicio']) ??
              DateTime.now(),
        ),
      ];
    }

    return rawMessages
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final text = (map['texto'] ?? map['Mensaje'] ?? '').toString().trim();
          final autor = (map['autor'] ?? map['Autor'] ?? 'usuario')
              .toString()
              .trim()
              .toLowerCase();
          final isFromPatient = autor != 'psicologo';

          return _PsychChatMessage(
            text: text,
            isFromPatient: isFromPatient,
            timestamp:
                _parseDate(map['timestamp'] ?? map['fecha'] ?? map['Fecha']) ??
                _parseDate(chat['Fecha_inicio']) ??
                DateTime.now(),
          );
        })
        .where((message) => message.text.isNotEmpty)
        .toList();
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
    final usuario = _patientName.trim();
    final motivo = (_chat['Motivo'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      appBar: AppBar(
        title: Text(usuario.isEmpty ? 'Paciente' : usuario),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (motivo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(motivo, style: AppTextStyles.titleLarge),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          'No se pudo abrir el chat\n$_error',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _PsychChatBubble(message: _messages[index]);
                        },
                      ),
              ),
              const SizedBox(height: 10),
              _PsychComposerBar(
                controller: _messageController,
                sending: _sending,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PsychComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _PsychComposerBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E5EE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: Color(0xFF2E2E3A), fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'Escribe una respuesta...',
                hintStyle: TextStyle(color: Color(0xFF9E9CAF), fontSize: 14.5),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Enviar respuesta',
            button: true,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: sending ? null : onSend,
                padding: EdgeInsets.zero,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PsychChatMessage {
  final String text;
  final bool isFromPatient;
  final DateTime timestamp;

  const _PsychChatMessage({
    required this.text,
    required this.isFromPatient,
    required this.timestamp,
  });
}

class _PsychChatBubble extends StatelessWidget {
  final _PsychChatMessage message;

  const _PsychChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isFromPatient = message.isFromPatient;

    final bubbleColor = isFromPatient ? Colors.white : const Color(0xFF8B5CF6);

    final textColor = isFromPatient ? const Color(0xFF2E2E3A) : Colors.white;

    final borderColor = isFromPatient
        ? const Color(0xFFE8E5EE)
        : Colors.transparent;

    final alignment = isFromPatient
        ? Alignment.centerLeft
        : Alignment.centerRight;

    final borderRadius = isFromPatient
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isFromPatient
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14.5, height: 1.3),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(message.timestamp.toLocal()),
              style: TextStyle(
                color: isFromPatient
                    ? const Color(0xFF7C7B8E)
                    : Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
