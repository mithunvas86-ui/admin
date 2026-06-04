import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_gate.dart';
import 'pages/dashboard_page.dart';
import 'pages/menu_page.dart';
import 'pages/analytics_page.dart';
import 'pages/orders_page.dart';
import 'pages/order_detail_page.dart';
import 'pages/customers_page.dart';
import 'pages/kds_page.dart';

String? _authGuard(BuildContext context, GoRouterState state) {
  final auth = context.read<AuthProvider>();
  if (!auth.isAuthenticated && state.matchedLocation != '/login') {
    return '/login';
  }
  if (auth.isAuthenticated && state.matchedLocation == '/login') {
    return '/';
  }
  return null;
}

final router = GoRouter(
  initialLocation: '/',
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
  ],
);
