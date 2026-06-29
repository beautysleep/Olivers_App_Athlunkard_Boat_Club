import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/app_scope.dart';
import '../../services/mock_club_repository.dart' show demoPassword;

/// Simple email + password sign-in. Which account you sign in as decides your
/// role. Quick-fill chips make the three demo accounts easy to reach.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    final ok = AppScope.of(context).login(_email.text, _password.text);
    // On success the root listens to AppState and swaps to the role home; we
    // only need to surface failure here.
    if (!ok) setState(() => _error = 'Email or password not recognised.');
  }

  void _fill(UserProfile account) {
    _email.text = account.email;
    _password.text = demoPassword;
    setState(() => _error = null);
  }

  UserProfile? _byRole(List<UserProfile> accounts, UserRole role) {
    for (final a in accounts) {
      if (a.role == role) return a;
    }
    return null;
  }

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.coach => 'Coach',
        UserRole.athlete => 'Athlete',
        UserRole.parent => 'Parent',
      };

  @override
  Widget build(BuildContext context) {
    final accounts = AppScope.of(context).accounts;
    final quickAccounts = [
      _byRole(accounts, UserRole.coach),
      _byRole(accounts, UserRole.athlete),
      _byRole(accounts, UserRole.parent),
    ].whereType<UserProfile>().toList();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.rowing, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Athlunkard Boat Club',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Sign in to see your sessions',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
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
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _signIn,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Demo accounts',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final account in quickAccounts)
                      ActionChip(
                        avatar: const Icon(Icons.person, size: 18),
                        label: Text(
                          '${_roleLabel(account.role)} · '
                          '${account.displayName.split(' ').first}',
                        ),
                        onPressed: () => _fill(account),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap an account to fill it in, then Sign in. '
                  'Password for all: "$demoPassword".',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
