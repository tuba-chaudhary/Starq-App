import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps a screen in a smooth fade + gentle slide-in-from-right transition.
/// Use this in every GoRoute's `pageBuilder` instead of `builder` for a
/// consistent, polished feel across the whole app.
Page<void> buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0), // subtle — not a full-screen slide
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}