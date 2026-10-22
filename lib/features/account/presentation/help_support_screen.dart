import 'package:flutter/material.dart';
import 'package:you_too_art/features/account/presentation/account_sheets.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<FaqItem> _allFaqs = [
    FaqItem(
      question: 'What is the You2Art?',
      answer:
          'You2Art is a dedicated professional networking and creative showcase platform '
          'designed for artists, actors, directors, producers, and creative industry professionals '
          'to connect, collaborate, and discover new opportunities.',
    ),
    FaqItem(
      question: 'How do I create an account on the You2Art?',
      answer:
          'You can sign up directly within the app using your email address. During setup, you can '
          'select your creative discipline (e.g. Actor, Director, Cinematographer, Musician) and configure your public profile.',
    ),
    FaqItem(
      question: 'What types of content can I share on the app?',
      answer:
          'You can share posts, behind-the-scenes updates, showreels, audition clips, high-resolution photographs, '
          'project milestones, and casting announcements relevant to your creative craft.',
    ),
    FaqItem(
      question: 'How can I interact with other users?',
      answer:
          'You can send connection requests to collaborate, message artists directly via in-app chat, '
          'react to and comment on their posts, and apply to casting calls hosted by verified production houses.',
    ),
    FaqItem(
      question: 'Is my personal information safe on the app?',
      answer:
          'We take your privacy seriously. Your personal information is protected through security measures '
          'and data encryption. You can control your privacy settings to determine who can view your content and interact with you.',
    ),
    FaqItem(
      question: 'How can I discover actors and directors?',
      answer:
          'Navigate to the Talent or Network tab to filter creative professionals by role, discipline, '
          'experience level, or location. You can view their full portfolio and connect instantly.',
    ),
    FaqItem(
      question: 'Can I customize my feed to see specific types of art?',
      answer:
          'Yes! Your feed dynamically reflects the creators you connect with and follow. You can also filter '
          'by categories and hashtags across the home stream.',
    ),
    FaqItem(
      question: 'How can I provide feedback or report inappropriate content?',
      answer:
          'You can tap the three-dots menu on any post or user profile to report inappropriate content or '
          'contact our community support team at support@you2art.com.',
    ),
  ];

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _searchQuery.isEmpty
        ? _allFaqs
        : _allFaqs
            .where(
              (f) =>
                  f.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  f.answer.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Search Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9E9E9E),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9E9E9E)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  hintText: 'Search',
                  hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // ─── Section Header ─────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),

          // ─── FAQ List ───────────────────────────────────
          Expanded(
            child: filteredFaqs.isEmpty
                ? const Center(
                    child: Text(
                      'No matching questions found',
                      style: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredFaqs.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0xFFF0F0F0),
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredFaqs[index];
                      return InkWell(
                        onTap: () {
                          AccountSheets.showFaqAnswer(
                            context,
                            question: item.question,
                            answer: item.answer,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.question,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A2E),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF3899F3),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
