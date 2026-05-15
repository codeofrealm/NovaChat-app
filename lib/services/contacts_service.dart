import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class ContactsService {
  final FirestoreService _fs = FirestoreService();

  /// Returns device contacts that are registered on NovaChat,
  /// plus all app users not in contacts (as "other users").
  Future<({List<UserModel> onApp, List<UserModel> others})> getContacts(
      String currentUid) async {
    final allAppUsers = await _fs.getAllUsers(currentUid);

    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      return (onApp: allAppUsers, others: <UserModel>[]);
    }

    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    // Normalize phone numbers: strip spaces, dashes, parentheses
    final deviceNumbers = <String>{};
    for (final c in deviceContacts) {
      for (final p in c.phones) {
        final normalized = p.number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        deviceNumbers.add(normalized);
        // Also add last 10 digits for local number matching
        if (normalized.length > 10) {
          deviceNumbers.add(normalized.substring(normalized.length - 10));
        }
      }
    }

    final onApp = <UserModel>[];
    final others = <UserModel>[];

    for (final user in allAppUsers) {
      final userPhone = user.phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final last10 =
          userPhone.length > 10 ? userPhone.substring(userPhone.length - 10) : userPhone;

      if (deviceNumbers.contains(userPhone) || deviceNumbers.contains(last10)) {
        onApp.add(user);
      } else {
        others.add(user);
      }
    }

    return (onApp: onApp, others: others);
  }
}
