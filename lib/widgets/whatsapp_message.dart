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

    if (phoneNumber.isEmpty || !RegExp(r'^\d{10,15}$').hasMatch(phoneNumber)) {
      throw Exception(
        'Invalid phone number. Include country code (e.g. 919876543210)',
      );
    }

    final encodedMessage = Uri.encodeComponent(message.trim());
    final whatsappUri =
        Uri.parse("whatsapp://send?phone=$phoneNumber&text=$encodedMessage");
    final fallbackUri =
        Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    print('🔗 Trying WhatsApp URI: $whatsappUri');

    try {
      final canLaunchNative = await canLaunchUrl(whatsappUri);
      if (canLaunchNative) {
        final launched =
            await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        if (!launched) throw Exception('Failed to launch WhatsApp.');
      } else {
        print('ℹ️ Native WhatsApp not available, trying browser fallback...');
        final launchedFallback =
            await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        if (!launchedFallback) {
          throw Exception(
              'Neither WhatsApp nor browser fallback could be launched.');
        }
      }
    } catch (e) {
      print('❌ Error launching WhatsApp: $e');
      throw Exception('Could not launch WhatsApp or fallback URL: $e');
    }
  }

  /// Shares a generic message using the system share sheet.
  static Future<void> shareWhatsAppGroupMessage(String message) async {
    await Share.share(message);
  }
}
