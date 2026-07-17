import 'package:flutter/material.dart';

import '../../constants.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help / FAQ')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.night, Color(0xFF0F2A21)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            _HelpIntroCard(),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'General',
              items: [
                _FaqItem(
                  question: 'What is CommunityShare?',
                  answer:
                      'CommunityShare is a role-based donation platform connecting admins, donors, recipients, and community hubs.',
                ),
                _FaqItem(
                  question: 'Who can use this page?',
                  answer:
                      'Everyone signed into the app can open this Help / FAQ page from the hamburger menu.',
                ),
                _FaqItem(
                  question: 'Why is some access restricted?',
                  answer:
                      'Pages and actions are shown based on your role and your current account status.',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'Donor FAQ',
              items: [
                _FaqItem(
                  question: 'How do donors manage listings?',
                  answer:
                      'Donors can create listings, review incoming requests, track donation progress, and manage handover details from their role pages.',
                ),
                _FaqItem(
                  question: 'How do donors handle requests?',
                  answer:
                      'Incoming requests are reviewed from the donor request flow, where donors can approve, reject, and continue handover steps.',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'Recipient FAQ',
              items: [
                _FaqItem(
                  question: 'How do recipients request an item?',
                  answer:
                      'Recipients can browse available items, open the item details page, and submit a request there.',
                ),
                _FaqItem(
                  question: 'How do recipients check request progress?',
                  answer:
                      'Recipients can use the Request Status page to follow approval, handover, and completion updates.',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'Hub FAQ',
              items: [
                _FaqItem(
                  question: 'What does a community hub do?',
                  answer:
                      'Community hubs help coordinate handovers, confirm items received at the hub, and confirm final collection.',
                ),
                _FaqItem(
                  question: 'What is the hub handover page for?',
                  answer:
                      'The hub handover page is used to review hub-assigned requests and confirm when an item arrives at or leaves the community hub.',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'Admin FAQ',
              items: [
                _FaqItem(
                  question: 'What can admins manage?',
                  answer:
                      'Admins can manage users, review flagged listings, and maintain role-linked records through the admin tools.',
                ),
                _FaqItem(
                  question: 'What does deleting a user do?',
                  answer:
                      'Deleting a user removes their authentication account and linked role-related records, rather than just hiding them in the UI.',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            _FaqSection(
              title: 'Account FAQ',
              items: [
                _FaqItem(
                  question: 'Why can an inactive account access fewer pages?',
                  answer:
                      'Inactive accounts are guided back to profile completion so the required details can be updated before normal access resumes.',
                ),
                _FaqItem(
                  question: 'How do I update my profile?',
                  answer:
                      'Open the Profile tab from the bottom navigation bar and save the required fields there.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpIntroCard extends StatelessWidget {
  const _HelpIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.pine),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help / FAQ',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Use this page for quick guidance on the common actions and rules inside CommunityShare.',
            style: TextStyle(color: AppColors.mist, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.title, required this.items});

  final String title;
  final List<_FaqItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        ...items,
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.pine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: AppColors.mint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              answer,
              style: const TextStyle(color: AppColors.mist, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
