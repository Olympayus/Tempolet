#include "win32_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

// DWMWA_WINDOW_CORNER_PREFERENCE (Windows 11); older SDKs do not declare it.
// DWMWCP_ROUND asks the compositor for the same rounded corners as the stock
// frame, which the frameless window would otherwise lose.
constexpr DWORD kDwmwaWindowCornerPreference = 33;
constexpr int kDwmWindowCornerRound = 2;

// App-drawn title bar geometry in logical pixels, scaled to the window DPI at
// hit-test time. Keep in sync with lib/core/ui/app_titlebar.dart.
constexpr int kTitleBarHeight = 32;
constexpr int kTitleBarButtonWidth = 46;
constexpr int kTitleBarResizeBorder = 8;

// Distinct from the subclass ids the window_manager/nativeapi plugin uses.
constexpr UINT_PTR kAppChromeSubclassId = 0x7E4D;

/// Converts |logical| pixels to physical pixels for |window|'s DPI.
int ScaleForWindow(HWND window, int logical) {
  UINT dpi = GetDpiForWindow(window);
  if (dpi == 0) {
    dpi = FlutterDesktopGetDpiForMonitor(
        MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST));
  }
  return MulDiv(logical, static_cast<int>(dpi), 96);
}

enum class TitleBarZone { kNone, kCaption, kMinimize, kMaximize, kClose };

/// Whether the app draws the title bar: the client area reaches the top of the
/// window. With the native frame still in place DefWindowProc keeps the caption
/// and sizing border, so the custom hit-testing must stay out of the way.
///
/// A maximized window is the exception to the rectangle comparison: its frame
/// hangs past the monitor by the sizing border, while the client area matches
/// the work area (window_manager clamps it there).
bool HasAppDrawnTitleBar(HWND window) {
  POINT client_origin = {0, 0};
  RECT window_rect = {};
  if (!ClientToScreen(window, &client_origin) ||
      !GetWindowRect(window, &window_rect)) {
    return false;
  }
  if (client_origin.y <= window_rect.top) {
    return true;
  }
  if (!IsZoomed(window)) {
    return false;
  }
  MONITORINFO monitor = {sizeof(monitor)};
  if (!GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                      &monitor)) {
    return false;
  }
  return client_origin.x == monitor.rcWork.left &&
         client_origin.y == monitor.rcWork.top;
}

/// Which part of the app title bar |client_point| (in client coordinates) is
/// over. Only the top strip is considered; resize borders are handled first by
/// the caller.
TitleBarZone TitleBarZoneAt(HWND window,
                            POINT client_point,
                            const RECT& client) {
  if (client_point.x < 0 || client_point.x >= client.right ||
      client_point.y < 0) {
    return TitleBarZone::kNone;
  }
  if (client_point.y >= ScaleForWindow(window, kTitleBarHeight)) {
    return TitleBarZone::kNone;
  }
  const int button_width = ScaleForWindow(window, kTitleBarButtonWidth);
  if (client_point.x >= client.right - button_width) {
    return TitleBarZone::kClose;
  }
  if (client_point.x >= client.right - 2 * button_width) {
    return TitleBarZone::kMaximize;
  }
  if (client_point.x >= client.right - 3 * button_width) {
    return TitleBarZone::kMinimize;
  }
  return TitleBarZone::kCaption;
}

/// Whether |client_point| is on one of the four 8px resize borders. Maximized
/// windows are not resizable, matching DefWindowProc.
bool IsOverResizeBorder(HWND window, POINT client_point, const RECT& client) {
  if (IsZoomed(window)) {
    return false;
  }
  if (client_point.x < 0 || client_point.x >= client.right ||
      client_point.y < 0 || client_point.y >= client.bottom) {
    return false;
  }
  const int border = ScaleForWindow(window, kTitleBarResizeBorder);
  return client_point.x < border || client_point.x >= client.right - border ||
         client_point.y < border || client_point.y >= client.bottom - border;
}

/// The HT* code for a point the caller already knows is on a resize border.
LRESULT ResizeBorderHitTest(HWND window,
                            POINT client_point,
                            const RECT& client) {
  const int border = ScaleForWindow(window, kTitleBarResizeBorder);
  const bool left = client_point.x < border;
  const bool right = client_point.x >= client.right - border;
  const bool top = client_point.y < border;
  const bool bottom = client_point.y >= client.bottom - border;
  if (top && left) {
    return HTTOPLEFT;
  }
  if (top && right) {
    return HTTOPRIGHT;
  }
  if (bottom && left) {
    return HTBOTTOMLEFT;
  }
  if (bottom && right) {
    return HTBOTTOMRIGHT;
  }
  if (left) {
    return HTLEFT;
  }
  if (right) {
    return HTRIGHT;
  }
  return top ? HTTOP : HTBOTTOM;
}

