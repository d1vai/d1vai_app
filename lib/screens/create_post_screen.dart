import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_required_view.dart';
import '../l10n/app_localizations.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _d1vaiService = D1vaiService();

  bool _isLoading = false;
  Timer? _draftDebounce;
  bool _didOfferRestore = false;

  String _draftKeyFor(AuthProvider auth) {
    final uid = auth.user?.id;
    return uid == null ? 'community_draft:anon' : 'community_draft:$uid';
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleDraftSave);
    _contentController.addListener(_scheduleDraftSave);

    // Offer restore only once after first frame (needs Provider context).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeOfferDraftRestore();
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadDraft(AuthProvider auth) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKeyFor(auth));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearDraft(AuthProvider auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKeyFor(auth));
  }

  Future<void> _maybeOfferDraftRestore() async {
    if (_didOfferRestore) return;
    _didOfferRestore = true;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final data = await _loadDraft(auth);
    if (!mounted) return;
    if (data == null) return;

    final draftTitle = (data['title'] ?? '').toString();
    final draftContent = (data['content'] ?? '').toString();
    if (draftTitle.trim().isEmpty && draftContent.trim().isEmpty) return;

    final action = await showDialog<_DraftRestoreAction>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore draft?'),
          content: Text(
            'We found an unsent draft.\n\n'
            'Title: ${draftTitle.trim().isEmpty ? '(empty)' : draftTitle.trim()}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_DraftRestoreAction.discard),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(_DraftRestoreAction.restore),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == _DraftRestoreAction.discard) {
      await _clearDraft(auth);
      return;
    }
    if (action == _DraftRestoreAction.restore) {
      _titleController.text = draftTitle;
      _contentController.text = draftContent;
    }
  }

  void _scheduleDraftSave() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final title = _titleController.text;
    final content = _contentController.text;
    if (title.trim().isEmpty && content.trim().isEmpty) return;

    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _draftKeyFor(auth),
          jsonEncode({
            'v': 1,
            'title': title,
            'content': content,
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );
      } catch (_) {
        // Best-effort only.
      }
    });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _d1vaiService.postCommunityPost({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        // Default values or additional fields can be added here
        'is_public': true,
      });

      if (!mounted) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      unawaited(_clearDraft(auth));

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Post created successfully',
      );

      Navigator.pop(context, true); // Return true to indicate refresh needed
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to create post: $e',
        actionLabel: 'Retry',
        onActionPressed: () {
          if (!_isLoading) _submitPost();
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final authed = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: (!authed || _isLoading) ? null : _submitPost,
            child: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: !authed
          ? LoginRequiredView(
              message:
                  loc?.translate('login_required_create_post_message') ??
                  'Please login first to create a post.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.headlineSmall,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'What\'s on your mind?',
                      border: InputBorder.none,
                    ),
                    style: theme.textTheme.bodyLarge,
                    maxLines: null,
                    minLines: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter some content';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

enum _DraftRestoreAction { discard, restore }
