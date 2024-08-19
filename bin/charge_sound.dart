import 'dart:ffi';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:logger/logger.dart';

const String defaults = """
sound-file:
  charger-connect: ""
  charger-disconnect: ""
""";

final player = SoundPlayer();
final listener = PowerListener();

var logger = Logger(
  printer: PrettyPrinter(),
);

void main() {
  player.initialize();
  listener.initialize();
  logger.d("Application initialize completed.");
  
  listener.listen();
  listener.dispose();
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

    final conn = doc["charger-connect"].toString();
    connect = (conn.isNotEmpty && File(conn).existsSync()) ?
      File(doc["charger-connect"].toString()) : null;

    final disc = doc["charger-disconnect"].toString();
    disconnect = disc.isNotEmpty && File(disc).existsSync() ?
      File(doc["charger-disconnect"].toString()) : null;

    logger.d("Set conn sound: ${connect?.path}");
    logger.d("Set disc cound: ${disconnect?.path}");

    logger.d("Initial power state: ${PowerListener.prevState}");
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

  static int windowProc(int hWnd, int msg, int wParam, int lParam) {
    switch (msg) {
      case WM_POWERBROADCAST:
        if (wParam == PBT_APMPOWERSTATUSCHANGE) {
          // Power status change detected, check the power status
          final sps = calloc<SYSTEM_POWER_STATUS>();
          GetSystemPowerStatus(sps);
          final plugged = sps.ref.ACLineStatus == 1;
          
          if (plugged && prevState == false) {
            logger.d("Power plugged-in ($prevState)");
            player.play(true);
            prevState = true;
            
          } else if (!plugged && prevState == true) {
            logger.d("Power un-plugged ($prevState)");
            player.play(false);
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


