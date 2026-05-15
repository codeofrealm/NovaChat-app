import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class ContactsService {
  final DatabaseService _db = DatabaseService();

  Future<({List<UserModel> onApp, List<UserModel> others})> getContacts(
      String currentUid) async {
    // Load all app users from Realtime Database
    List<UserModel> allAppUsers = [];
    try {
      allAppUsers = await _db.getAllUsers(currentUid);
    } catch (_) {}

    // If no users found, return empty
    if (allAppUsers.isEmpty) {
      return (onApp: <UserModel>[], others: <UserModel>[]);
    }

    // Request contacts permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      // No permission — show all app users under "Other Users"
      return (onApp: <UserModel>[], others: allAppUsers);
    }

    List<Contact> deviceContacts = [];
    try {
      deviceContacts = await FlutterContacts.getContacts(withProperties: true);
    } catch (_) {
      return (onApp: <UserModel>[], others: allAppUsers);
    }

    // Normalize phone numbers
    final deviceNumbers = <String>{};
    for (final c in deviceContacts) {
      for (final p in c.phones) {
        final normalized = p.number.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
        deviceNumbers.add(normalized);
        if (normalized.length > 10) {
          deviceNumbers.add(normalized.substring(normalized.length - 10));
        }
      }
    }

    final onApp = <UserModel>[];
    final others = <UserModel>[];

    for (final user in allAppUsers) {
      final userPhone = user.phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
      final last10 = userPhone.length > 10
          ? userPhone.substring(userPhone.length - 10)
          : userPhone;

      if (deviceNumbers.contains(userPhone) || deviceNumbers.contains(last10)) {
        onApp.add(user);
      } else {
        others.add(user);
      }
    }

    return (onApp: onApp, others: others);
  }
}
