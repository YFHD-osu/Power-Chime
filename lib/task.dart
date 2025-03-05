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

  void execute()  {
    late ProcessResult result;

    try {
      result = Process.runSync(program, args, runInShell: true);
    } catch (error) {
      logger.e("Process $name failed. $error");
      return;
    }

    print("4");
    logger.i("Process $name end with code ${result.exitCode}");
    logger.d("[STDOUT] ${result.stdout}");
    logger.d("[STDERR] ${result.stderr}");
  }
}