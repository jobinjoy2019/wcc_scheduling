import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppHelper {
  /// Sends a WhatsApp message to a specific phone number.
  /// [phoneNumber] should be in international format without the '+' (e.g., "919876543210").
  /// [message] is the text content you want to send.
  static Future<void> sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl =
        Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch WhatsApp');
    }
  }

  static Future<void> shareWhatsAppGroupMessage(String message) async {
    await Share.share(message);
  }
}
