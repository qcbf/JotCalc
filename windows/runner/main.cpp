#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  // Skia presents the first frame faster on the Windows OpenGL backend.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(960, 640);
  if (!window.Create(L"JotCalc", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  const HWND handle = window.GetHandle();
  constexpr LPARAM kKeyWasDown = 1L << 30;
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    if (msg.message == WM_KEYDOWN && msg.wParam == VK_ESCAPE &&
        (msg.hwnd == handle || ::IsChild(handle, msg.hwnd)) &&
        ::GetKeyState(VK_CONTROL) >= 0 && ::GetKeyState(VK_SHIFT) >= 0 &&
        ::GetKeyState(VK_MENU) >= 0 && ::GetKeyState(VK_LWIN) >= 0 &&
        ::GetKeyState(VK_RWIN) >= 0) {
      if ((msg.lParam & kKeyWasDown) == 0) {
        // Follow the title bar's close path before tearing down Flutter.
        ::PostMessage(handle, WM_CLOSE, 0, 0);
      }
      continue;
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
