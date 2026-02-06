import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

enum TimerStatus { initial, running, paused, breakTime, finished }

class TimerState {
  final int remainingSeconds;
  final int initialSeconds; // for progress calculation
  final TimerStatus status;
  final int sessionsCompleted;

  TimerState({
    required this.remainingSeconds,
    required this.initialSeconds,
    required this.status,
    this.sessionsCompleted = 0,
  });

  TimerState copyWith({
    int? remainingSeconds,
    int? initialSeconds,
    TimerStatus? status,
    int? sessionsCompleted,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      initialSeconds: initialSeconds ?? this.initialSeconds,
      status: status ?? this.status,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
    );
  }

  double get progress => remainingSeconds / initialSeconds;
}

class TimerNotifier extends StateNotifier<TimerState> {
  TimerNotifier() : super(TimerState(remainingSeconds: 25 * 60, initialSeconds: 25 * 60, status: TimerStatus.initial));

  Timer? _timer;
  int _currentWorkDuration = 25 * 60; // default 25 mins
  static const int _breakDuration = 5 * 60; // 5 mins

  void startTimer() {
    if (state.status == TimerStatus.running) return;

    state = state.copyWith(status: TimerStatus.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _timer?.cancel();
        _finishSession();
      }
    });
  }

  void startCustomTimer(int minutes) {
    _timer?.cancel();
    _currentWorkDuration = minutes * 60;
    state = state.copyWith(
      status: TimerStatus.running,
      remainingSeconds: _currentWorkDuration,
      initialSeconds: _currentWorkDuration,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _timer?.cancel();
        _finishSession();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    state = state.copyWith(status: TimerStatus.paused);
  }

  void resetTimer() {
    _timer?.cancel();
    state = TimerState(
      remainingSeconds: _currentWorkDuration,
      initialSeconds: _currentWorkDuration,
      status: TimerStatus.initial,
      sessionsCompleted: state.sessionsCompleted
    );
  }

  void _finishSession() {
    if (state.status == TimerStatus.running) {
      // Work session done -> Start break
      _notify("Good job! Take a break.", "You've focused for 25 minutes.");
      state = state.copyWith(
        status: TimerStatus.breakTime,
        remainingSeconds: _breakDuration,
        initialSeconds: _breakDuration,
        sessionsCompleted: state.sessionsCompleted + 1
      );
      startTimer(); // Auto-start break? or wait? Let's auto start break for flow.
    } else if (state.status == TimerStatus.breakTime) {
      // Break done -> Back to work (but paused)
      _notify("Break over!", "Ready to focus again?");
      state = state.copyWith(
        status: TimerStatus.initial,
        remainingSeconds: _currentWorkDuration,
        initialSeconds: _currentWorkDuration,
      );
      // Don't auto-start work, let user choose to continue
    }
  }

  void resetSessionCount() {
    state = state.copyWith(sessionsCompleted: 0);
  }

  Future<void> _notify(String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'dita_planner_channel_v4',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});
