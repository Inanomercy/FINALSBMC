class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final trimmed = value.trim();
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.isEmpty) return 'Price is required';
    final n = double.tryParse(value);
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Price cannot be negative';
    return null;
  }

  static String? stock(String? value) {
    if (value == null || value.isEmpty) return 'Stock is required';
    final n = int.tryParse(value);
    if (n == null) return 'Enter a valid whole number';
    if (n < 0) return 'Stock cannot be negative';
    return null;
  }
}
