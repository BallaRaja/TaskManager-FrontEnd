# TASK MANAGER WITH AI & NOTIFICATIONS

## Project Documentation Report — UI Module (Initial Phase)

**Flutter • Node.js • MongoDB • OpenAI • Firebase**

---

### Members

| Roll Number       | Name                      |
| ----------------- | ------------------------- |
| CB.SC.U4CSE23312  | Balla Kumar Basavaraju    |
| CB.SC.U4CSE23313  | Chappidi Kuladeep Reddy   |
| CB.SC.U4CSE23343  | Paggilla Saketh           |
| CB.SC.U4CSE23356  | Vejju Sasi Kiran Yasaswi  |

---

## 1. Overview

This document covers the **initial 30 %** of the Task Manager front-end, focusing on the foundational UI layer built with Flutter. The work completed in this phase establishes:

- Project scaffolding and folder structure  
- App-wide theming (light & dark)  
- Authentication screens (Login, Register, OTP Verification, Forgot Password)  
- Bottom-navigation shell and basic page routing  

These components form the visual and navigational backbone upon which the remaining features (AI chat, calendar views, Pomodoro timer, profile management, etc.) are built in later phases.

---

## 2. Technology Stack (UI)

| Layer            | Technology                         |
| ---------------- | ---------------------------------- |
| Framework        | Flutter 3.x (Dart SDK ^3.10.0)    |
| State Management | Provider 6.x                       |
| HTTP Client      | http 1.6.x                         |
| Local Storage    | shared_preferences 2.x             |
| Notifications    | flutter_local_notifications 17.x   |
| Connectivity     | connectivity_plus 6.x              |
| Firebase         | firebase_core, firebase_messaging   |

---

## 3. Project Structure (Relevant to This Phase)

```
lib/
├── main.dart                          # App entry, theme bootstrap, MainAppShell
├── core/
│   ├── constants/
│   │   └── api_constants.dart         # Base URL & endpoint strings
│   ├── theme/
│   │   └── app_theme.dart             # Light / Dark theme definitions
│   ├── utils/
│   │   ├── session_manager.dart       # JWT & userId persistence
│   │   └── validators.dart            # Password-strength checker
│   └── services/                      # Notification & push services
├── features/
│   └── auth/
│       ├── logic/
│       │   └── auth_controller.dart   # Login / Register / OTP API calls
│       └── presentation/
│           ├── login_page.dart        # Login screen
│           ├── register_page.dart     # Registration screen
│           ├── otp_verification_page.dart  # Email OTP verification
│           └── forgot_password_page.dart   # Password-reset flow
└── shared/
    └── widgets/
        └── custom_button.dart         # Reusable button widget
```

---

## 4. Theming

The app ships with a **dual-theme** system defined in `core/theme/app_theme.dart`.

### 4.1 Colour Palette

| Token             | Light Mode    | Dark Mode     |
| ----------------- | ------------- | ------------- |
| Primary           | `#7C4DFF`     | `#9C6BFF`     |
| Secondary         | `#B388FF`     | `#C9A8FF`     |
| Scaffold BG       | `#F5F3FF`     | `#121018`     |
| Surface / Card    | `#FFFFFF`     | `#1E1A2B`     |
| Text Primary      | `#1A1A1A`     | `#FFFFFF`     |
| Text Secondary    | `#616161`     | `#BDBDBD`     |
| Success           | `#4CAF50`     | `#66BB6A`     |
| Error             | `#EF5350`     | `#EF5350`     |

### 4.2 Theme Persistence

- The user's theme preference is stored via `SharedPreferences` under the key `is_dark_mode`.  
- On app launch, the saved preference is read and applied before the first frame renders.

---

## 5. Authentication Screens

All auth screens share a consistent visual language:

- **Wave header** — A gradient container clipped with a custom `WaveClipper` (quadratic Bézier curve) that displays the page title in white.  
- **Outlined input fields** — Each `TextField` uses `OutlineInputBorder` with a 14 px corner radius, a subtle fill colour, and a themed prefix icon.  
- **Rounded action buttons** — Primary buttons use a 27 px radius `ElevatedButton`, while secondary actions use a matching `OutlinedButton`.

### 5.1 Login Page (`login_page.dart`)

| Element            | Details                                                |
| ------------------ | ------------------------------------------------------ |
| Email field        | `TextInputType.emailAddress`, email icon prefix        |
| Password field     | Obscured text, visibility toggle suffix icon           |
| Forgot password    | Text link → navigates to `ForgotPasswordPage`          |
| Login button       | Calls `AuthController.login()`, shows a `CircularProgressIndicator` while loading |
| Sign Up link       | Navigates to `RegisterPage`                            |
| Post-login         | Saves JWT + userId via `SessionManager`, then pushes `MainAppShell` |

