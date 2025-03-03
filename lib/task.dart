import 'dart:io';
import 'package:yaml/yaml.dart';

import 'package:charge_sound/logger.dart';

enum State {
  plugged,
  unplugged
}

class Task {
  final String name, program;
  final List<String> args;
  final State event;

  Task({
    required this.name,
    required this.program,
    required this.args,
    required this.event
  });

  factory Task.fromMap(Map res) {
    return Task(
      name: res["name"]!,
      program: res["program"]!,
      args: (res["args"] as YamlList?)?.cast<String>() ?? [],
      event: (res["event"]! == "connect") ? State.plugged : State.unplugged,
    );
  }

  Future<void> execute() async {
    final process = await Process.run(program, args);
    logger.i(process.stdout);
  }
}