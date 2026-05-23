import 'package:flutter/material.dart';

class LockButton extends StatelessWidget {
  const LockButton({
    required this.locked,
    required this.onToggle,
    super.key,
  });

  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onToggle,
      icon: Icon(locked ? Icons.lock : Icons.lock_open),
      label: Text(locked ? '已锁定' : '锁定 EV'),
    );
  }
}
