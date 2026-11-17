import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_shell.dart';
import '../../features/calendar/calendar_page.dart';
import '../../features/completed/completed_page.dart';
import '../../features/reminders/category_management_page.dart';
import '../../features/reminders/reminders_page.dart';
import '../../features/settings/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/calendar',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarPage(),
                routes: [
                  // Nested so the icon rail and shell survive; the spec's
                  // `/completed` is short-form.
                  GoRoute(
                    path: 'completed',
                    builder: (context, state) => const CompletedPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reminders',
                builder: (context, state) => const RemindersPage(),
                routes: [
                  // Shared completed page entering from the reminders branch;
                  // the rail selection stays on reminders.
                  GoRoute(
                    path: 'completed',
                    builder: (context, state) => const CompletedPage(),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoryManagementPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
