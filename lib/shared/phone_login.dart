/// Firebase Auth has no phone + password provider, so phone accounts are email/password accounts whose
/// address is derived from the E.164 number. No mail is ever sent to this domain.
const _phoneLoginDomain = 'phone.aiassistant-49b02.firebaseapp.com';

/// Country calling code suggested for each app language.
String defaultCountryCode(String languageCode) => languageCode == 'ja' ? '81' : '82';

/// Joins a country calling code and a local number into E.164; a trunk 0 (010…, 090…) is dropped
/// and separators such as '-' or spaces are ignored. Returns null when the result cannot be a phone number.
String? toE164(String countryCode, String localNumber) {
  final country = countryCode.replaceAll(RegExp(r'\D'), '');
  final local = localNumber.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  final digits = '$country$local';
  if (country.isEmpty || country.length > 3 || local.length < 4 || digits.length > 15) {
    return null;
  }
  return '+$digits';
}

String phoneLoginEmail(String e164) => '${e164.substring(1)}@$_phoneLoginDomain';

/// The phone number behind a phone-login address, or null for real email addresses.
String? phoneOfLoginEmail(String? email) {
  if (email == null || !email.endsWith('@$_phoneLoginDomain')) {
    return null;
  }
  return '+${email.split('@').first}';
}
