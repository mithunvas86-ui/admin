import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_gate.dart';
import 'pages/model_chooser_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/menu_page.dart';
import 'pages/analytics_page.dart';
import 'pages/orders_page.dart';
import 'pages/order_detail_page.dart';
import 'pages/customers_page.dart';
import 'pages/kds_page.dart';
import 'pages/service_hours_page.dart';
import 'pages/subscriptions_page.dart';
import 'pages/subscription_dashboard_page.dart';
import 'pages/subscription_chef_page.dart';
import 'pages/subscription_delivery_page.dart';
import 'pages/subscription_meals_page.dart';
import 'pages/subscription_settings_page.dart';
import 'pages/gym_membership_settings_page.dart';
import 'pages/staff_page.dart';

Future<String?> _authGuard(BuildContext context, GoRouterState state) async {
  final loc = state.matchedLocation;
  final authed = adminAuth.isAuthenticated;

  // Unauthenticated users only ever see the login screen.
  if (!authed) return loc == '/login' ? null : '/login';

  // Authenticated users have no business on the login screen.
  if (loc == '/login') return adminAuth.homeRoute;

  // Allow-list by role (deny by default). Admin pages are NOT reachable unless
  // role == 'admin', so a missing/unreadable role can never expose them.
  //
  // chef/delivery were retired in favor of model-scoped roles below — a
  // profiles.role of 'chef', 'delivery', null, or anything unrecognized
  // falls through to the fail-closed default, which signs the user out
  // rather than land them on any live KDS/order page.
  final role = adminAuth.role;
  switch (role) {
    case 'admin':
      // Full access to both models — but the very first thing an admin sees
      // each session is the Gym/Subscription chooser, regardless of whether
      // they arrived via a fresh /login or an already-restored session
      // landing straight on some other route.
      if (!adminAuth.hasChosenModel && loc != '/choose-model') {
        return '/choose-model';
      }
      return null;
    case 'gym_manager':
      // Full run of the gym/restaurant side — dashboard, orders, menu
      // (incl. pricing), analytics, customers, KDS, service hours — but
      // not the subscription section, and not staff access (admin-only).
      if (loc == '/staff') return '/';
      return loc.startsWith('/subs') ? '/' : null;
    case 'sub_manager':
      // Subscription manager (separate credentials) — confined to the
      // subscription section: members, kitchen, settings.
      return loc.startsWith('/subs') ? null : '/subs';
    case 'gym_chef':
      // Gym-model kitchen staff — restaurant KDS only, not the subscription
      // kitchen/delivery screen.
      return loc == '/kds' ? null : '/kds';
    case 'gym_delivery':
      // Gym-model delivery staff — restaurant orders only, not the
      // subscription kitchen/delivery screen.
      return (loc == '/orders' || loc.startsWith('/orders/'))
          ? null
          : '/orders';
    case 'subs_chef':
      return loc == '/subs-kitchen' ? null : '/subs-kitchen';
    case 'subs_delivery':
      return loc == '/subs-delivery' ? null : '/subs-delivery';
    default:
      // Not a recognized staff role — including the retired 'chef'/
      // 'delivery' values. Fail closed: sign out entirely rather than
      // fall through to any live page.
      await adminAuth.logout();
      return '/login';
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
      path: '/choose-model',
      builder: (context, state) => const ModelChooserPage(),
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
    GoRoute(
      path: '/gym-membership-settings',
      builder: (context, state) => const GymMembershipSettingsPage(),
    ),
    GoRoute(
      path: '/staff',
      builder: (context, state) => const StaffPage(),
    ),
    GoRoute(
      path: '/subs',
      builder: (context, state) => const SubscriptionDashboardPage(),
    ),
    GoRoute(
      path: '/subs-members',
      builder: (context, state) => const SubscriptionsPage(),
    ),
    GoRoute(
      path: '/subs-kitchen',
      builder: (context, state) => const SubscriptionChefPage(),
    ),
    GoRoute(
      path: '/subs-delivery',
      builder: (context, state) => const SubscriptionDeliveryPage(),
    ),
    GoRoute(
      path: '/subs-meals',
      builder: (context, state) => const SubscriptionMealsPage(),
    ),
    GoRoute(
      path: '/subs-settings',
      builder: (context, state) => const SubscriptionSettingsPage(),
    ),
  ],
);
