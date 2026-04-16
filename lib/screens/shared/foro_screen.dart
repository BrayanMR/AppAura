import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/foro_service.dart';

import '../../widgets/crear_publicacion_modal.dart';

class ForoScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData heroIcon;
  final String? userRole;

  const ForoScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.heroIcon = Icons.forum_outlined,
    this.userRole,
  });

  @override
  State<ForoScreen> createState() => _ForoScreenState();
}

class _ForoScreenState extends State<ForoScreen> {
  late Future<List<ForoPublicacion>> _futurePublicaciones;
  final Set<String> _likingPosts = <String>{};
  List<ForoPublicacion> _lastPublicaciones = const <ForoPublicacion>[];

  @override
  void initState() {
    super.initState();
    _futurePublicaciones = ForoService.fetchPublicaciones();
  }

  void _reload({bool forceRefresh = false}) {
    setState(() {
      _futurePublicaciones = ForoService.fetchPublicaciones(
        forceRefresh: forceRefresh,
      );
    });
  }

  String _displayName(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;
    final name = (mapArgs?['nombreUsuario'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Usuario Aura';
  }

  String _actorId(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : null;
    final uid = (mapArgs?['uid'] as String?)?.trim();
    if (uid != null && uid.isNotEmpty) return uid;

    final name = (mapArgs?['nombreUsuario'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;

    return 'usuario-aura';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha reciente';
    return DateFormat('dd/MM/yyyy • HH:mm').format(date.toLocal());
  }

  Future<void> _toggleLikeFromFeed(
    BuildContext context,
    ForoPublicacion publicacion,
    String actorId,
  ) async {
    if (_likingPosts.contains(publicacion.id)) return;

    setState(() {
      _likingPosts.add(publicacion.id);
    });

    try {
      await ForoService.toggleLike(
        publicacion: publicacion,
        actorId: actorId,
        currentLikes: publicacion.likes,
        currentLikedBy: publicacion.likedBy,
      );
      if (!mounted) return;
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el me gusta: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _likingPosts.remove(publicacion.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actorId = _actorId(context);
    final userRole = widget.userRole;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.primary.withOpacity(0.06),
              AppColors.secondary.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _AuraBlob(
                color: widget.accentColor.withOpacity(0.18),
                size: 180,
              ),
            ),
            Positioned(
              top: 110,
              left: -70,
              child: _AuraBlob(
                color: AppColors.secondary.withOpacity(0.12),
                size: 150,
              ),
            ),
            FutureBuilder<List<ForoPublicacion>>(
              future: _futurePublicaciones,
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final hasError = snapshot.hasError;
                final publicaciones = snapshot.data ?? _lastPublicaciones;

                if (snapshot.hasData) {
                  _lastPublicaciones = snapshot.data!;
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(forceRefresh: true),
                  color: widget.accentColor,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      if (isLoading && publicaciones.isEmpty)
                        const _LoadingState()
                      else if (hasError)
                        _ErrorState(
                          accentColor: widget.accentColor,
                          message: snapshot.error.toString(),
                          onRetry: () => _reload(forceRefresh: true),
                        )
                      else if (publicaciones.isEmpty)
                        _EmptyState(
                          accentColor: widget.accentColor,
                          icon: widget.heroIcon,
                        )
                      else
                        ...publicaciones.map(
                          (publicacion) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PublicationCard(
                              publicacion: publicacion,
                              accentColor: widget.accentColor,
                              onOpenDetail: () =>
                                  _openPublicationDetail(context, publicacion),
                              isLiking: _likingPosts.contains(publicacion.id),
                              isLiked: publicacion.likedBy.contains(actorId),
                              onLikeTap: () => _toggleLikeFromFeed(
                                context,
                                publicacion,
                                actorId,
                              ),
                              onCommentTap: () => _openCommentSheet(
                                context,
                                publicacion,
                                _displayName(context),
                              ),
                              formatDate: _formatDate,
                            ),
                          ),
                        ),
                      const SizedBox(height: 60),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: userRole == 'psicologo'
          ? FloatingActionButton.extended(
              backgroundColor: widget.accentColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nueva publicación',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                final result = await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      CrearPublicacionModal(accentColor: widget.accentColor),
                );
                if (result == true && mounted) {
                  _reload(forceRefresh: true);
                }
              },
            )
          : null,
    );
  }

  Future<void> _openPublicationDetail(
    BuildContext context,
    ForoPublicacion publicacion,
  ) async {
    final actorId = _actorId(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PublicationDetailSheet(
          publicacion: publicacion,
          accentColor: widget.accentColor,
          formatDate: _formatDate,
          actorId: actorId,
          onLikeChanged: _reload,
        );
      },
    );
  }

  Future<void> _openCommentSheet(
    BuildContext context,
    ForoPublicacion publicacion,
    String authorName,
  ) async {
    final actorUid = _actorId(context);
    final commentText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return _CommentComposerSheet(
          accentColor: widget.accentColor,
          title: publicacion.titulo,
          content: publicacion.contenido,
          onSubmit: (text) => Navigator.of(sheetContext).pop(text),
        );
      },
    );

    final text = commentText?.trim();
    if (text == null || text.isEmpty) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Publicando comentario...'),
        backgroundColor: widget.accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );

