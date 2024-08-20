import 'dart:ffi';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:logger/logger.dart';

const String defaults = r"""
# You can disable function by commenting lines
# If config file is broken, please delete file and restart program to generate a new one

# run-script:
#   charger-connect: 
#     - start program:
#       - ipconfig
#       - param1
#   charger-disconnect:
#     - pwsh task:
#       - start
#       - path/to/program.exe

# Play sound on charger connect or disconnect
# Please fill in an absolute path of .wav file 
play-sound:
  # charger-connect: 
  charger-disconnect: "path\\to\\your\\file.wav"
""";

final player = SoundPlayer();
final listener = PowerListener();

var logger = Logger(
  printer: PrefixPrinter(
    PrettyPrinter(
      methodCount: 0,
      noBoxingByDefault: true
    )
  )
);

void main() {
  player.initialize();
  listener.initialize();
  logger.d("Application initialize completed.");
  
  listener.listen();
  listener.dispose();
}

class Task {
  final String title;
  final List<String> command;

  Task({
    required this.title,
    required this.command
  });

  factory Task.fromMap(YamlMap res) {
    return Task(
      title: res.keys.first,
      command: List.from(res.values.first)
    );
  }

  String run() {
    try {
      return Process.runSync(command.first, command.sublist(1)).stdout as String;
    } catch(e) {
      return "Error: $e";
    }
  }
}

class SoundPlayer {
  static final lib = DynamicLibrary.open('winmm.dll');
  static final playSound = lib.lookupFunction<
    Int32 Function(Pointer<Utf16> pszSound, IntPtr hmod, Uint32 fdwSound),
    int Function(Pointer<Utf16> pszSound, int hmod, int fdwSound)>('PlaySoundW');
  
  late final File? connect, disconnect;

  void initialize() {
    File file = File("config.yaml");
    if (!file.existsSync()) {
      file.writeAsStringSync(defaults);
    }
    var doc = loadYaml(file.readAsStringSync()) as Map;

    if(doc.containsKey("play-sound")) {
      final root = doc["play-sound"];
      final conn = root["charger-connect"].toString();
      connect = (conn.isNotEmpty && File(conn).existsSync()) ?
        File(root["charger-connect"].toString()) : null;

      final disc = root["charger-disconnect"].toString();
      disconnect = disc.isNotEmpty && File(disc).existsSync() ?
        File(root["charger-disconnect"].toString()) : null;

      logger.i("Load sound connect sound file: ${connect?.path??'None'}");
      logger.i("Load sound disconnect sound file: ${disconnect?.path??'None'}");
    } else {
      logger.i("Play sound function is disabled in config file");
    }

    logger.i("Current charaging state: ${PowerListener.prevState ? 'Charged' : 'Battery'}");
  }

  int play(bool isCharged) {
    final file = isCharged ? connect : disconnect;
    if (file == null) return -1;
    final soundFilePath = TEXT(file.path);
    final result = playSound(soundFilePath, NULL, SND_FILENAME | SND_ASYNC);

    free(soundFilePath);
    return result;
  }
}

class PowerListener {
  static final msg = calloc<MSG>();
  static final hInstance = GetModuleHandle(nullptr);
  static final className = TEXT('Charge Listener');
  static final wndClass = calloc<WNDCLASS>()
    ..ref.style = WNDCLASS_STYLES.CS_HREDRAW | WNDCLASS_STYLES.CS_VREDRAW
    ..ref.lpfnWndProc = Pointer.fromFunction<WNDPROC>(windowProc, 0)
    ..ref.hInstance = hInstance
    ..ref.lpszClassName = className;

  static bool prevState = fetchState();
  static List<Task> connTasks = [], discTask = [];

  static int windowProc(int hWnd, int msg, int wParam, int lParam) {
    switch (msg) {
      case WM_POWERBROADCAST:
        if (wParam == PBT_APMPOWERSTATUSCHANGE) {
          // Power status change detected, check the power status
          final sps = calloc<SYSTEM_POWER_STATUS>();
          GetSystemPowerStatus(sps);
          final plugged = sps.ref.ACLineStatus == 1;
          
          if (plugged && prevState == false) {
            logger.i("Power plugged-in ($prevState)");
            player.play(true);
            for (var task in connTasks) {
              final result = task.run();
              logger.i("Task ${task.title} run and end up with log:\n $result");
            }
            prevState = true;
            
          } else if (!plugged && prevState == true) {
            logger.i("Power un-plugged ($prevState)");
            player.play(false);
            for (var task in discTask) {
              final result = task.run();
              logger.i("Task ${task.title} run and end up with log:\n $result");
            }
            prevState = false;
          }
          
          free(sps);
        }
        break;
      case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
  }

  static bool fetchState() {
    // Initialize COM library
    CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);

    final powerStatus = calloc<SYSTEM_POWER_STATUS>();
    // Call the GetSystemPowerStatus function to retrieve the power status
    GetSystemPowerStatus(powerStatus);
    

    // Clean up
    free(powerStatus);
    CoUninitialize();

    return powerStatus.ref.ACLineStatus == 1;
  }

  void initialize() {
    RegisterClass(wndClass);
    CreateWindowEx(
      0,
      className,
      className,
      WINDOW_STYLE.WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      NULL,
      NULL,
      hInstance,
      nullptr,
    );

    ShowWindow(GetConsoleWindow(), SHOW_WINDOW_CMD.SW_HIDE);
    
    File file = File("config.yaml");
    if (!file.existsSync()) {
      file.writeAsStringSync(defaults);
    }
    var doc = loadYaml(file.readAsStringSync()) as Map;

    if(doc.containsKey("run-script")) {
      final root = doc["run-script"];

      if (root["charger-disconnect"] != null) {
        discTask = (root["charger-disconnect"] as YamlList)
          .map((e) => Task.fromMap(e as YamlMap))
          .toList();
      } else {
        discTask = [];
      }

      if (root["charger-connect"] != null) {
        connTasks = (root["charger-connect"] as YamlList)
          .map((e) => Task.fromMap(e as YamlMap))
          .toList();
      } else {
        connTasks = [];
      }
      
      logger.i("Loaded ${connTasks.length} tasks on connect and ${discTask.length} tasks on disconnect");
    } else {
      logger.i("Run script function is disabled in config file");
    }
  }

  void dispose() {
    free(msg);
    free(wndClass);
    free(className);
  }

  void listen() {
    while(GetMessage(msg, NULL, 0, 0) > 0) {
      TranslateMessage(msg);
      DispatchMessage(msg);
    }
  }
}


