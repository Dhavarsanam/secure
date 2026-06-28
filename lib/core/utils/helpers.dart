import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Colors defined directly — no import needed
const Color _successColor = Color(0xFF22C55E);
const Color _errorColor = Color(0xFFEF4444);
const Color _primaryColor = Color(0xFF1A73E8);

class Helpers {
  // Generate 6-character trip code
  static String generateTripCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    int temp = random;
    for (int i = 0; i < 6; i++) {
      code += chars[temp % chars.length];
      temp ~/= chars.length;
    }
    return code;
  }

  // Format date
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  // Format date and time
  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  // Format time
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  // Format duration in minutes to readable
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  // Format distance
  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  // Show toast
  static void showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? _errorColor : _successColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  // Show snackbar
  static void showSnackBar(
      BuildContext context,
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message ?? 'Loading...'),
          ],
        ),
      ),
    );
  }

  // Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // Show confirm dialog
  static Future<bool> showConfirmDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        bool isDangerous = false,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? _errorColor : _primaryColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Get vehicle icon
  static IconData getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'auto':
        return Icons.electric_rickshaw;
      case 'van':
        return Icons.airport_shuttle;
      case 'bus':
        return Icons.directions_bus;
      case 'suv':
        return Icons.directions_car_filled;
      default:
        return Icons.directions_car;
    }
  }

  // Get passenger type icon
  static IconData getPassengerIcon(String passengerType) {
    switch (passengerType.toLowerCase()) {
      case 'solo':
        return Icons.person;
      case 'family':
        return Icons.family_restroom;
      case 'group':
        return Icons.group;
      case 'women only':
        return Icons.female;
      case 'corporate':
        return Icons.business_center;
      default:
        return Icons.person;
    }
  }

  // Google Maps URL from coordinates
  static String googleMapsUrl(double lat, double lng) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }
}