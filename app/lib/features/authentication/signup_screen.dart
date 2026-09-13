import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/app_scope.dart';
import '../../services/member_directory.dart';
import 'sign_in_message.dart';

/// Joining the club. The invite code is what decides the role — it is checked
/// on the server, so nothing here can grant a role by itself.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();
  String? _childId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await AppScope.of(context).signUp(
      email: _email.text.trim(),
      password: _password.text,
      displayName: _name.text.trim(),
      inviteCode: _inviteCode.text.trim(),
      childId: _childId,
    );
    if (!mounted) return;
    if (outcome == SignInOutcome.succeeded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = messageFor(outcome);
    });
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      _inviteCode.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Only a parent needs to name their child, but the role is not known until
    // the server has read the code — so the picker is offered whenever the club
    // has athletes to pick from, and ignored for any other role.
    final athletes = AppScope.of(
      context,
    ).roster.where((member) => member.role == UserRole.athlete).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Join the club')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your coach will have given you a code. It decides whether '
                  'you join as a coach, an athlete or a parent.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _inviteCode,
                  autocorrect: false,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    helperText: 'Shown beside your commitment to a session',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (athletes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _childId,
                    decoration: const InputDecoration(
                      labelText: 'Joining as a parent? Pick your athlete',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.family_restroom_outlined),
                    ),
                    items: [
                      for (final athlete in athletes)
                        DropdownMenuItem(
                          value: athlete.id,
                          child: Text(athlete.displayName),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _childId = value),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (_busy || !_complete) ? null : _join,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join'),
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
