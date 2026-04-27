import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/wallet_service.dart';
import '../services/stripe_payment_service.dart';
import 'adaptive_modal.dart';
import 'snackbar_helper.dart';
import '../utils/error_utils.dart';
import '../l10n/app_localizations.dart';

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

  String _ctaLabel(AppLocalizations? loc) {
    return loc?.translate('topup_continue') ?? 'Continue';
  }

  String _paymentMethodsCopy(AppLocalizations? loc) {
    final methodLabel = StripePaymentService.availablePaymentMethodsLabel(loc);
    return (loc?.translate('topup_subtitle') ??
            'Add funds with {methods} through Stripe.')
        .replaceAll('{methods}', methodLabel);
  }

  Future<void> _handleSubmit() async {
    final loc = AppLocalizations.of(context);
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      setState(() {
        _error = loc?.translate('topup_amount_required') ??
            'Please enter an amount';
      });
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      setState(() {
        _error =
            loc?.translate('topup_amount_invalid') ?? 'Please enter a valid number';
      });
      return;
    }

    final normalized = (amount * 100).roundToDouble() / 100.0;
    if (!_isValidAmount(normalized)) {
      setState(() {
        _error = loc?.translate('topup_amount_range') ??
            'Amount must be between \$25 and \$20,000';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _walletService.initiateTopupApp(
        amountUsd: normalized,
      );

      if (!mounted) return;

      final clientSecret = response['client_secret'] as String?;
      final currency = (response['currency'] as String? ?? 'usd').toUpperCase();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Missing client secret');
      }

      await StripePaymentService.presentPaymentSheet(
        clientSecret: clientSecret,
        amountUsd: normalized,
        currencyCode: currency,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      SnackBarHelper.showSuccess(
        context,
        title: loc?.translate('topup_payment_submitted_title') ??
            'Payment submitted',
        message: loc?.translate('topup_payment_submitted_message') ??
            'Your top-up payment was submitted successfully.',
        duration: const Duration(seconds: 3),
        position: SnackBarPosition.top,
      );
      widget.onSuccess?.call();
    } on StripeException catch (e) {
      debugPrint('Top-up canceled: $e');
      final error = e.error;
      final isCanceled =
          error.code == FailureCode.Canceled ||
          ((error.localizedMessage ?? '').toLowerCase().contains('canceled')) ||
          ((error.message ?? '').toLowerCase().contains('canceled'));

      if (isCanceled) {
        if (mounted) {
          SnackBarHelper.showInfo(
            context,
            title: loc?.translate('topup_payment_canceled_title') ??
                'Payment canceled',
            message: loc?.translate('topup_payment_canceled_message') ??
                'The payment was canceled.',
            duration: const Duration(seconds: 3),
            position: SnackBarPosition.top,
          );
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }
      rethrow;
    } catch (e) {
      debugPrint('Top-up failed: $e');
      final msg = humanizeError(e);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: loc?.translate('error') ?? 'Error',
          message: msg,
          duration: const Duration(seconds: 3),
          position: SnackBarPosition.top,
        );
      }
      setState(() {
        _isLoading = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final amount = _parseAmount();
    final canSubmit =
        amount != null && amount.isFinite && _isValidAmount(amount);
    return AdaptiveModalContainer(
      maxWidth: 520,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                    loc?.translate('topup_title') ?? 'Top up credits',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              StripePaymentService.isConfigured
                  ? _paymentMethodsCopy(loc)
                  : (loc?.translate('topup_unconfigured') ??
                      'Stripe mobile payment is not configured in this build.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('topup_amount_label') ?? 'Amount (USD)',
                      hintText:
                          loc?.translate('topup_amount_hint') ?? '25 - 20000',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _error = null;
                        final n = double.tryParse(value.trim());
                        final asInt = (n != null && n.isFinite)
                            ? n.toInt()
                            : null;
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
                  onSelected: _isLoading
                      ? null
                      : (_) => _selectQuickAmount(amount),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
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
              loc?.translate('topup_limit_hint') ?? 'Min \$25 • Max \$20,000',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                    child: Text(loc?.translate('cancel') ?? 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ||
                            !canSubmit ||
                            !StripePaymentService.isConfigured
                        ? null
                        : _handleSubmit,
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
                        : Text(_ctaLabel(loc)),
                  ),
                ),
              ],
            ),
          ],
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
