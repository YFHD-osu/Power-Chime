import 'dart:io';
import 'package:yaml/yaml.dart';

import 'package:power_chime/logger.dart';
import 'package:power_chime/task.dart';

const defaultYaml = """
# Comment field to disable function

########################
# Charge Sound Section #
########################
charger-connect: "path/to/wav/file.wav"
charger-disconnect: "path/to/wav/file.wav"

####################
# Run Task Section #
####################
tasks:
  - name: On connect task example
    event: connect
    program: "path/to/program"
    args:
      - "-v"
      - "-args_here"

  - name: On disconnect task example
    event: disconnect
    program: "path/to/program"
    args:
      - "-v"
      - "-args_here"
""";

class Preferences {
  static File? onConnSound, onDiscSound;
  static final List<Task> tasks = [];

  static Future<void> initialize() async {
    final rawConfig = File(".\\config.yaml");

    if (! await rawConfig.exists()) {
      await rawConfig.create();
      await rawConfig.writeAsString(defaultYaml);
    }
    
    final context = await rawConfig.readAsString();

    late final Map doc;
    try {
      doc = loadYaml(context) as Map;
    } on YamlException catch (error) {
      logger.e("Failed to parse config file: ${error.message} ${error.offset}");
      exit(1);
    }
    
    late File file;
    
    file = File(doc["charger-connect"].toString());
    if (await file.exists()) {
      onConnSound = file;
    }

    file = File(doc["charger-disconnect"].toString());
    if (await file.exists()) {
      onDiscSound = file;
    }

    final rawTasks = (doc["tasks"] as YamlList?)?.cast<Map>();

    if (rawTasks == null) {
      return;
    }

    for (var item in rawTasks) {
      tasks.add(Task.fromMap(item));
    }
  }
}