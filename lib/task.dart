import 'dart:io';
import 'package:yaml/yaml.dart';

import 'package:power_chime/logger.dart';

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
    late ProcessResult result;
    try {
      result = await Process.run(program, args);
    } catch (error) {
      logger.e("Process $name failed. $error");
      return;
    }

    logger.i("Process $name end with code ${result.exitCode}");
    logger.d("[STDOUT] ${result.stdout}");
    logger.d("[STDERR] ${result.stderr}");
  }
}