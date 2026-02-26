import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'passenger_controller.dart';

class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '1');
  DateTime? _start;
  DateTime? _end;
  String? _error;

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('So‘rov yaratish')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'Qayerdan')),
          const SizedBox(height: 8),
          TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'Qayerga')),
          const SizedBox(height: 8),
          TextField(controller: _seatsCtrl, decoration: const InputDecoration(labelText: 'Kerakli o‘rindiq (1..4)')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickDate(true),
            child: Text(_start == null ? 'Boshlanish vaqtini tanlang' : 'Boshlanish: $_start'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _pickDate(false),
            child: Text(_end == null ? 'Tugash vaqtini tanlang' : 'Tugash: $_end'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              if (_start == null || _end == null) {
                setState(() => _error = 'Vaqt oralig‘ini kiriting');
                return;
              }
              try {
                final id = await ref.read(passengerActionsProvider).createRequest(
                      from: _fromCtrl.text.trim(),
                      to: _toCtrl.text.trim(),
                      start: _start!,
                      end: _end!,
                      seatsNeeded: int.tryParse(_seatsCtrl.text) ?? 1,
                    );
                if (context.mounted) context.go('/passenger/request-status?requestId=$id');
              } catch (_) {
                setState(() => _error = 'So‘rov yaratishda xatolik');
              }
            },
            child: const Text('Saqlash'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ]
        ],
      ),
    );
  }
}
