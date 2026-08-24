/// What a sign-in outcome should say to the person in front of the screen.
///
/// Kept apart from both screens because they say the same things, and apart
/// from [MemberDirectory] because wording is not the directory's business.
library;

import '../../services/member_directory.dart';

String? messageFor(SignInOutcome outcome) => switch (outcome) {
  SignInOutcome.succeeded => null,
  SignInOutcome.wrongEmailOrPassword => 'Email or password not recognised.',
  SignInOutcome.emailAlreadyRegistered =>
    'That email already has an account. Sign in instead.',
  SignInOutcome.weakPassword =>
    'Pick a longer password — at least 6 characters.',
  // Deliberately does not say whether the code was wrong, expired or never
  // existed: it is a shared secret, and hints help the wrong people.
  SignInOutcome.inviteCodeRefused =>
    'That invite code is not one of ours. Check with your coach.',
  SignInOutcome.noNetwork => 'No connection. Check your signal and try again.',
  SignInOutcome.failed => 'Something went wrong. Try again in a moment.',
};
