import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/repositories.dart';

/// Returns true when no cloud backend is configured or a staff session exists
/// (signing in through a dialog when needed).
Future<bool> ensureStaffSignedIn(
  BuildContext context,
  AppController controller,
) async {
  if (await controller.hasStaffSession()) return true;
  if (!context.mounted) return false;
  final signedIn = await showDialog<bool>(
    context: context,
    builder: (_) => _StaffSignInDialog(controller: controller),
  );
  return signedIn ?? false;
}

class _StaffSignInDialog extends StatefulWidget {
  const _StaffSignInDialog({required this.controller});

  final AppController controller;

  @override
  State<_StaffSignInDialog> createState() => _StaffSignInDialogState();
}

class _StaffSignInDialogState extends State<_StaffSignInDialog> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _identifier.text.trim().isEmpty || _password.text.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.signInStaff(
        _identifier.text.trim(),
        _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is StaffSignInException
              ? switch (error.stage) {
                  'auth' =>
                    'فشل Supabase Auth (signInWithPassword): ${error.detail}',
                  'rpc' =>
                    'نجح الدخول لكن فشل استدعاء is_staff: ${error.detail}',
                  _ => 'نجح الدخول لكن ${error.detail} (ليس موظفًا فعّالًا).',
                }
              : 'تعذر تسجيل الدخول: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تسجيل دخول الموظف'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _identifier,
          autofocus: true,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.text,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني أو رقم الهاتف',
            hintText: 'أدخل البريد الإلكتروني أو رقم الهاتف',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'كلمة المرور'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('دخول'),
      ),
    ],
  );
}
