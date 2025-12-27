import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wallet_service.dart';
import 'snackbar_helper.dart';

class TopUpDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  const TopUpDialog({super.key, this.onSuccess});

  @override
  State<TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<TopUpDialog> {
  final TextEditingController _amountController = TextEditingController();
  final WalletService _walletService = WalletService();
  bool _isLoading = false;
  String? _error;

  final List<int> _quickAmounts = [25, 50, 100, 200, 500, 1000];
  int? _selectedQuickAmount;

  static const String _webBaseUrlEnv = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://www.d1v.ai',
  );

  static String _normalizeBaseUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'https://www.d1v.ai';
    return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
  }

  static String _ordersUrl({String? pay}) {
    final base = _normalizeBaseUrl(_webBaseUrlEnv);
    if (pay == null || pay.trim().isEmpty) return '$base/orders';
    return '$base/orders?pay=${Uri.encodeQueryComponent(pay.trim())}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
      _selectedQuickAmount = amount;
      _error = null;
    });
  }

  void _stepAmount(int delta) {
    final curr = _parseAmount();
    final next = (curr ?? 0) + delta;
    final clamped = next < 25 ? 25 : (next > 20000 ? 20000 : next);
    setState(() {
      _amountController.text = clamped.toStringAsFixed(0);
      _selectedQuickAmount = _quickAmounts.contains(clamped.toInt())
          ? clamped.toInt()
          : null;
      _error = null;
    });
  }

  double? _parseAmount() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool _isValidAmount(double amount) {
    return amount >= 25 && amount <= 20000;
  }

  String _formatUsd(double amount) {
    final normalized = (amount * 100).roundToDouble() / 100.0;
    final isInt = normalized == normalized.roundToDouble();
    return isInt ? normalized.toStringAsFixed(0) : normalized.toStringAsFixed(2);
  }

  String _ctaLabel() {
    final amount = _parseAmount();
    final amt = (amount != null && amount.isFinite && amount > 0)
        ? _formatUsd(amount)
        : null;
    return amt == null ? 'Continue to Stripe' : 'Continue to Stripe • \$$amt';
  }

  Future<void> _handleSubmit() async {
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      setState(() {
        _error = 'Please enter an amount';
      });
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      setState(() {
        _error = 'Please enter a valid number';
      });
      return;
    }

    final normalized = (amount * 100).roundToDouble() / 100.0;
    if (!_isValidAmount(normalized)) {
      setState(() {
        _error = 'Amount must be between \$25 and \$20,000';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call API to initiate top-up
      final response = await _walletService.initiateTopup(
        amountUsd: normalized,
        successUrl: _ordersUrl(pay: 'success'),
        cancelUrl: _ordersUrl(pay: 'cancel'),
      );

      if (!mounted) return;

      // Get the checkout URL from response
      final checkoutUrl = response['url'] as String?;
      if (checkoutUrl == null) {
        throw Exception('Invalid response from server');
      }

      final uri = Uri.tryParse(checkoutUrl.trim());
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw Exception('Invalid checkout URL');
      }

      // Close dialog
      Navigator.of(context).pop();

      SnackBarHelper.showInfo(
        context,
        title: 'Redirecting',
        message: 'Opening Stripe checkout…',
        duration: const Duration(seconds: 3),
        position: SnackBarPosition.top,
      );

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Failed to open checkout URL');
      }

      // Call success callback to refresh balance
      widget.onSuccess?.call();
    } catch (e) {
      debugPrint('Top-up failed: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to process payment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _parseAmount();
    final canSubmit =
        amount != null && amount.isFinite && _isValidAmount(amount);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Top up credits',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Add funds to your account balance. Secure checkout by Stripe.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    onTap: _isLoading ? null : () => _stepAmount(-5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !_isLoading,
                      inputFormatters: const [_CurrencyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Amount (USD)',
                        hintText: '25 - 20000',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _error = null;
                          final n = double.tryParse(value.trim());
                          final asInt =
                              (n != null && n.isFinite) ? n.toInt() : null;
                          _selectedQuickAmount =
                              asInt != null && _quickAmounts.contains(asInt)
                                  ? asInt
                                  : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StepperButton(
                    icon: Icons.add,
                    onTap: _isLoading ? null : () => _stepAmount(5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) {
                  final isSelected = _selectedQuickAmount == amount;
                  return ChoiceChip(
                    label: Text('\$$amount'),
                    selected: isSelected,
                    onSelected:
                        _isLoading ? null : (_) => _selectQuickAmount(amount),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                    ),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.10),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isSelected ? 0.0 : 0.25,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Min \$25 • Max \$20,000',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || !canSubmit ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Text(_ctaLabel()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  static final RegExp _re = RegExp(r'^\d{0,5}(\.\d{0,2})?$');

  const _CurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (_re.hasMatch(t)) return newValue;
    return oldValue;
  }
}