### 5.2 Register Page (`register_page.dart`)

| Element                  | Details                                                   |
| ------------------------ | --------------------------------------------------------- |
| Name field               | Person icon prefix                                        |
| Email field              | Email icon prefix                                         |
| Password field           | Real-time **strength meter** (linear progress bar) with 5 requirement chips: 8+ chars, uppercase, lowercase, number, special character |
| Confirm Password field   | Must match password; visibility toggle                    |
| Register button          | Calls `AuthController.register()` → navigates to OTP page |

### 5.3 OTP Verification Page (`otp_verification_page.dart`)

- Accepts the 6-digit OTP sent to the user's email.  
- Provides a **Resend OTP** option with a cooldown timer.  
- On successful verification the user is routed to the Login page.

### 5.4 Forgot Password Page (`forgot_password_page.dart`)

- Single email input to receive a password-reset link / OTP.  
- Follows the same wave-header + outlined-field design.

---

## 6. App Shell & Navigation

`MainAppShell` (in `main.dart`) is the primary post-login scaffold:

| Component               | Description                                      |
| ------------------------ | ------------------------------------------------ |
| `BottomNavigationBar`    | Three tabs — **Tasks**, **AI**, **Calendar**     |
| `IndexedStack`           | Preserves page state across tab switches         |
| Offline banner           | A top banner that appears when the device loses connectivity or a background sync is in progress |

At this phase only the **navigation shell** and the **Tasks** stub page are wired; the AI and Calendar views are placeholders.

---

## 7. Screens Completed in This Phase

| #  | Screen               | File                          | Status     |
| -- | -------------------- | ----------------------------- | ---------- |
| 1  | Login                | `login_page.dart`             | ✅ Done    |
| 2  | Register             | `register_page.dart`          | ✅ Done    |
| 3  | OTP Verification     | `otp_verification_page.dart`  | ✅ Done    |
| 4  | Forgot Password      | `forgot_password_page.dart`   | ✅ Done    |
| 5  | App Shell (Nav Bar)  | `main.dart`                   | ✅ Done    |
| 6  | Theme System         | `app_theme.dart`              | ✅ Done    |

---

## 8. Screens Remaining (Planned for Subsequent Phases)

| #  | Screen / Feature              | File(s)                                |
| -- | ----------------------------- | -------------------------------------- |
| 1  | Tasks Page (List + CRUD)      | `tasks_page.dart`, `add_task_sheet.dart`, `edit_task_sheet.dart`, `task_item.dart` |
| 2  | Task Lists / Tabs             | `task_list_tab.dart`, `completed_section.dart` |
| 3  | Summary / Analytics Page      | `summary_page.dart`                    |
| 4  | AI Chat                       | `ai_chat_page.dart`, `message_bubble.dart`, `typing_indicator.dart` |
| 5  | AI Day Planner                | `day_planner_page.dart`                |
| 6  | AI Week Planner               | `week_planner_page.dart`               |
| 7  | Calendar (Monthly / Weekly / Daily) | `calendar_page.dart`, `monthly_view.dart`, `weekly_view.dart`, `daily_view.dart` |
| 8  | Pomodoro Timer                | `pomodoro_page.dart`                   |
| 9  | Profile Management            | `manage_profile.dart`, `profile_sheet.dart`, `avatar_crop_page.dart` |
| 10 | Push Notifications UI         | Notification routes & overlays         |

---

## 9. Design Guidelines Followed

1. **Consistency** — Every screen reuses the same colour tokens from `AppTheme` and the same input-field decoration pattern.  
2. **Responsiveness** — Wave header height is proportional to `MediaQuery.of(context).size.height * 0.35`.  
3. **Accessibility** — Sufficient contrast ratios between text and background in both themes; all icons have semantic labels through their surrounding widgets.  
4. **Dark Mode** — Full parity between light and dark variants; no hard-coded colours outside the theme file.

---

## 10. How to Run

```bash
# 1. Clone the repository
git clone https://github.com/BallaRaja/TaskManager-FrontEnd.git

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device / emulator
flutter run
```

> **Minimum SDK:** Dart ^3.10.0 | Flutter 3.x

---

*This document represents ~30 % of the total front-end work — covering project setup, theming, authentication UI, and the navigation shell. Subsequent phases will add task management, AI features, calendar views, Pomodoro timer, and profile management.*
