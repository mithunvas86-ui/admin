import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_gate.dart';
import 'pages/dashboard_page.dart';
import 'pages/menu_page.dart';
import 'pages/analytics_page.dart';
import 'pages/orders_page.dart';
import 'pages/order_detail_page.dart';
import 'pages/customers_page.dart';
import 'pages/kds_page.dart';
import 'pages/service_hours_page.dart';

String? _authGuard(BuildContext context, GoRouterState state) {
  final loc = state.matchedLocation;
  final authed = adminAuth.isAuthenticated;

  // Unauthenticated users only ever see the login screen.
  if (!authed) return loc == '/login' ? null : '/login';

  // Authenticated users have no business on the login screen.
  if (loc == '/login') return adminAuth.homeRoute;

  // Allow-list by role (deny by default). Admin pages are NOT reachable unless
  // role == 'admin', so a missing/unreadable role can never expose them.
  final role = adminAuth.role;
  switch (role) {
    case 'admin':
      return null; // full access
    case 'chef':
      return loc == '/kds' ? null : '/kds';
    case 'delivery':
      return (loc == '/orders' || loc.startsWith('/orders/')) ? null : '/orders';
    default:
      // Authenticated but no recognized staff role → confine to the Kitchen
      // Display, whose data is empty for non-staff (orders RLS uses is_staff()).
      return loc == '/kds' ? null : '/kds';
  }
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: adminAuth,
  redirect: _authGuard,
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersPage(),
    ),
    GoRoute(
      path: '/orders/:orderId',
      builder: (context, state) => OrderDetailPage(
        orderId: state.pathParameters['orderId']!,
      ),
    ),
    GoRoute(
      path: '/menu',
      builder: (context, state) => const MenuPage(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsPage(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
    ),
    GoRoute(
      path: '/kds',
      builder: (context, state) => const KDSPage(),
    ),
    GoRoute(
      path: '/service-hours',
      builder: (context, state) => const ServiceHoursPage(),
    ),
  ],
);
