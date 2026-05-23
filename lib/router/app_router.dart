import 'package:film_go/pages/calc/calc_page.dart';
import 'package:film_go/pages/darkroom/darkroom_page.dart';
import 'package:film_go/pages/me/me_page.dart';
import 'package:film_go/pages/meter/meter_page.dart';
import 'package:film_go/pages/rolls/rolls_page.dart';
import 'package:film_go/widgets/scaffold_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/meter',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meter',
                builder: (_, __) => const MeterPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calc',
                builder: (_, __) => const CalcPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rolls',
                builder: (_, __) => const RollsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/darkroom',
                builder: (_, __) => const DarkroomPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, __) => const MePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
