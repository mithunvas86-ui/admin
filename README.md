# M·PROTI Dining Admin

Admin dashboard for M·PROTI Contactless Dining system.

## Features

- **Dashboard**: Overview of daily orders and metrics
- **Menu Manager**: Add, edit, delete, and manage menu items
- **Orders**: View and manage customer orders
- **Analytics**: Sales analytics and reporting

## Setup

1. Copy `.env.example` to `.env` and fill in your values:
   ```
   CLERK_PUBLISHABLE_KEY=your_key
   SUPABASE_URL=your_url
   SUPABASE_ANON_KEY=your_key
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Run the app:
   ```
   flutter run
   ```

## Architecture

- **Pages**: Admin-specific UI screens
- **Providers**: State management using Provider
- **Services**: Supabase integration
- **Models**: Data models (MenuItem, Order, etc.)

## Database

See parent project Supabase setup instructions.
