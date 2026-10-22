import 'package:flutter/material.dart';

class TransactionItem {
  final bool isSuccess;
  final String title;
  final String description;
  final String transactionId;
  final String time;
  final String amount;

  const TransactionItem({
    required this.isSuccess,
    required this.title,
    required this.description,
    required this.transactionId,
    required this.time,
    required this.amount,
  });
}

class TransactionSection {
  final String date;
  final String totalAmount;
  final List<TransactionItem> items;

  const TransactionSection({
    required this.date,
    required this.totalAmount,
    required this.items,
  });
}

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  static const List<TransactionSection> _transactions = [
    TransactionSection(
      date: 'Today',
      totalAmount: '₹500',
      items: [
        TransactionItem(
          isSuccess: true,
          title: 'Successful!',
          description: '6 Months Subscription to apply for Casting Call.',
          transactionId: '#TID1212',
          time: '12:00 Am',
          amount: '₹500',
        ),
        TransactionItem(
          isSuccess: false,
          title: 'Failed!',
          description: '6 Months Subscription to apply for Casting Call.',
          transactionId: '#TID1212',
          time: '11:53 Am',
          amount: '₹500',
        ),
      ],
    ),
    TransactionSection(
      date: '26 May',
      totalAmount: '₹1000',
      items: [
        TransactionItem(
          isSuccess: true,
          title: 'Successful!',
          description: '6 Months Subscription to apply for Casting Call.',
          transactionId: '#TID1212',
          time: '12:00 Am',
          amount: '₹500',
        ),
        TransactionItem(
          isSuccess: true,
          title: 'Successful!',
          description: '6 Months Subscription to apply for Casting Call.',
          transactionId: '#TID1212',
          time: '12:00 Am',
          amount: '₹500',
        ),
        TransactionItem(
          isSuccess: false,
          title: 'Failed!',
          description: '6 Months Subscription to apply for Casting Call.',
          transactionId: '#TID1212',
          time: '11:53 Am',
          amount: '₹500',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          'Transaction History',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _transactions.length,
        itemBuilder: (context, sectionIndex) {
          final section = _transactions[sectionIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      section.date,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      section.totalAmount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3899F3),
                      ),
                    ),
                  ],
                ),
              ),

              // Items
              ...section.items.map((item) => _buildTransactionCard(item)),

              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(TransactionItem item) {
    final statusColor =
        item.isSuccess ? const Color(0xFF00C48C) : const Color(0xFFE53935);
    final bgIconColor =
        item.isSuccess ? const Color(0xFFE8F8F3) : const Color(0xFFFEECEB);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgIconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isSuccess ? Icons.check : Icons.block_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF424242),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      item.transactionId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3899F3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              item.amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
