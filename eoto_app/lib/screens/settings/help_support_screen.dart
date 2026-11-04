import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  final bool isFocalPerson;

  const HelpSupportScreen({
    Key? key,
    this.isFocalPerson = false,
  }) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  late List<Map<String, dynamic>> _faqs;

  @override
  void initState() {
    super.initState();
    if (widget.isFocalPerson) {
      _faqs = [
        {
          'question': 'How does the 120-Hour Escalation work?',
          'answer':
              'If a focal person does not review a volunteer or learner submission within 120 hours, or if a volunteer remains inactive, the ticket automatically escalates to the NCHD Super Admin SLA center for direct intervention and learner re-assignment.',
          'expanded': false,
        },
        {
          'question': 'How do I reschedule a Final Exam?',
          'answer':
              'Open the learner\'s EOTO Lifecycle / Exam Scheduler card, unlock the assessment window gate, and assign an extended physical evaluation slot.',
          'expanded': false,
        },
        {
          'question': 'What if a Learner fails the Baseline Assessment?',
          'answer':
              'If a learner does not meet baseline criteria or already demonstrates literacy competence, reject the baseline with audit checklist remarks or assign a remedial preparatory cycle.',
          'expanded': false,
        },
      ];
    } else {
      _faqs = [
        {
          'question': 'How do I log daily attendance?',
          'answer':
              'Open your learner\'s progress calendar and tap "+ Log Today\'s Class". Lock your real-time GPS coordinates within the learner\'s geofence, select today\'s syllabus topic, and complete the mandatory 60-minute live teaching timer.',
          'expanded': false,
        },
        {
          'question': 'When is the Mid-Term Assessment due?',
          'answer':
              'The Mid-Term Assessment triggers automatically upon reaching the 15-session milestone (Mid-Term gate). You must upload the solved mid-term evaluation sheet to unlock subsequent classes.',
          'expanded': false,
        },
        {
          'question': 'How do I receive my 10 Academic Marks?',
          'answer':
              'Once your learner completes the full teaching cycle and clears the Final Evaluation verified by your Institutional Focal Person, NCHD issues your official literacy certificate and 10 academic credit marks sign-off.',
          'expanded': false,
        },
      ];
    }
  }

  Future<void> _callITHelpdesk() async {
    final Uri callUri = Uri(scheme: 'tel', path: '051111222333');
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        throw 'Could not launch $callUri';
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('EOTO IT Helpline',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: const Text(
              'Direct Federal IT Helpline: 051-111-222-333\n\nAvailable Mon–Sat (9:00 AM – 6:00 PM PKT).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _emailSuperAdmin() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'super_admin@nchd.gov.pk',
      queryParameters: {
        'subject': 'Priority Escalation: Institutional Focal Person Support'
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'Could not launch $emailUri';
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('NCHD Super Admin Escalation',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: const Text(
              'Priority Escalation Desk: super_admin@nchd.gov.pk\n\nDirect federal escalation channel for Institutional Focal Officers.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showReportIssueModal() {
    String selectedCategory = 'Technical';
    final TextEditingController issueController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Report an Issue',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Categorize your problem and submit a support ticket to the EOTO IT Helpdesk.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ISSUE CATEGORY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['Technical', 'Learner Data', 'Assessment']
                            .map((cat) {
                          final bool isSelected = selectedCategory == cat;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedCategory = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFCCFF00)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.transparent,
                                    width: 1.3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: issueController,
                        maxLines: 3,
                        style: const TextStyle(
                            color: Colors.black, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText:
                              'Describe the bug or issue you are facing...',
                          hintStyle: const TextStyle(
                              color: Colors.grey, fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.6),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a brief description of the issue';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCCFF00),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('support_tickets')
                                        .add({
                                      'category': selectedCategory,
                                      'description':
                                          issueController.text.trim(),
                                      'userEmail': FirebaseAuth
                                              .instance.currentUser?.email ??
                                          'volunteer@eoto.pk',
                                      'createdAt':
                                          FieldValue.serverTimestamp(),
                                      'status': 'Open',
                                    });
                                  } catch (_) {}
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                  }
                                  if (mounted) {
                                    AppTheme.showSuccessSnackBar(
                                      context,
                                      'Bug ticket ($selectedCategory) submitted to EOTO IT Helpdesk!',
                                    );
                                  }
                                },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            isSubmitting
                                ? 'SUBMITTING TICKET...'
                                : 'SUBMIT BUG TICKET',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFAQAccordion(int index) {
    final faq = _faqs[index];
    final bool isExpanded = faq['expanded'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              faq['question'],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.black54,
            ),
            onTap: () {
              setState(() {
                faq['expanded'] = !isExpanded;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq['answer'],
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isFocalPerson ? 'Help & Support' : 'App Help & FAQs',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dual Action Cards
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _callITHelpdesk,
                      child: Container(
                        height: 148,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFCCFF00).withOpacity(0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.black.withOpacity(0.08),
                              child: const Icon(Icons.headphones_outlined,
                                  color: Colors.black, size: 22),
                            ),
                            Text(
                              widget.isFocalPerson
                                  ? 'Federal IT\nSupport'
                                  : 'Call EOTO\nIT Helpline',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.isFocalPerson
                          ? _emailSuperAdmin
                          : _showReportIssueModal,
                      child: Container(
                        height: 148,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.black.withOpacity(0.06),
                              child: Icon(
                                widget.isFocalPerson
                                    ? Icons.mail_outline
                                    : Icons.bug_report_outlined,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                            Text(
                              widget.isFocalPerson
                                  ? 'Super Admin\nEscalation'
                                  : 'Report an\nIssue / Bug',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Text(
                widget.isFocalPerson
                    ? 'Administrator FAQs'
                    : 'Student-Teacher FAQs',
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),

              Column(
                children: List.generate(
                  _faqs.length,
                  (index) => _buildFAQAccordion(index),
                ),
              ),
              const SizedBox(height: 24),

              // System Info Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black.withOpacity(0.05),
                          child: const Icon(Icons.info_outline,
                              color: Colors.black87, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EOTO Literacy Platform',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.isFocalPerson
                                    ? 'Super Admin Escalation: super_admin@nchd.gov.pk'
                                    : 'Version 1.0.4 • NCHD Official Release',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
