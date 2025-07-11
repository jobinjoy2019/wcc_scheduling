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
    print('📞 Phone Number: $phoneNumber');
    if (!phoneNumber.startsWith('91')) {
      throw Exception(
          'Phone number must include country code. Example: 919876543210');
    }

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl =
        Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    print('🔗 WhatsApp URL: $whatsappUrl');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch WhatsApp');
    }
  }

  /// Shares a generic message using the system share sheet.
  static Future<void> shareWhatsAppGroupMessage(String message) async {
    await Share.share(message);
  }
}
