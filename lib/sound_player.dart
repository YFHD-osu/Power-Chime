import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class SoundPlayer {
  static final lib = DynamicLibrary.open('winmm.dll');
  static final playSound = lib.lookupFunction<
    Int32 Function(Pointer<Utf16> pszSound, IntPtr hmod, Uint32 fdwSound),
    int Function(Pointer<Utf16> pszSound, int hmod, int fdwSound)>('PlaySoundW');
  
  late final File? connect, disconnect;

  static int play(File file) {
    final soundFilePath = TEXT(file.path);
    final result = playSound(soundFilePath, NULL, SND_FILENAME | SND_ASYNC);

    free(soundFilePath);
    return result;
  }
}