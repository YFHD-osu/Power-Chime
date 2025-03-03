import 'package:charge_sound/database.dart';

import 'package:charge_sound/power_listener.dart';
import 'package:charge_sound/sound_player.dart';
import 'package:charge_sound/task.dart';
import 'package:logger/logger.dart';

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