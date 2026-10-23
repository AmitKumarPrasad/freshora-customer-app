import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef GoogleOtpSender = Future<void> Function(String phone);
typedef GoogleAccountCompleter = Future<void> Function(
  String phone,
  String otp,
  String name,
  String pin,
);

class GooglePhoneVerificationDialog extends StatefulWidget {
  const GooglePhoneVerificationDialog({
    super.key,
    required this.email,
    required this.initialName,
    required this.onSendOtp,
    required this.onComplete,
  });

  final String email;
  final String initialName;
  final GoogleOtpSender onSendOtp;
  final GoogleAccountCompleter onComplete;

  @override
  State<GooglePhoneVerificationDialog> createState() =>
      _GooglePhoneVerificationDialogState();
}

class _GooglePhoneVerificationDialogState
    extends State<GooglePhoneVerificationDialog> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _otpSent = false;
  bool _sending = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName;
  }

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSendOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  Future<void> _finish() async {
    final phone = _phone.text.trim();
    final otp = _otp.text.trim();
    final name = _name.text.trim();
    final pin = _pin.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    if (!_otpSent || !RegExp(r'^\d{4,8}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the verification code sent to your phone.');
      return;
    }
    if (name.length < 2 || name.length > 60) {
      setState(() => _error = 'Enter your name (2 to 60 characters).');
      return;
    }
    if (pin.isNotEmpty &&
        (!RegExp(r'^\d{6}$').hasMatch(pin) || pin != _confirmPin.text.trim())) {
      setState(() => _error = 'PIN must be 6 digits and both PIN fields must match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onComplete(phone, otp, name, pin);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('AuthException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _submitting;
    return AlertDialog(
      title: const Text('Verify your delivery phone'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Google account: ${widget.email}'),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                controller: _phone,
                enabled: !busy && !_otpSent,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Indian mobile number',
                  prefixText: '+91 ',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : _sendOtp,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sms_outlined),
                label: Text(_otpSent ? 'Send code again' : 'Send verification code'),
              ),
              if (_otpSent) ...[
                TextField(
                  controller: _otp,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(labelText: 'SMS verification code'),
                ),
                TextField(
                  controller: _pin,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Create 6-digit PIN (new accounts)',
                    helperText: 'Existing account PINs are kept unchanged.',
                  ),
                ),
                TextField(
                  controller: _confirmPin,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || !_otpSent ? null : _finish,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify and continue'),
        ),
      ],
    );
  }
}
