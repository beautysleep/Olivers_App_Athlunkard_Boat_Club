import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'club_members.dart';
import 'member_directory.dart';

class FirebaseMemberDirectory implements MemberDirectory {
  const FirebaseMemberDirectory({required this.membershipEndpoint});

  /// The membership function, which is what turns an invite code into a role.
  /// Deployed by infrastructure/membership.tf; its URI is a Terraform output.
  final Uri membershipEndpoint;

  @override
  Future<UserProfile?> currentMember() async {
    final signedIn = FirebaseAuth.instance.currentUser;
    if (signedIn == null) return null;
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(signedIn.uid)
        .get();
    return clubMemberFromDocument(signedIn.uid, profile.data());
  }

  @override
  Future<SignInOutcome> signIn(String email, String password) =>
      _attempt(() async {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return SignInOutcome.succeeded;
      });

  @override
  Future<SignInOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    String? childId,
  }) => _attempt(() async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    final claimed = await _claimMembership(
      displayName: displayName,
      inviteCode: inviteCode,
      childId: childId,
    );
    if (claimed != SignInOutcome.succeeded) {
      // An account with no profile can never be signed in usefully, so it is
      // removed rather than left stranded for someone to trip over later.
      await credential.user?.delete();
      return claimed;
    }

    // The role arrives as a custom claim, and a token minted moments ago does
    // not carry it. Without this refresh the first write is refused and it
    // works only on the second try.
    await credential.user?.getIdToken(true);
    return SignInOutcome.succeeded;
  });

  Future<SignInOutcome> _claimMembership({
    required String displayName,
    required String inviteCode,
    String? childId,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http.post(
      membershipEndpoint,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'display_name': displayName,
        'invite_code': inviteCode,
        'child_uid': ?childId,
      }),
    );
    return switch (response.statusCode) {
      200 => SignInOutcome.succeeded,
      403 => SignInOutcome.inviteCodeRefused,
      _ => SignInOutcome.failed,
    };
  }

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  Future<List<UserProfile>> roster() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return clubRosterFromDocuments({
      for (final document in snapshot.docs) document.id: document.data(),
    });
  }

  /// Firebase's error codes are turned into the handful of outcomes a person
  /// can actually do something about; the rest are one failure, because
  /// "malformed-credential" on a login screen helps nobody.
  Future<SignInOutcome> _attempt(
    Future<SignInOutcome> Function() action,
  ) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      return switch (error.code) {
        'invalid-credential' ||
        'invalid-email' ||
        'user-not-found' ||
        'wrong-password' => SignInOutcome.wrongEmailOrPassword,
        'email-already-in-use' => SignInOutcome.emailAlreadyRegistered,
        'weak-password' => SignInOutcome.weakPassword,
        'network-request-failed' => SignInOutcome.noNetwork,
        _ => SignInOutcome.failed,
      };
    } catch (_) {
      return SignInOutcome.failed;
    }
  }
}
