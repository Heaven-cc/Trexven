import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/business.dart';
import 'auth_provider.dart';

class BusinessSelectionScreen extends ConsumerWidget {
  final List<Business> businesses;

  const BusinessSelectionScreen({super.key, required this.businesses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Business')),
      body: SafeArea(
        top: false,
        child: businesses.isEmpty
            ? const _EmptyBusinessState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final business = businesses[index];

                  return _BusinessCard(
                    business: business,
                    onTap: () {
                      ref
                          .read(authStateProvider.notifier)
                          .selectBusiness(business);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Business business;
  final VoidCallback onTap;

  const _BusinessCard({required this.business, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              _BusinessLogo(business: business),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name.isNotEmpty
                          ? business.name
                          : 'Unnamed Business',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      business.address ??
                          business.businessType ??
                          'Business information unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B6B70),
                      ),
                    ),

                    if (business.businessType != null &&
                        business.address != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        business.businessType!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessLogo extends StatelessWidget {
  final Business business;

  const _BusinessLogo({required this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!business.hasLogo) {
      return _fallbackLogo(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        business.logoUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) {
          return _fallbackLogo(theme);
        },
      ),
    );
  }

  Widget _fallbackLogo(ThemeData theme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_outlined,
        color: theme.colorScheme.primary,
        size: 25,
      ),
    );
  }
}

class _EmptyBusinessState extends StatelessWidget {
  const _EmptyBusinessState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No businesses available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are currently no businesses associated with your account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
