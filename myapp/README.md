# PROJECT: OCEANCART
## Flutter-Based E-Commerce Mobile Application

Act as a Senior Flutter Developer, UI/UX Designer, Software Architect, and Backend Engineer.

Your task is to design, develop, and implement a fully functional, production-ready e-commerce mobile application named **OceanCart** using Flutter and Dart.

OceanCart is an online shopping platform where customers can browse products, add items to their cart, place orders, and pay online. Administrators manage products, customers, orders, and delivery riders. Riders receive assigned deliveries and manage their delivery status.

The application must have THREE DIFFERENT USER ROLES:

1. Customer
2. Administrator
3. Rider

Each role must have its own dashboard, navigation, permissions, and functionalities.

Do not create just a UI prototype. Implement the actual backend integration, database operations, authentication, payment workflow, and order management.

---

# 1. TECHNOLOGY STACK

Frontend:
- Flutter
- Dart
- Material Design 3
- Responsive mobile-first interface
- Provider or Riverpod for state management
- GoRouter for navigation

Backend:
- Supabase
- Supabase Authentication
- Supabase PostgreSQL Database
- Supabase Storage
- Supabase Row Level Security (RLS)
- Supabase Edge Functions for secure backend operations

Payment Gateway:
- Xendit API
- Online payment integration
- Payment verification through webhooks

Additional:
- Google Fonts
- Cached Network Image
- Image Picker
- Flutter Secure Storage
- QR Code generation/scanning where appropriate

Use clean architecture and modular code organization.

---

# 2. APPLICATION BRANDING AND DESIGN

Application Name: OceanCart

Design Concept:
Create a modern, premium, clean, and user-friendly online shopping experience.

