import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';

class FocalExamSchedulerScreen extends StatefulWidget {
  final Map<String, dynamic> learner;

  const FocalExamSchedulerScreen({Key? key, required this.learner}) : super(key: key);

  @override
  State<FocalExamSchedulerScreen> createState() => _FocalExamSchedulerScreenState();
}

class _FocalExamSchedulerScreenState extends State<FocalExamSchedulerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Scheduling controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Grading controllers
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use real exam scheduling data from learner if available
    _dateController.text = (widget.learner['examDate'] ?? '').toString();
    _timeController.text = (widget.learner['examTime'] ?? '').toString();
    _locationController.text = (widget.learner['examLocation'] ?? '').toString();
    
    // Real exam grading values if available
    _scoreController.text = widget.learner['examScore'] != null ? widget.learner['examScore'].toString() : '';
    _remarksController.text = (widget.learner['examRemarks'] ?? '').toString();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _scoreController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _handleSchedule() {
    if (!_formKey.currentState!.validate()) return;
    
    Provider.of<RegistrationController>(context, listen: false).scheduleFinalExam(
      widget.learner['id'],
      _dateController.text.trim(),
      _timeController.text.trim(),
      _locationController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Final exam successfully scheduled! Exam Ticket is now active.'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  void _handleGrade() {
    if (!_formKey.currentState!.validate()) return;
    
    final score = double.tryParse(_scoreController.text.trim()) ?? 0.0;

    Provider.of<RegistrationController>(context, listen: false).submitFinalGrade(
      widget.learner['id'],
      score,
      _remarksController.text.trim(),
    );

    AppTheme.showSuccessSnackBar(
      context,
      'Final exam graded! Certification request submitted to NCHD Head Office.',
    );

    Navigator.pop(context);
  }

  void _handleDisqualify() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text('Confirm Disqualification', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to disqualify this cycle? This will delist the learner pair.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRejected),
            onPressed: () {
              Provider.of<RegistrationController>(context, listen: false)
                  .updateLearnerStatus(widget.learner['id'], 'Rejected', remarks: 'Failed final physical exam criteria.');
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to dashboard
            },
            child: const Text('Disqualify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool isCompleted, bool isPulsing, VoidCallback? onAction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot and vertical line connector
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green 
                      : (isPulsing ? AppTheme.primaryLime : const Color(0xFFE5E5EA)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? Colors.green : AppTheme.primaryLime.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted 
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : (isPulsing ? const Icon(Icons.hourglass_empty_rounded, color: Colors.black, size: 14) : null),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                if (isPulsing && onAction != null) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(180, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: AppTheme.primaryLime,
                    ),
                    child: const Text('UPDATE LOGISTICS STATUS', style: TextStyle(fontSize: 12)),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationController>(
      builder: (context, controller, child) {
        // Re-fetch current state of learner
        final currentLearner = controller.learners.firstWhere((l) => l['id'] == widget.learner['id']);
        final status = currentLearner['status'] ?? 'Week 12 Completed';
        
        final bool isWeek12Done = status == 'Week 12 Completed';
        final bool isScheduled = status == 'Exam Scheduled';
        final bool isCompleted = status == 'Completed';
        final bool isCertified = status == 'Certified';

        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textBlack),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isCompleted || isCertified ? 'Certificate Logistics' : 'Exam & Certification',
              style: const TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
            ),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Learner Detail Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryLime.withOpacity(0.15),
                            child: const Icon(Icons.person, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentLearner['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'ID: ${currentLearner['id']} • District: ${currentLearner['district'] ?? "Islamabad (ICT)"}',
                                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // SECTION 1: Exam Scheduling Form
                    if (isWeek12Done) ...[
                      Text(
                        '1. SCHEDULE FINAL PHYSICAL EXAM',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Exam Date',
                          prefixIcon: Icon(Icons.calendar_month, color: AppTheme.textGrey),
                        ),
                        validator: (v) => v!.isEmpty ? 'Date is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _timeController,
                        decoration: const InputDecoration(
                          labelText: 'Exam Time',
                          prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.textGrey),
                        ),
                        validator: (v) => v!.isEmpty ? 'Time is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Exam Location',
                          prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textGrey),
                        ),
                        validator: (v) => v!.isEmpty ? 'Location is required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleSchedule,
                          child: const Text('SCHEDULE PHYSICAL EXAM'),
                        ),
                      ),
                    ],

                    // SECTION 2: Final Exam Grading Form
                    if (isScheduled) ...[
                      Text(
                        '2. FINAL COMPETENCY GRADING',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLime.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Exam scheduled on ${currentLearner['examDate']} at ${currentLearner['examTime']} at ${currentLearner['examLocation']}.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _scoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Test Score (out of 100)',
                          prefixIcon: Icon(Icons.grade_outlined, color: AppTheme.textGrey),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Score is required';
                          final val = double.tryParse(v);
                          if (val == null || val < 0 || val > 100) return 'Enter score between 0 and 100';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Coordinator Remarks',
                          hintText: 'Describe solved paper performance...',
                        ),
                        validator: (v) => v!.isEmpty ? 'Remarks are required' : null,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.statusRejected),
                                foregroundColor: AppTheme.statusRejected,
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              onPressed: _handleDisqualify,
                              child: const Text('Disqualify Pair'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleGrade,
                              child: const Text('Apply for Certificate'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // SECTION 3: Certificate Logistics Vertical Timeline
                    if (isCompleted || isCertified) ...[
                      Text(
                        'CERTIFICATE TRACKER (VERTICAL TIMELINE)',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withOpacity(0.04)),
                        ),
                        child: Column(
                          children: [
                            _buildTimelineStep(
                              'Approved by NCHD Head Office',
                              true,
                              false,
                              null,
                            ),
                            _buildTimelineStep(
                              'Dispatched by NCHD Head Office',
                              currentLearner['certificateLogistics']['dispatched'] == true,
                              currentLearner['certificateLogistics']['dispatched'] == false,
                              () => controller.updateCertificateLogisticsStep(currentLearner['id'], 'dispatched'),
                            ),
                            _buildTimelineStep(
                              'Received by Focal Person',
                              currentLearner['certificateLogistics']['receivedByFocal'] == true,
                              currentLearner['certificateLogistics']['dispatched'] == true && currentLearner['certificateLogistics']['receivedByFocal'] == false,
                              () => controller.updateCertificateLogisticsStep(currentLearner['id'], 'receivedByFocal'),
                            ),
                            _buildTimelineStep(
                              'Handover Confirmed (Handed to Teacher & Learner)',
                              currentLearner['certificateLogistics']['handoverConfirmed'] == true,
                              currentLearner['certificateLogistics']['receivedByFocal'] == true && currentLearner['certificateLogistics']['handoverConfirmed'] == false,
                              () => controller.updateCertificateLogisticsStep(currentLearner['id'], 'handoverConfirmed'),
                            ),
                          ],
                        ),
                      ),
                      if (isCertified) ...[
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLime.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryLime),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.verified_rounded, color: Colors.green, size: 48),
                              SizedBox(height: 12),
                              Text(
                                'Cycle Officially Certified!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'The physical certificate was successfully handed over and chain of custody completed.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      ]
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
