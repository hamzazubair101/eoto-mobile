import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class FinalExamTicketWidget extends StatelessWidget {
  final Map<String, dynamic> learner;

  const FinalExamTicketWidget({Key? key, required this.learner}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Ticket Part (Header)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFF1E1E1E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppTheme.primaryLime, shape: BoxShape.circle),
                      child: const Icon(Icons.confirmation_num_outlined, color: Colors.black, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EOTO CAMPAIGN',
                          style: TextStyle(color: AppTheme.primaryLime, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0),
                        ),
                        Text(
                          'FINAL EXAM TICKET',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFICIAL',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Lower Ticket Part (Metadata)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTicketRow('LEARNER NAME', learner['name'], 'LEARNER ID', learner['id']),
                const SizedBox(height: 16),
                _buildTicketRow(
                  'EXAM DATE',
                  learner['examDate'] != null && learner['examDate'].toString().isNotEmpty ? learner['examDate'].toString() : 'TBA',
                  'EXAM TIME',
                  learner['examTime'] != null && learner['examTime'].toString().isNotEmpty ? learner['examTime'].toString() : 'TBA',
                ),
                const SizedBox(height: 16),
                const Text(
                  'EXAM LOCATION',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  learner['examLocation'] != null && learner['examLocation'].toString().isNotEmpty
                      ? learner['examLocation'].toString()
                      : 'Venue to be confirmed by Focal Person',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                
                const SizedBox(height: 24),
                // Custom Dotted Separator
                Row(
                  children: List.generate(
                    30,
                    (index) => Expanded(
                      child: Container(
                        color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
                        height: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Mock Barcode
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 48,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            42,
                            (index) => Container(
                              width: (index % 3 == 0) ? 4.0 : ((index % 5 == 0) ? 1.5 : 2.5),
                              color: index % 7 == 0 ? Colors.transparent : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '* ${learner['id']}-${learner['examDate']?.replaceAll("-", "")} *',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(String label1, String value1, String label2, String value2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label2,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                value2,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
