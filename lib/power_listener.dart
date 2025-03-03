import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class PowerListener {
  static late Function() onChanged;
  static late SYSTEM_POWER_STATUS status;

  static final _msg = calloc<MSG>();
  static final _hInstance = GetModuleHandle(nullptr);
  static final _className = TEXT('Charge Listener');
  static final _wndClass = calloc<WNDCLASS>()
    ..ref.style = WNDCLASS_STYLES.CS_HREDRAW | WNDCLASS_STYLES.CS_VREDRAW
    ..ref.lpfnWndProc = Pointer.fromFunction<WNDPROC>(_windowProc, 0)
    ..ref.hInstance = _hInstance
    ..ref.lpszClassName = _className;

  static bool get plugged =>
    status.ACLineStatus == 1;

  static int get percentage =>
    status.BatteryLifePercent;

  static int _windowProc(int hWnd, int msg, int wParam, int lParam) {
    switch (msg) {
      case WM_POWERBROADCAST:
        if (wParam == PBT_APMPOWERSTATUSCHANGE) {
          // Power status change detected, check the power status
          final sps = calloc<SYSTEM_POWER_STATUS>();
          GetSystemPowerStatus(sps);
          status = sps.ref;
          onChanged();
          free(sps);
        }
        break;
      case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
  }

  static SYSTEM_POWER_STATUS fetchState() {
    // Initialize COM library
    CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);

    final powerStatus = calloc<SYSTEM_POWER_STATUS>();
    // Call the GetSystemPowerStatus function to retrieve the power status
    GetSystemPowerStatus(powerStatus);
    

    // Clean up
    free(powerStatus);
    CoUninitialize();

    return powerStatus.ref;
  }

  static void initialize() {
    RegisterClass(_wndClass);
    CreateWindowEx(
      0,
      _className,
      _className,
      WINDOW_STYLE.WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      CW_USEDEFAULT,
      NULL,
      NULL,
      _hInstance,
      nullptr,
    );

    ShowWindow(GetConsoleWindow(), SHOW_WINDOW_CMD.SW_HIDE);

    status = fetchState();
  }

  static Future<void> loop() async {
    while(GetMessage(_msg, NULL, 0, 0) > 0) {
      TranslateMessage(_msg);
      DispatchMessage(_msg);
    }

    free(_msg);
    free(_wndClass);
    free(_className);

    return;
  }
}