/// Hit-tests in the Flutter view would otherwise swallow the app title bar and
/// resize borders before the top-level window sees them. HTTRANSPARENT passes
/// the test on to the parent; Windows only does that for windows of the same
/// thread, which the Flutter view is.
LRESULT CALLBACK AppChromeChildProc(HWND child,
                                    UINT message,
                                    WPARAM wparam,
                                    LPARAM lparam,
                                    UINT_PTR subclass_id,
                                    DWORD_PTR) {
  if (message == WM_NCHITTEST) {
    HWND root = GetAncestor(child, GA_ROOT);
    POINT client_point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    RECT client = {};
    if (root != nullptr && root != child && HasAppDrawnTitleBar(root) &&
        GetWindowThreadProcessId(root, nullptr) == GetCurrentThreadId() &&
        ScreenToClient(root, &client_point) &&
        GetClientRect(root, &client)) {
      if (TitleBarZoneAt(root, client_point, client) != TitleBarZone::kNone ||
          IsOverResizeBorder(root, client_point, client)) {
        return HTTRANSPARENT;
      }
    }
  } else if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(child, AppChromeChildProc, subclass_id);
  }
  return DefSubclassProc(child, message, wparam, lparam);
}

/// Makes |child| step aside for the app-drawn title bar. Idempotent.
void AttachAppChromeHitTest(HWND child) {
  if (child == nullptr) {
    return;
  }
  if (!SetWindowSubclass(child, AppChromeChildProc, kAppChromeSubclassId, 0)) {
    // Without the subclass the Flutter view keeps every hit test and the title
    // bar stops working; say so instead of failing silently.
    OutputDebugStringW(
        L"tempolet: SetWindowSubclass failed for the Flutter view\n");
  }
}

