import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FlowBody extends StatelessWidget {
  const FlowBody({required this.children, this.maxWidth = 760, super.key});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.medium),
                    child: child,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

AppBar flowAppBar(BuildContext context, String title, {Widget? leading}) =>
    AppBar(
      toolbarHeight: 64 * MediaQuery.textScalerOf(context).scale(1),
      title: Text(title, maxLines: 2),
      leading: leading,
    );

class FlowError extends StatelessWidget {
  const FlowError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
