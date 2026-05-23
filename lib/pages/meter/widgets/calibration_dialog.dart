import 'package:flutter/material.dart';

class CalibrationDialog extends StatefulWidget {
  const CalibrationDialog({super.key});

  static Future<double?> show(BuildContext context) {
    return showDialog<double>(
      context: context,
      builder: (_) => const CalibrationDialog(),
    );
  }

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('校准测光'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('对准已知 EV 的稳定光源（如阳光直射纸面、Sunny 16 速查），输入参考 EV：'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(hintText: '例如 15'),
          ),
        ],
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
          child: const Text('校准'),
        ),
      ],
    );
  }
}