Color Palette:
- Primary: Ocean Blue (#087EA4)
- Secondary: Deep Navy (#063B5C)
- Accent: Aqua (#35C6D8)
- Background: (#F5FAFC)
- White: (#FFFFFF)
- Success: Green
- Warning: Orange
- Error: Red

Design Requirements:
- Modern shopping application interface.
- Rounded product cards.
- High-quality product images.
- Smooth transitions and animations.
- Bottom navigation for customers.
- Sidebar or dashboard navigation for administrators.
- Simple navigation for riders.
- Loading indicators and skeleton screens.
- Empty states and error states.
- Consistent typography and spacing.
- Light theme initially, with architecture ready for dark mode.

The interface should feel similar in usability to Shopee, Lazada, and other modern e-commerce platforms, but with original OceanCart branding.

---

# 3. AUTHENTICATION AND USER ROLES

Implement Supabase Authentication.

Create a login and registration system.

Customer Registration:
- Full Name
- Email Address
- Password
- Confirm Password
- Phone Number
- Complete Delivery Address

Login:
- Email
- Password
- Forgot Password
- Show/Hide Password

After successful login, redirect users according to their assigned role.

IMPORTANT:
- Customers can register through the mobile application.
- Administrators must be created through a secure admin provisioning process.
- Riders must be created by the administrator.
- Never allow users to choose or assign themselves an administrator or rider role.
- Validate permissions using Supabase RLS and secure backend functions, not just frontend navigation.

---

# 4. CUSTOMER APPLICATION

Create a complete online shopping experience.

## A. Customer Home Screen

Include:
- OceanCart logo and branding.
- Search bar.
- Shopping cart icon with item counter.
- Promotional banners.
- Featured products.
- Popular products.
- New arrivals.
- Product categories.
- Recommended products.
- Bottom navigation.

Bottom Navigation:
1. Home
2. Categories
3. Cart
4. Orders
5. Profile

## B. Product Categories

Allow customers to browse products by category.

Each category should contain:
- Category name
- Category image
- List of products

## C. Product Listing

Each product card should display:
- Product image
- Product name
- Product price in PHP
- Stock availability
- Product rating, if available
- Add to Cart button

Implement:
- Search
- Category filtering
- Price sorting
- Newest products
- Price ascending/descending

## D. Product Details

Display:
- Multiple product images
- Product name
- Price
- Product description
- Available stock
- Product category
- Quantity selector
- Add to Cart
- Buy Now

Prevent customers from ordering quantities greater than available stock.

## E. Shopping Cart

Features:
- Display selected products.
- Increase/decrease quantity.
- Remove products.
- Display subtotal.
- Display delivery fee.
- Display total amount.
- Proceed to Checkout.

Persist cart data so it is not lost when the application closes.

## F. Checkout

Checkout information:
- Customer name
- Contact number
- Delivery address
- Order items
- Quantity
- Subtotal
- Delivery fee
- Total amount
- Payment method

Payment Methods:
- GCash (through supported Xendit payment channels)
- Maya (through supported Xendit payment channels)
- Credit/Debit Card (if enabled in the Xendit account)
- Other enabled Xendit payment channels

The available payment methods must be loaded or configured based on supported Xendit channels.

Add an Order Summary before confirming the order.

## G. Order Tracking

Customers must be able to track their orders.

Order statuses:
1. Pending Payment
2. Pending Confirmation
3. Processing
4. Assigned to Rider
5. Rider Accepted
6. Picked Up
7. Out for Delivery
8. Delivered
9. Cancelled
10. Payment Failed

Show:
- Order reference number
- Order date
- Purchased products
- Total amount
- Payment status
- Rider information once assigned
- Delivery status
- Order timeline

Provide a button to view order details.

## H. Customer Profile

Features:
- View profile.
- Edit personal information.
- Change password.
- Manage delivery addresses.
- View order history.
- Logout.

---

# 5. ADMINISTRATOR APPLICATION

Create a dedicated Admin Dashboard.

Only authorized administrators can access this dashboard.

## A. Admin Dashboard

Display dashboard statistics:
- Total Products
- Total Customers
- Total Riders
- Total Orders
- Pending Orders
- Processing Orders
- Active Deliveries
- Completed Deliveries
- Total Sales / Revenue

Add recent orders and recent activities.

Use dashboard cards and simple charts.

## B. Product Management

Administrators must be able to:

- Add new products.
- Edit existing products.
- Delete or archive products.
- Upload product images.
- Assign products to categories.
- Update product stock.
- Set product prices.
- Set product descriptions.
- Activate/deactivate products.

Add Product Form:
- Product Name
- Product Description
- Product Category
- Product Price
- Product Stock
- Product Images
- Product Status

All product data must be saved in Supabase PostgreSQL.

Images must be uploaded to Supabase Storage.

## C. Category Management

Administrators can:
- Create categories.
- Edit categories.
- Delete categories.
- Upload category images.

## D. Order Management

Display all customer orders.

Admin can:
- View order details.
- Review payment status.
- Confirm paid orders.
- Update order status.
- Assign riders.
- Cancel orders when permitted.
- View customer details.
- View order items and totals.

Only paid orders should be eligible for normal delivery assignment, unless an explicitly configured alternative payment workflow is implemented.

## E. Rider Management

The administrator must be able to create and manage rider accounts.

Create Rider Form:
- Full Name
- Email Address
- Phone Number
- Password
- Confirm Password
- Address
- Rider Profile Image (optional)

Features:
- Create rider account.
- Edit rider information.
- Activate/deactivate rider.
- View all riders.
- View rider delivery history.
- View available riders.
- View currently assigned deliveries.

IMPORTANT:
Use a secure Supabase Edge Function or trusted backend process to create rider accounts using the Supabase Admin Auth API.

Never expose the Supabase service role key inside Flutter.

Creating a rider account must not accidentally replace or invalidate the administrator's current authentication session.

## F. Rider Assignment

For every eligible order:

1. Open the order details.
2. Click Assign Rider.
3. Display a list of active riders.
4. Select an available rider.
5. Confirm assignment.
6. Save the rider ID in the order record.
7. Notify the assigned rider.
8. Update the order status to Assigned to Rider.

Prevent multiple riders from accepting the same delivery.

Implement proper database transactions or secure backend validation for assignment and acceptance.

## G. Reports and Analytics

Include:
- Daily sales.
- Weekly sales.
- Monthly sales.
- Total orders.
- Most purchased products.
- Best-selling categories.
- Rider delivery performance.

Provide date filters and export functionality where practical.

---

# 6. RIDER APPLICATION

Create a separate dashboard for riders.

Riders must only access deliveries assigned to their accounts.

## A. Rider Dashboard

Display:
- Rider profile.
- Assigned Deliveries.
- Pending Acceptance.
- Active Deliveries.
- Completed Deliveries.
- Total Deliveries.

## B. Assigned Orders

Display delivery cards containing:
- Order Number
- Customer Name
- Customer Contact Number
- Delivery Address
- Order Date
- Number of Items
- Order Status

## C. Accept or Reject Delivery

When the administrator assigns an order, the rider receives an in-app notification.

The rider can:
- View assigned delivery.
- Accept delivery.
- Reject delivery with a reason.

If rejected:
- Notify the administrator.
- Return the order to the unassigned queue.
- Allow the administrator to assign another rider.

If accepted:
- Update order status to Rider Accepted.
- Notify the administrator and customer.

Acceptance must be atomic to prevent duplicate acceptance.

## D. Delivery Management

After accepting an order, the rider can:

1. View delivery details.
2. Contact the customer.
3. View delivery address.
4. Open the address in a map application.
5. Mark order as Picked Up.
6. Mark order as Out for Delivery.
7. Mark order as Delivered.

For delivery completion:
- Show order confirmation.
- Record delivery timestamp.
- Optionally capture proof of delivery.
- Save delivery completion in Supabase.

Riders must not be able to modify product prices, customer payments, or other riders' deliveries.

## E. Rider Profile

Include:
- Rider name.
- Email.
- Contact number.
- Delivery history.
- Completed deliveries.
- Logout.

---

# 7. XENDIT PAYMENT INTEGRATION

Integrate Xendit as the payment gateway.

IMPORTANT SECURITY REQUIREMENTS:

- Never put the Xendit secret API key in Flutter.
- Never expose private API credentials in client-side code.
- All payment creation must happen through Supabase Edge Functions or another secure backend.
- Use Xendit-hosted checkout or supported payment APIs.
- Verify webhook signatures on the backend.
- Do not rely on the frontend redirect to determine whether payment succeeded.

Payment Workflow:

1. Customer checks out.
2. Flutter sends the order request to Supabase.
3. Backend validates products, stock, quantities, and total prices.
4. Backend creates the order with Pending Payment status.
5. Backend creates a Xendit payment or invoice.
6. Return the checkout URL to Flutter.
7. Customer opens the secure Xendit checkout page.
8. Customer completes payment.
9. Xendit sends a webhook to the backend.
10. Backend verifies the webhook.
11. Backend updates payment status.
12. If payment succeeds, mark order as paid.
13. Notify the customer.
14. Make the order available for administrator processing.

Implement:
- Payment creation.
- Payment status verification.
- Webhook handling.
- Failed payment handling.
- Duplicate webhook protection.
- Payment reference storage.
- Transaction records.

Use idempotency keys to avoid duplicate charges.

Do not assume that a payment is successful simply because the customer returned to the app.

---

# 8. SUPABASE DATABASE STRUCTURE

Create SQL migration files for the following tables.

## profiles
- id UUID PRIMARY KEY REFERENCES auth.users(id)
- full_name TEXT
- email TEXT
- phone TEXT
- address TEXT
- role TEXT CHECK (role IN ('customer', 'admin', 'rider'))
- avatar_url TEXT
- is_active BOOLEAN DEFAULT TRUE
- created_at TIMESTAMPTZ

## categories
- id UUID PRIMARY KEY
- name TEXT
- description TEXT
- image_url TEXT
- created_at TIMESTAMPTZ

## products
- id UUID PRIMARY KEY
- category_id UUID REFERENCES categories(id)
- name TEXT
- description TEXT
- price NUMERIC(12,2)
- stock INTEGER
- image_url TEXT
- is_active BOOLEAN DEFAULT TRUE
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

## product_images
- id UUID PRIMARY KEY
- product_id UUID REFERENCES products(id)
- image_url TEXT
- created_at TIMESTAMPTZ

## cart_items
- id UUID PRIMARY KEY
- customer_id UUID REFERENCES profiles(id)
- product_id UUID REFERENCES products(id)
- quantity INTEGER
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

## orders
- id UUID PRIMARY KEY
- order_number TEXT UNIQUE
- customer_id UUID REFERENCES profiles(id)
- rider_id UUID REFERENCES profiles(id) NULL
- subtotal NUMERIC(12,2)
- delivery_fee NUMERIC(12,2)
- total_amount NUMERIC(12,2)
- payment_status TEXT
- order_status TEXT
- delivery_address TEXT
- customer_phone TEXT
- assigned_at TIMESTAMPTZ
- accepted_at TIMESTAMPTZ
- delivered_at TIMESTAMPTZ
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

## order_items
- id UUID PRIMARY KEY
- order_id UUID REFERENCES orders(id)
- product_id UUID REFERENCES products(id)
- product_name TEXT
- product_price NUMERIC(12,2)
- quantity INTEGER
- subtotal NUMERIC(12,2)

Store product name and price snapshots so historical orders do not change when administrators edit products.

## payments
- id UUID PRIMARY KEY
- order_id UUID REFERENCES orders(id)
- customer_id UUID REFERENCES profiles(id)
- provider TEXT DEFAULT 'xendit'
- payment_reference TEXT
- payment_method TEXT
- amount NUMERIC(12,2)
- status TEXT
- checkout_url TEXT
- paid_at TIMESTAMPTZ
- created_at TIMESTAMPTZ

## rider_assignments
- id UUID PRIMARY KEY
- order_id UUID REFERENCES orders(id)
- rider_id UUID REFERENCES profiles(id)
- status TEXT
- rejection_reason TEXT
- assigned_at TIMESTAMPTZ
- responded_at TIMESTAMPTZ

## order_status_history
- id UUID PRIMARY KEY
- order_id UUID REFERENCES orders(id)
- status TEXT
- changed_by UUID REFERENCES profiles(id)
- notes TEXT
- created_at TIMESTAMPTZ

## notifications
- id UUID PRIMARY KEY
- user_id UUID REFERENCES profiles(id)
- title TEXT
- message TEXT
- type TEXT
- is_read BOOLEAN DEFAULT FALSE
- created_at TIMESTAMPTZ

Add indexes, foreign key constraints, validation constraints, and appropriate timestamps.

Use database functions and transactions for important operations such as checkout, inventory deduction, rider assignment, and rider acceptance.

Avoid trusting client-submitted prices and totals.

---

# 9. SUPABASE SECURITY AND ROW LEVEL SECURITY

Enable RLS on every table containing application data.

Implement these access rules:

CUSTOMER:
- Read active products and categories.
- Manage only their own cart.
- Read only their own orders.
- Create orders through secure checkout functions.
- Read only their own payment records.
- Read only their own notifications.

ADMIN:
- Manage products.
- Manage categories.
- View customers.
- Manage orders.
- Create and manage rider accounts through secure Edge Functions.
- Assign riders.
- Access sales reports.

RIDER:
- Read only their own profile.
- Read only orders assigned to them.
- Accept or reject their own assigned deliveries.
- Update permitted delivery statuses.
- Read their own delivery history.

Never rely exclusively on Flutter route protection.

Use database-level security and server-side role verification.

---

# 10. NOTIFICATION SYSTEM

Implement real-time in-app notifications using Supabase Realtime.

Customer notifications:
- Order successfully created.
- Payment successful.
- Order confirmed.
- Rider assigned.
- Rider accepted delivery.
- Order out for delivery.
- Order delivered.

Admin notifications:
- New order received.
- Payment successful.
- Rider rejected assignment.
- Delivery completed.

Rider notifications:
- New delivery assigned.
- Assignment cancelled.
- New delivery instructions.

---

# 11. FLUTTER PROJECT STRUCTURE

Use a clean and modular folder structure:

lib/
  main.dart

  core/
    constants/
    theme/
    utils/
    services/
    routing/

  models/

  features/
    authentication/
      screens/
      widgets/
      providers/

    customer/
      home/
      products/
      categories/
      cart/
      checkout/
      orders/
      profile/

    admin/
      dashboard/
      products/
      categories/
      orders/
      riders/
      reports/

    rider/
      dashboard/
      deliveries/
      history/
      profile/

    payments/
      services/
      screens/

  shared/
    widgets/
    services/

supabase/
  migrations/
  functions/
    create-rider/
    create-payment/
    xendit-webhook/
    checkout/
    assign-rider/
    accept-delivery/

Keep the code clean, reusable, documented, and easy to maintain.

---

# 12. IMPORTANT FUNCTIONAL REQUIREMENTS

The following are mandatory:

1. All three roles must work independently.
2. Authentication must be connected to Supabase.
3. Product management must save real data.
4. Product images must upload to Supabase Storage.
5. Customers must be able to place actual orders.
6. Cart data must persist.
7. Checkout must calculate totals securely.
8. Xendit must handle actual online payments.
9. Webhooks must update payment status.
10. Admin must be able to create rider accounts.
11. Admin must be able to assign riders.
12. Riders must be able to accept assigned orders.
13. Customers must see order progress.
14. Supabase RLS must enforce user permissions.
15. All important operations must handle errors properly.

Do not use hardcoded products, fake payment success, or static dashboard statistics as the final implementation.

If API credentials are unavailable, implement the integration structure and provide clear configuration instructions. Do not pretend that a real payment has been processed.

---

# 13. DEVELOPMENT WORKFLOW

Build the application in organized phases.

PHASE 1:
- Initialize Flutter project.
- Configure theme and navigation.
- Configure Supabase.
- Implement authentication and role-based routing.

PHASE 2:
- Create database migrations.
- Configure Storage.
- Configure RLS policies.
- Implement customer product browsing.

PHASE 3:
- Implement cart and checkout.
- Implement secure order creation.
- Implement Xendit payment integration.

PHASE 4:
- Implement administrator dashboard.
- Implement product and category management.
- Implement rider account creation.
- Implement order and rider assignment management.

PHASE 5:
- Implement rider dashboard.
- Implement delivery acceptance.
- Implement delivery status updates.

PHASE 6:
- Implement notifications.
- Implement order tracking.
- Implement reports and analytics.

PHASE 7:
- Test all three user roles.
- Test database security.
- Test payment webhooks.
- Test stock management.
- Test rider assignment concurrency.
- Fix bugs and optimize performance.

After each phase:
- Verify that the code compiles.
- Run Flutter Analyze.
- Fix errors before proceeding.
- Test the implemented features.

---

# 14. FINAL EXPECTATION

Deliver a complete, functional Flutter e-commerce application called OceanCart.

The finished application should have:

- A beautiful customer shopping experience.
- A complete administrator management dashboard.
- A dedicated rider delivery application.
- Supabase-powered backend.
- Secure Xendit payment integration.
- Real-time order updates.
- Secure role-based access.
- Clean and maintainable Flutter code.

Do not stop after generating the homepage or UI.

Continue implementing the actual functionalities until the complete system is operational.

At the end, provide:
1. Complete Flutter source code.
2. Supabase SQL migration files.
3. Supabase Edge Functions.
4. RLS policies.
5. Xendit configuration guide.
6. Environment variable setup instructions.
7. Installation and deployment guide.
8. Testing instructions and sample test accounts.

Build OceanCart as a real, scalable e-commerce system, not just a visual demonstration.xxx

2. Recommended application workflow
This is how the three users will interact with each other.
CUSTOMER
Browse and Purchase

Browse products → Add to cart → Checkout → Pay through Xendit


SUPABASE BACKEND

Authentication • Database • Inventory • Orders • Payment Records
Xendit Payment Verification


ADMIN
Manage Orders and Assign Riders

Verify payment → Process order → Select rider → Assign delivery


RIDER
Delivery Management

Receive assignment → Accept delivery → Pick up → Deliver → Complete

Order status updates are reflected in the customer and admin dashboards.

3. Recommended database architecture
Table	Purpose
profiles	All three user accounts
products	Product information and pricing
categories	Product categories
product_images	Multiple product images
cart_items	Customer shopping carts
orders	Customer purchases
order_items	Products included in orders
payments	Xendit payment records
rider_assignments	Rider assignment and acceptance
order_status_history	Order tracking history
notifications	Notifications for all roles


5. Important implementation reminders
Before asking Antigravity to build everything, prepare these:
- Supabase: Project URL and anon/publishable key.
- Xendit: Secret API key and webhook configuration.
- Flutter: Android Studio and Flutter SDK.
- Testing: Separate customer, admin, and rider accounts.
A few important architectural decisions:
1. Use one Flutter project with three role-based interfaces rather than three separate applications.
2. Create rider accounts using a Supabase Edge Function with the Admin API.
3. Keep Xendit secret keys on the backend only.
4. Deduct inventory through a secure database transaction to prevent overselling.
5. Require verified payment before normal rider assignment.
My recommendation: Build the project phase by phase using Antigravity. Have it finish and test authentication and Supabase first before proceeding to checkout, Xendit, and rider management. This will make debugging significantly easier.