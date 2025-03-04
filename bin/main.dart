import 'package:logger/logger.dart';

import 'package:power_chime/database.dart';
import 'package:power_chime/power_listener.dart';
import 'package:power_chime/sound_player.dart';
import 'package:power_chime/task.dart';

final Logger logger = Logger();

late bool prevState;

void main() async {
  await Preferences.initialize();

  PowerListener.onChanged = onStateChange;
  PowerListener.initialize();

  prevState = PowerListener.plugged;

  logger.d("Application initialize completed.");

  PowerListener.loop();
}

void onStateChange() async {
  logger.i("Plugged: ${PowerListener.plugged} (${PowerListener.percentage}%)");

  if (PowerListener.plugged && prevState == false) {
    if (Preferences.onConnSound != null) {
      SoundPlayer.play(Preferences.onConnSound!);
    }

    final tasks = Preferences.tasks
      .where((e) => e.event == State.plugged);

    for (var item in tasks) {
      await item.execute();
    }

    prevState = true;    
  } else if (!PowerListener.plugged && prevState == true) {
    if (Preferences.onDiscSound != null) {
      SoundPlayer.play(Preferences.onDiscSound!);
    }

    final tasks = Preferences.tasks
      .where((e) => e.event == State.unplugged);

    for (var item in tasks) {
      await item.execute();
    }

    prevState = false;    
  }
}