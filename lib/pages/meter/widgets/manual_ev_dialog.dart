import 'package:flutter/material.dart';

class ManualEvDialog extends StatefulWidget {
  const ManualEvDialog({this.initialEv, super.key});
  final double? initialEv;

  static Future<double?> show(BuildContext context, {double? initialEv}) {
    return showDialog<double>(
      context: context,
      builder: (_) => ManualEvDialog(initialEv: initialEv),
    );
  }

  @override
  State<ManualEvDialog> createState() => _ManualEvDialogState();
}

class _ManualEvDialogState extends State<ManualEvDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialEv?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动输入 EV'),
      content: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: const InputDecoration(hintText: '例如 12.5'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_ctrl.text.trim());
            if (v != null) Navigator.pop(context, v);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
