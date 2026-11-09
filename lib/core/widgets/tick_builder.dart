import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] every [interval] while [active] is true, passing the
/// current wall-clock time. The timer itself never counts anything: callers
/// derive elapsed time from stored timestamps, so a throttled background tab
/// or a locked phone cannot lose time.
class TickBuilder extends StatefulWidget {
  const TickBuilder({
    super.key,
    required this.active,
    required this.builder,
    this.interval = const Duration(seconds: 1),
  });

  final bool active;
  final Widget Function(BuildContext context, int nowMs) builder;
  final Duration interval;

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TickBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && _timer == null) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.active && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, DateTime.now().millisecondsSinceEpoch);
}
