import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    
    String statusText = "Ready to Focus?";
    if (timerState.status == TimerStatus.running) statusText = "Focus Mode";
    if (timerState.status == TimerStatus.paused) statusText = "Paused";
    if (timerState.status == TimerStatus.breakTime) statusText = "Break Time ☕";
    
    // Format MM:SS
    final minutes = (timerState.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (timerState.remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Study Timer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SESSIONS COUNT
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text(
                "Sessions Completed: ${timerState.sessionsCompleted}",
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),

            // PROGRESS CIRCLE
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: timerState.progress,
                    strokeWidth: 15,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                       timerState.status == TimerStatus.breakTime ? Colors.green : primaryColor
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$minutes:$seconds",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                         fontFeatures: const [FontFeature.tabularFigures()], // Fixed width numbers
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    )
                  ],
                )
              ],
            ),
            const SizedBox(height: 30),

            // PRESETS (Only shown when not running)
            if (timerState.status == TimerStatus.initial || timerState.status == TimerStatus.finished)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PresetButton(label: "25m", minutes: 25, active: true),
                  const SizedBox(width: 15),
                  _PresetButton(label: "45m", minutes: 45),
                  const SizedBox(width: 15),
                  _PresetButton(label: "60m", minutes: 60),
                ],
              ),
            const SizedBox(height: 50),

            // CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // RESET
                IconButton(
                  onPressed: notifier.resetTimer,
                  icon: const Icon(Icons.refresh, size: 30),
                  color: Colors.grey,
                  tooltip: "Reset",
                ),
                const SizedBox(width: 30),
                
                // PLAY / PAUSE
                FloatingActionButton.large(
                  onPressed: () {
                    if (timerState.status == TimerStatus.running || timerState.status == TimerStatus.breakTime) {
                      notifier.pauseTimer();
                    } else {
                      notifier.startTimer();
                    }
                  },
                  backgroundColor: primaryColor,
                  child: Icon(
                    (timerState.status == TimerStatus.running || (timerState.status == TimerStatus.breakTime && timerState.remainingSeconds > 0)) 
                    ? Icons.pause_rounded 
                    : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(width: 30),
                
                // SETTINGS (Placeholder)
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings, size: 30),
                  color: Colors.grey,
                  tooltip: "Settings",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends ConsumerWidget {
  final String label;
  final int minutes;
  final bool active;

  const _PresetButton({
    required this.label,
    required this.minutes,
    this.active = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final isSelected = (timerState.initialSeconds == minutes * 60);
    final primaryColor = Theme.of(context).primaryColor;

    return OutlinedButton(
      onPressed: () {
        ref.read(timerProvider.notifier).startCustomTimer(minutes);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : primaryColor,
        backgroundColor: isSelected ? primaryColor : Colors.transparent,
        side: BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