/// DWM attributes for the frameless window: Windows 11 rounded corners and a
/// frame extended into the client area so the compositor would keep drawing the
/// window shadow.
///
/// Caveat, not yet GUI-verified: window_manager 0.6 (nativeapi) applies its own
/// frame extent when the title bar style is set from Dart, after this runs. It
/// resets the margins to 0 for a window without a visual effect, disables
/// non-client rendering for an explicit-frameless window and draws the shadow
/// from its own layered-window implementation instead. The corner preference
/// attribute is not touched by nativeapi and persists, but with NC rendering
/// disabled the rounded corners may not be rendered. Treat this as the runner's
/// baseline call only: acceptance item 6 (rounded corners + shadow) is a
/// PENDING-MANUAL check; if it fails, annotate docs/design/10-ui-refinement.md
/// §4 as the plan requires.
void ApplyTitleBarDwm(HWND window) {
  const int corner = kDwmWindowCornerRound;
  DwmSetWindowAttribute(window, kDwmwaWindowCornerPreference, &corner,
                        sizeof(corner));
  const MARGINS margins = {-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(window, &margins);
}

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  ApplyTitleBarDwm(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      ResizeChildContent();
      return 0;
    }

    // Removing the frame changes the client area without changing the window
    // size, so no WM_SIZE follows; keep the Flutter view over the whole window.
    case WM_WINDOWPOSCHANGED:
      ResizeChildContent();
      break;

    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        tracking_nc_mouse_ = false;
        UpdateTitleBarHover(TitleBarButton::kNone);
      }
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    // App-drawn title bar (design 10-ui-refinement §4, decision D60): the top
    // 32 logical px are the caption, the rightmost three 46px cells are the
    // window buttons, and all four edges keep an 8px resize border. Answering
    // HTMAXBUTTON here is also what makes the Windows Snap layout preview
    // appear over the maximize button.
    case WM_NCHITTEST: {
      if (!HasAppDrawnTitleBar(hwnd)) {
        break;
      }
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &point);
      RECT client = {};
      GetClientRect(hwnd, &client);
      // Borders win over the caption so every edge and corner stays grabbable;
      // this matches how the stock frame behaves near the top corners.
      if (IsOverResizeBorder(hwnd, point, client)) {
        return ResizeBorderHitTest(hwnd, point, client);
      }
      switch (TitleBarZoneAt(hwnd, point, client)) {
        case TitleBarZone::kClose:
          return HTCLOSE;
        case TitleBarZone::kMaximize:
          return HTMAXBUTTON;
        case TitleBarZone::kMinimize:
          return HTMINBUTTON;
        case TitleBarZone::kCaption:
          return HTCAPTION;
        case TitleBarZone::kNone:
          break;
      }
      return HTCLIENT;
    }

    // Flutter paints the buttons; the system runs their commands so the
    // minimize animation, Snap and the close-to-tray path stay native.
    case WM_NCLBUTTONDOWN:
      if (!HasAppDrawnTitleBar(hwnd)) {
        break;
      }
      switch (wparam) {
        case HTMAXBUTTON:
          PostMessage(hwnd, WM_SYSCOMMAND,
                      IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE, 0);
          return 0;
        case HTMINBUTTON:
          PostMessage(hwnd, WM_SYSCOMMAND, SC_MINIMIZE, 0);
          return 0;
        case HTCLOSE:
          // SC_CLOSE, not WM_CLOSE: window_manager/nativeapi treats WM_CLOSE as
          // the mandatory close path and destroys the window, while SC_CLOSE is
          // the cancellable request its prevent-close/tray handling intercepts
          // (cnativeapi window_close_windows.cpp). Same as the native button.
          PostMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
          return 0;
        default:
          break;
      }
      break;

    // Tell Flutter which title bar button the pointer is over; it owns the
    // hover paint. WM_NCMOUSELEAVE (armed below) and moves into the client
    // area clear it again.
    case WM_NCMOUSEMOVE: {
      if (!HasAppDrawnTitleBar(hwnd)) {
        break;
      }
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &point);
      RECT client = {};
      GetClientRect(hwnd, &client);
      TitleBarButton button = TitleBarButton::kNone;
      // Same precedence as WM_NCHITTEST: the resize border wins, so the outer
      // 8px of a button does not light up while a click there resizes.
      if (!IsOverResizeBorder(hwnd, point, client)) {
        switch (TitleBarZoneAt(hwnd, point, client)) {
          case TitleBarZone::kMinimize:
            button = TitleBarButton::kMinimize;
            break;
          case TitleBarZone::kMaximize:
            button = TitleBarButton::kMaximize;
            break;
          case TitleBarZone::kClose:
            button = TitleBarButton::kClose;
            break;
          default:
            break;
        }
      }
      UpdateTitleBarHover(button);
      if (!tracking_nc_mouse_) {
        TRACKMOUSEEVENT track = {sizeof(track), TME_LEAVE | TME_NONCLIENT, hwnd,
                                 0};
        tracking_nc_mouse_ = TrackMouseEvent(&track) != FALSE;
      }
      return 0;
    }

    case WM_NCMOUSELEAVE:
      tracking_nc_mouse_ = false;
      UpdateTitleBarHover(TitleBarButton::kNone);
      break;

    case WM_MOUSEMOVE:
      UpdateTitleBarHover(TitleBarButton::kNone);
      break;

    // Later child windows (a recreated Flutter view, for one) must step aside
    // for the title bar too.
    case WM_PARENTNOTIFY:
      if (LOWORD(wparam) == WM_CREATE) {
        AttachAppChromeHitTest(reinterpret_cast<HWND>(lparam));
      }
      break;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  // Make the title bar and resize borders reach this window's message handler.
  AttachAppChromeHitTest(content);

  SetFocus(child_content_);
}

void Win32Window::ResizeChildContent() {
  if (child_content_ == nullptr) {
    return;
  }
  RECT client = GetClientArea();
  // WM_SIZE and WM_WINDOWPOSCHANGED both arrive for one resize; only move the
  // child when it does not already cover the client area.
  RECT content = {};
  if (GetWindowRect(child_content_, &content)) {
    MapWindowPoints(HWND_DESKTOP, window_handle_,
                    reinterpret_cast<POINT*>(&content), 2);
    if (content.left == client.left && content.top == client.top &&
        content.right == client.right && content.bottom == client.bottom) {
      return;
    }
  }
  MoveWindow(child_content_, client.left, client.top, client.right - client.left,
             client.bottom - client.top, TRUE);
}

void Win32Window::UpdateTitleBarHover(TitleBarButton button) {
  if (button == title_bar_button_) {
    return;
  }
  title_bar_button_ = button;
  OnTitleBarHover(button);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
