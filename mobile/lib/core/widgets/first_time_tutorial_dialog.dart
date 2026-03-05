import 'package:flutter/material.dart';

class TutorialStepData {
  const TutorialStepData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class FirstTimeTutorialDialog extends StatefulWidget {
  const FirstTimeTutorialDialog({
    super.key,
    required this.title,
    required this.steps,
    required this.skipText,
    required this.nextText,
    required this.doneText,
  });

  final String title;
  final List<TutorialStepData> steps;
  final String skipText;
  final String nextText;
  final String doneText;

  @override
  State<FirstTimeTutorialDialog> createState() =>
      _FirstTimeTutorialDialogState();
}

class _FirstTimeTutorialDialogState extends State<FirstTimeTutorialDialog> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.steps.length - 1;
    final current = widget.steps[_index];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.skipText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (_, i) {
                  final step = widget.steps[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        child: Icon(step.icon, size: 30),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  if (isLast) {
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  await _pageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
                child: Text(isLast ? widget.doneText : widget.nextText),
              ),
            ),
            Semantics(
              container: true,
              liveRegion: true,
              label: current.title,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