    try {
      await ForoService.addComentario(
        publicacion: publicacion,
        autor: authorName,
        texto: text,
        autorUid: actorUid,
      );

      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comentario publicado'),
          backgroundColor: widget.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo comentar: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _CommentComposerSheet extends StatefulWidget {
  final Color accentColor;
  final String title;
  final String content;
  final ValueChanged<String> onSubmit;

  const _CommentComposerSheet({
    required this.accentColor,
    required this.title,
    required this.content,
    required this.onSubmit,
  });

  @override
  State<_CommentComposerSheet> createState() => _CommentComposerSheetState();
}

class _CommentComposerSheetState extends State<_CommentComposerSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.accentColor,
                            widget.accentColor.withOpacity(0.78),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.mode_comment_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comentar publicación',
                            style: AppTextStyles.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _commentController,
                  maxLength: 200,
                  maxLines: 4,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu comentario de apoyo...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppColors.border.withOpacity(0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppColors.border.withOpacity(0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: widget.accentColor,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Publicar comentario'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  final ForoPublicacion publicacion;
  final Color accentColor;
  final VoidCallback onOpenDetail;
  final VoidCallback onLikeTap;
  final bool isLiked;
  final bool isLiking;
  final VoidCallback onCommentTap;
  final String Function(DateTime? date) formatDate;

  const _PublicationCard({
    required this.publicacion,
    required this.accentColor,
    required this.onOpenDetail,
    required this.onLikeTap,
    required this.isLiked,
    required this.isLiking,
    required this.onCommentTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final commentsPreview = publicacion.comentarios.take(2).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accentColor.withOpacity(0.18),
                      child: Text(
                        publicacion.autor.isNotEmpty
                            ? publicacion.autor[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  publicacion.autor.isNotEmpty
                                      ? publicacion.autor
                                      : 'AurApp',
                                  style: AppTextStyles.titleLarge,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  formatDate(publicacion.fecha),
                                  style: AppTextStyles.caption.copyWith(
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            publicacion.titulo,
                            style: AppTextStyles.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  publicacion.contenido,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Opacity(
                      opacity: isLiking ? 0.55 : 1,
                      child: InkWell(
                        onTap: isLiking ? null : onLikeTap,
                        borderRadius: BorderRadius.circular(99),
                        child: _MiniInfo(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: '${publicacion.likes} me gusta',
                          color: isLiked
                              ? AppColors.error
                              : AppColors.secondaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MiniInfo(
                      icon: Icons.mode_comment_outlined,
                      label: '${publicacion.comentarios.length} comentarios',
                      color: accentColor,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor.withOpacity(0.28)),
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: onCommentTap,
                    icon: const Icon(Icons.reply_rounded),
                    label: const Text('Comentar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicationDetailSheet extends StatefulWidget {
  final ForoPublicacion publicacion;
  final Color accentColor;
  final String Function(DateTime? date) formatDate;
  final String actorId;
  final VoidCallback onLikeChanged;

  const _PublicationDetailSheet({
    required this.publicacion,
    required this.accentColor,
    required this.formatDate,
    required this.actorId,
    required this.onLikeChanged,
  });

  @override
  State<_PublicationDetailSheet> createState() =>
      _PublicationDetailSheetState();
}

class _PublicationDetailSheetState extends State<_PublicationDetailSheet> {
  late int _likes;
  late List<String> _likedBy;
  bool _liking = false;

  bool get _isLiked => _likedBy.contains(widget.actorId);

  @override
  void initState() {
    super.initState();
    _likes = widget.publicacion.likes;
    _likedBy = List<String>.from(widget.publicacion.likedBy);
  }

  Future<void> _toggleLike() async {
    if (_liking) return;

    setState(() => _liking = true);
    try {
      final result = await ForoService.toggleLike(
        publicacion: widget.publicacion,
        actorId: widget.actorId,
        currentLikes: _likes,
        currentLikedBy: _likedBy,
      );

      if (!mounted) return;
      setState(() {
        _likes = (result['likes'] as int?) ?? _likes;
        _likedBy = List<String>.from(result['likedBy'] as List? ?? _likedBy);
      });
      widget.onLikeChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el me gusta: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _liking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicacion = widget.publicacion;
    final accentColor = widget.accentColor;
    final formatDate = widget.formatDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.2),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Post', style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accentColor.withOpacity(0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.08),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: accentColor.withOpacity(0.14),
                                child: Text(
                                  publicacion.autor.isNotEmpty
                                      ? publicacion.autor[0].toUpperCase()
                                      : '?',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      publicacion.autor.isNotEmpty
                                          ? publicacion.autor
                                          : 'AurApp',
                                      style: AppTextStyles.titleLarge,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatDate(publicacion.fecha),
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Comunidad',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            publicacion.titulo,
                            style: AppTextStyles.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            publicacion.contenido,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _SocialAction(
                                  icon: _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  label: '$_likes me gusta',
                                  color: _isLiked
                                      ? AppColors.error
                                      : accentColor,
                                  onTap: _liking ? null : _toggleLike,
                                ),
                                const SizedBox(width: 8),
                                _SocialAction(
                                  icon: Icons.mode_comment_outlined,
                                  label:
                                      '${widget.publicacion.comentarios.length}',
                                  color: AppColors.secondaryDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Todos los comentarios (${widget.publicacion.comentarios.length})',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (widget.publicacion.comentarios.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Esta publicación todavía no tiene comentarios.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    else
                      ...widget.publicacion.comentarios.map(
                        (comentario) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SocialCommentTile(
                            comentario: comentario,
                            accentColor: widget.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SocialAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialCommentTile extends StatelessWidget {
  final ForoComentario comentario;
  final Color accentColor;

  const _SocialCommentTile({
    required this.comentario,
    required this.accentColor,
  });

  String _date(DateTime? date) {
    if (date == null) return 'Ahora';
    return DateFormat('dd/MM • HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final commentText = comentario.texto.isNotEmpty
        ? comentario.texto
        : (comentario.respuestaTexto ?? '');
    final hasReply =
        comentario.respuestaTexto != null &&
        comentario.respuestaTexto!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                comentario.autor.isNotEmpty
                    ? comentario.autor[0].toUpperCase()
                    : '?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comentario.autor.isNotEmpty
                            ? comentario.autor
                            : 'Comunidad',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(_date(comentario.fecha), style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    commentText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary.withOpacity(0.95),
                      height: 1.4,
                    ),
                  ),
                ),
                if (hasReply) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            comentario.respuestaTexto!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentPreview extends StatelessWidget {
  final ForoComentario comentario;
  final Color accentColor;

  const _CommentPreview({required this.comentario, required this.accentColor});

  String _date(DateTime? date) {
    if (date == null) return 'Ahora';
    return DateFormat('dd/MM • HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final commentText = comentario.texto.isNotEmpty
        ? comentario.texto
        : (comentario.respuestaTexto ?? '');

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                comentario.autor.isNotEmpty
                    ? comentario.autor[0].toUpperCase()
                    : '?',
                style: AppTextStyles.bodySmall.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comentario.autor.isNotEmpty
                            ? comentario.autor
                            : 'Comunidad',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(_date(comentario.fecha), style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary.withOpacity(0.88),
                    height: 1.35,
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

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniInfo({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AuraBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AuraBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando publicaciones del foro...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Color accentColor;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.accentColor,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 52, color: accentColor),
          const SizedBox(height: 12),
          Text('No se pudo cargar el foro', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accentColor;
  final IconData icon;

  const _EmptyState({required this.accentColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 58, color: accentColor),
          const SizedBox(height: 12),
          Text('Aún no hay publicaciones', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Cuando el equipo comparta contenido, aparecerá aquí para que puedas comentar y acompañar la conversación.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
