import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/app_logos.dart';
import 'focal_exam_scheduler_screen.dart';
import 'focal/teacher_review_detail_screen.dart';
import 'focal/learner_review_detail_screen.dart';
import 'focal/focal_active_classes_screen.dart';
import 'notifications_center_screen.dart';
import 'settings/help_support_screen.dart';
import 'settings/profile_sub_screens.dart';
import '../utils/logout_helper.dart';

class FocalPersonDashboard extends StatefulWidget {
  final String? focalEmail;
  const FocalPersonDashboard({Key? key, this.focalEmail}) : super(key: key);

  @override
  _FocalPersonDashboardState createState() => _FocalPersonDashboardState();
}

class _FocalPersonDashboardState extends State<FocalPersonDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  String _searchQuery = '';
  String _selectedSubTab = 'teachers'; // 'teachers' or 'learners'
  bool _showAllItems = false;
  final TextEditingController _searchController = TextEditingController();

  String get effectiveFocalEmail => (widget.focalEmail ?? FirebaseAuth.instance.currentUser?.email ?? 'cust_focal@eoto.pk').toLowerCase().trim();

  Map<String, String> _getLocalFocalDetails(String email) {
    email = email.toLowerCase().trim();
    if (email == 'cust_focal@eoto.pk') {
      return {'name': 'Dr. Daud Arshad', 'info': 'Capital University of Science and Technology (CUST)'};
    } else if (email == 'nust_focal@eoto.pk') {
      return {'name': 'Dr. Sajid Ali', 'info': 'National University of Sciences and Technology (NUST)'};
    } else if (email == 'fast_focal@eoto.pk') {
      return {'name': 'Dr. Fareeha Raza', 'info': 'FAST National University'};
    } else if (email == 'comsats_focal@eoto.pk') {
      return {'name': 'Prof. Mukhtar Ahmed', 'info': 'COMSATS University'};
    } else if (email == 'pu_focal@eoto.pk') {
      return {'name': 'Dr. Ahmed', 'info': 'Punjab University, Lahore'};
    } else if (email == 'islamabad_officer@eoto.pk') {
      return {'name': 'Mr. Danish Abbas', 'info': 'Islamabad (ICT)'};
    } else if (email.endsWith('_officer@eoto.pk')) {
      final String districtPart = email.split('_officer@eoto.pk').first.replaceAll('_', ' ');
      final String capitalizedDistrict = districtPart.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');
      return {'name': 'Mr. Khan', 'info': 'NCHD $capitalizedDistrict Officer'};
    }
    return {'name': 'Focal Officer', 'info': 'NCHD Office'};
  }



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRejectDialog(String applicantId, String applicantName) {
    final TextEditingController _remarksController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: Text(
          'Reject Application',
          style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting $applicantName',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textBlack),
                decoration: const InputDecoration(
                  labelText: 'Mandatory Remarks',
                  hintText: 'Reason for rejection...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Remarks are mandatory for rejection';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Update Firestore to 'rejected'
                await FirebaseFirestore.instance
                    .collection('teachers')
                    .doc(applicantId)
                    .update({
                  'status': 'rejected',
                  'rejectionRemarks': _remarksController.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application Rejected')),
                );
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    bool isStudent = (app['role'] ?? '').toString().toLowerCase() == 'student';
    return Card(
      color: AppTheme.cardLight,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  app['id'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                Text(
                  app['date'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isStudent ? AppTheme.primaryLime.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                  child: Icon(
                    isStudent ? Icons.school : Icons.volunteer_activism,
                    color: isStudent ? AppTheme.primaryLime : Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['name'],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${app['role']} • ${app['district']}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (app['status'] == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(app['id'], app['name']),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Update Firestore status to 'approved'
                        await FirebaseFirestore.instance
                            .collection('teachers')
                            .doc(app['id'])
                            .update({'status': 'approved'});
                            
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${app['name']} Approved!')),
                          );
                        }
                      },
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TeacherReviewDetailScreen(applicant: app),
                    ),
                  );
                },
                child: Text('Review Documents', style: TextStyle(color: AppTheme.primaryLime)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEOTOLearnersTab(BuildContext context) {
    final String currentFocalEmail = effectiveFocalEmail;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('learners')
          .where('assignedFocalPersonEmail', isEqualTo: currentFocalEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'No EOTO learners in lifecycle pipeline.',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final lifecycleLearners = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data
          };
        }).where((l) {
          final s = l['status'] ?? '';
          return s == 'Week 12 Completed' ||
              s == 'Exam Scheduled' ||
              s == 'Completed' ||
              s == 'Certified';
        }).toList();

        if (lifecycleLearners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'No EOTO learners in lifecycle pipeline.',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lifecycleLearners.length,
          itemBuilder: (context, index) {
            final learner = lifecycleLearners[index];
            final status = learner['status'] ?? 'Week 12 Completed';

            Color statusColor;
            String statusTitle = status;
            IconData statusIcon = Icons.school_rounded;

            if (status == 'Week 12 Completed') {
              statusColor = Colors.blueAccent;
              statusTitle = 'Exam Pending';
              statusIcon = Icons.calendar_today_rounded;
            } else if (status == 'Exam Scheduled') {
              statusColor = Colors.orangeAccent;
              statusTitle = 'Grading Pending';
              statusIcon = Icons.assignment_outlined;
            } else if (status == 'Completed') {
              statusColor = AppTheme.primaryLime;
              statusTitle = 'Logistics Dispatch';
              statusIcon = Icons.local_shipping_outlined;
            } else {
              statusColor = Colors.green;
              statusTitle = 'Certified Cycle';
              statusIcon = Icons.verified_rounded;
            }

            return Card(
              color: AppTheme.cardLight,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FocalExamSchedulerScreen(learner: learner),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            learner['id'] ?? 'L-0000',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 10, color: statusColor == AppTheme.primaryLime ? Colors.green[800] : statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusTitle.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor == AppTheme.primaryLime ? Colors.green[800] : statusColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: statusColor.withOpacity(0.12),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: statusColor == AppTheme.primaryLime ? Colors.green[800] : statusColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  learner['name'] ?? 'Unknown',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'District: ${learner['district'] ?? "Islamabad (ICT)"} • Parentage: ${learner['parentage'] ?? "Fazal Ahmad"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            status == 'Certified' ? 'View Certificate History' : 'Manage EOTO Lifecycle',
                            style: TextStyle(
                              color: Colors.green[800] ?? AppTheme.primaryLime,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.green[800] ?? AppTheme.primaryLime,
                          ),
                        ],
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

  Widget _buildTriageTab(String status) {
    final String currentFocalEmail = effectiveFocalEmail;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teachers')
          .where('assignedFocalPersonEmail', isEqualTo: currentFocalEmail)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No $status applications found.',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final Map<String, dynamic> app = {
              'id': docs[index].id,
              'name': data['fullName'] ?? 'Unknown',
              'role': data['role'] == 'student' ? 'Student' : 'Community Volunteer',
              'district': data['district'] ?? 'N/A',
              'date': data['createdAt'] != null 
                  ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0] 
                  : 'Just Now',
              'email': data['email'] ?? '',
              'institute': data['instituteName'] ?? '',
              ...data
            };
            return _buildApplicationCard(app);
          },
        );
      },
    );
  }

  Widget _getFocalPage(int index) {
    switch (index) {
      case 0:
        final String currentFocalEmail = effectiveFocalEmail;

        return Scaffold(
          backgroundColor: Colors.white,
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('focal_persons')
                .doc(currentFocalEmail)
                .snapshots(),
            builder: (context, focalSnapshot) {
              final localDetails = _getLocalFocalDetails(currentFocalEmail);
              final String name = (focalSnapshot.hasData && focalSnapshot.data!.exists)
                  ? (focalSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? localDetails['name']!
                  : localDetails['name']!;
              
              // Extract first name for the greeting
              final String displayGreetingName = name.startsWith("Dr.") || name.startsWith("Prof.")
                  ? name.split(' ').take(2).join(' ') 
                  : name.split(' ').first;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teachers')
                    .where('assignedFocalPersonEmail', isEqualTo: currentFocalEmail)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, teachersSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('learners')
                        .where('assignedFocalPersonEmail', isEqualTo: currentFocalEmail)
                        .where('status', isEqualTo: 'Pending Review')
                        .snapshots(),
                    builder: (context, learnersSnapshot) {
                      final int pendingTeachersCount = teachersSnapshot.hasData ? teachersSnapshot.data!.docs.length : 0;
                      final int pendingLearnersCount = learnersSnapshot.hasData ? learnersSnapshot.data!.docs.length : 0;
                      final int totalPendingReviews = pendingTeachersCount + pendingLearnersCount;

                       // Compute SLA Urgent count (<24h left out of 120h limit, meaning elapsed time > 96h)
                       int urgentCount = 0;
                       final now = DateTime.now();
 
                       if (teachersSnapshot.hasData) {
                         for (var doc in teachersSnapshot.data!.docs) {
                           final data = doc.data() as Map<String, dynamic>;
                           final Timestamp? ts = data['createdAt'] as Timestamp?;
                           if (ts != null) {
                             final elapsedHours = now.difference(ts.toDate()).inHours;
                             if (elapsedHours >= 96) {
                               urgentCount++;
                             }
                           }
                         }
                       }
                       if (learnersSnapshot.hasData) {
                         for (var doc in learnersSnapshot.data!.docs) {
                           final data = doc.data() as Map<String, dynamic>;
                           final Timestamp? ts = data['createdAt'] as Timestamp?;
                           if (ts != null) {
                             final elapsedHours = now.difference(ts.toDate()).inHours;
                             if (elapsedHours >= 96) {
                               urgentCount++;
                             }
                           }
                         }
                       }

                      final String q = _searchQuery.trim().toLowerCase();

                      // Prepare list of pending teachers to display based on search
                      final List<Map<String, dynamic>> filteredTeachers = [];
                      if (teachersSnapshot.hasData) {
                        for (var doc in teachersSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                          final cnic = (data['cnic'] ?? '').toString().toLowerCase();
                          final email = (data['email'] ?? '').toString().toLowerCase();
                          final phone = (data['phone'] ?? '').toString().toLowerCase();
                          final institute = (data['institute'] ?? '').toString().toLowerCase();
                          final district = (data['district'] ?? '').toString().toLowerCase();
                          final role = (data['role'] ?? '').toString().toLowerCase();

                          final matchesSearch = q.isEmpty || 
                              fullName.contains(q) || 
                              cnic.contains(q) ||
                              email.contains(q) ||
                              phone.contains(q) ||
                              institute.contains(q) ||
                              district.contains(q) ||
                              role.contains(q);
                          if (matchesSearch) {
                            filteredTeachers.add({
                              'id': doc.id,
                              'name': data['fullName'] ?? 'Unknown',
                              'role': data['role'] == 'student' ? 'Student Teacher' : 'Community Volunteer',
                              'district': data['district'] ?? 'N/A',
                              'createdAt': data['createdAt'],
                              'type': 'teacher',
                              ...data
                            });
                          }
                        }
                      }

                      // Prepare list of pending learners to display based on search
                      final List<Map<String, dynamic>> filteredLearners = [];
                      if (learnersSnapshot.hasData) {
                        for (var doc in learnersSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final lName = (data['name'] ?? '').toString().toLowerCase();
                          final idNumber = (data['idNumber'] ?? data['cnic'] ?? '').toString().toLowerCase();
                          final parentage = (data['parentage'] ?? '').toString().toLowerCase();
                          final teacherName = (data['teacherName'] ?? data['assignedTeacherName'] ?? '').toString().toLowerCase();
                          final district = (data['district'] ?? '').toString().toLowerCase();
                          final phone = (data['contactNumber'] ?? data['phone'] ?? '').toString().toLowerCase();

                          final matchesSearch = q.isEmpty || 
                              lName.contains(q) || 
                              idNumber.contains(q) ||
                              parentage.contains(q) ||
                              teacherName.contains(q) ||
                              district.contains(q) ||
                              phone.contains(q);
                          if (matchesSearch) {
                            filteredLearners.add({
                              'id': doc.id,
                              'name': data['name'] ?? 'Unknown',
                              'role': 'Learner Partner',
                              'district': data['district'] ?? 'N/A',
                              'createdAt': data['createdAt'],
                              'type': 'learner',
                              ...data
                            });
                          }
                        }
                      }

                      // Sort by createdAt ascending (oldest/most urgent reviews appear first at the top)
                      filteredTeachers.sort((a, b) {
                        final Timestamp? tsA = a['createdAt'] as Timestamp?;
                        final Timestamp? tsB = b['createdAt'] as Timestamp?;
                        if (tsA == null) return 1;
                        if (tsB == null) return -1;
                        return tsA.compareTo(tsB);
                      });

                      filteredLearners.sort((a, b) {
                        final Timestamp? tsA = a['createdAt'] as Timestamp?;
                        final Timestamp? tsB = b['createdAt'] as Timestamp?;
                        if (tsA == null) return 1;
                        if (tsB == null) return -1;
                        return tsA.compareTo(tsB);
                      });

                      final bool isTeachersSelected = _selectedSubTab == 'teachers';
                      final currentList = isTeachersSelected ? filteredTeachers : filteredLearners;

                      return SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Top Header Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedIndex = 3);
                                    },
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppTheme.primaryLime.withOpacity(0.2),
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'F',
                                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  AppLogos.wordmark(height: 26),
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_none_outlined, color: Colors.black, size: 26),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => NotificationsCenterScreen(
                                                isFocalPerson: true,
                                                focalEmail: currentFocalEmail,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        right: 12,
                                        top: 12,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // 2. Greeting Header
                              Text(
                                'Hello, $displayGreetingName',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 3. Search Bar
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.black),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.trim();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search by name, CNIC, institute, district...',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 4. Summary Stats Row
                              Row(
                                children: [
                                  // Card 1: Pending Reviews
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$totalPendingReviews',
                                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Pending\nReviews',
                                            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.2, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Card 2: Urgent
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$urgentCount',
                                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFC83B0E)),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Urgent\n(<24h)',
                                            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.2, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // 5. Section Title
                              const Text(
                                'Pending Approvals',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                              const SizedBox(height: 16),

                              // 6. Horizontal Toggle Pill Switcher
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedSubTab = 'teachers'),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isTeachersSelected ? const Color(0xFFCCFF00) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Teachers ($pendingTeachersCount)',
                                            style: TextStyle(
                                              color: isTeachersSelected ? Colors.black : Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _selectedSubTab = 'learners'),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: !isTeachersSelected ? const Color(0xFFCCFF00) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Learners ($pendingLearnersCount)',
                                            style: TextStyle(
                                              color: !isTeachersSelected ? Colors.black : Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 7. Applications List View
                              if (currentList.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                                    child: Text(
                                      'No pending ${isTeachersSelected ? "teachers" : "learners"} found.',
                                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              else
                                ...(_showAllItems ? currentList : currentList.take(3)).map((item) {
                                  // Compute SLA hrs left (120 hours default)
                                  final Timestamp? ts = item['createdAt'] as Timestamp?;
                                  int hrsLeft = 120;
                                  bool isOverdue = false;
                                  int hrsOverdue = 0;
                                  if (ts != null) {
                                    final elapsed = now.difference(ts.toDate()).inHours;
                                    if (elapsed >= 120) {
                                      isOverdue = true;
                                      hrsOverdue = elapsed - 120;
                                    } else {
                                      hrsLeft = 120 - elapsed;
                                    }
                                  }
                                  
                                  final bool isUrgent = isOverdue || hrsLeft < 24;
                                  final String initials = item['name'].split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
                                  final String displayInitials = initials.length > 2 ? initials.substring(0, 2) : initials;

                                  final void Function() handleReview = () {
                                    if (item['type'] == 'teacher') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TeacherReviewDetailScreen(
                                            applicant: {
                                              'id': item['id'],
                                              'name': item['name'],
                                              'role': item['role'],
                                              'district': item['district'],
                                              ...item
                                            },
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LearnerReviewDetailScreen(
                                            learner: {
                                              'id': item['id'],
                                              'name': item['name'],
                                              ...item
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  };

                                  return Card(
                                    color: const Color(0xFFF2F2F7),
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: handleReview,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: Colors.grey[800],
                                              child: Text(displayInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['name'],
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                                                  ),
                                                  Text(
                                                    item['role'],
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isUrgent ? const Color(0xFFFFD6D6) : const Color(0xFFD6F5D6),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isOverdue
                                                        ? 'Overdue ($hrsOverdue hrs)'
                                                        : '$hrsLeft hrs left',
                                                    style: TextStyle(
                                                      color: isUrgent ? Colors.red[900] : Colors.green[900],
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFCCFF00),
                                                    foregroundColor: Colors.black,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  ),
                                                  onPressed: handleReview,
                                                  child: const Text(
                                                    'Review',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                              // 8. Bottom Link
                              if (currentList.length > 3)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _showAllItems = !_showAllItems;
                                        });
                                      },
                                      child: Text(
                                        _showAllItems
                                            ? 'Show less ^'
                                            : 'See all ${currentList.length} ${isTeachersSelected ? "teachers" : "learners"} v',
                                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      case 1:
        // Tab 2: Active Classes monitoring matching 1 (2).png
        return FocalActiveClassesScreen(effectiveFocalEmail: effectiveFocalEmail);
      case 2:
        // Tab 3: History (Completed, Certified, and Rejected/Past Records)
        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundLight,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text('History & Logistics', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('learners')
                .where('assignedFocalPersonEmail', isEqualTo: effectiveFocalEmail)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No history records yet.', style: TextStyle(color: Colors.grey)));
              }

              final docs = snapshot.data!.docs;
              final historyList = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  ...data
                };
              }).where((l) {
                final status = (l['status'] ?? '').toString().toLowerCase();
                return status == 'completed' ||
                    status == 'certified' ||
                    status.contains('reject') ||
                    status.contains('delist');
              }).toList();

              if (historyList.isEmpty) {
                return const Center(child: Text('No completed or past records yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: historyList.length,
                itemBuilder: (context, index) {
                  final learner = historyList[index];
                  final rawStatus = (learner['status'] ?? 'Completed').toString();
                  final isRejected = rawStatus.toLowerCase().contains('reject') || rawStatus.toLowerCase().contains('delist');
                  final logistics = learner['certificateLogistics'] ?? {};
                  final teacherName = learner['teacherName'] ?? learner['assignedTeacherName'] ?? 'Volunteer Teacher';

                  return Card(
                    color: AppTheme.cardLight,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LearnerReviewDetailScreen(learner: learner),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        learner['name'] ?? 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Teacher: $teacherName',
                                        style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isRejected ? const Color(0xFFEF4444) : const Color(0xFFCCFF00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isRejected ? 'REJECTED' : rawStatus.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isRejected ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isRejected
                                  ? 'Remarks: ${learner['remarks'] ?? learner['rejectionRemarks'] ?? "Application rejected during review."}'
                                  : 'ID: ${learner['id']} • Grade: ${learner['examGrade'] ?? "Graded"}',
                              style: TextStyle(
                                color: isRejected ? Colors.red[700] : Colors.grey[700],
                                fontSize: 12.5,
                                fontWeight: isRejected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (!isRejected) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Physical Certificate Logistics Timeline:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    children: [
                                      Icon(Icons.check_circle, color: logistics['approved'] == true ? AppTheme.primaryLime : Colors.grey, size: 22),
                                      const SizedBox(height: 4),
                                      const Text('Approved', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Icon(Icons.local_shipping, color: logistics['dispatched'] == true ? AppTheme.primaryLime : Colors.grey, size: 22),
                                      const SizedBox(height: 4),
                                      const Text('Dispatched', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Icon(Icons.verified_user, color: logistics['receivedByFocal'] == true ? AppTheme.primaryLime : Colors.grey, size: 22),
                                      const SizedBox(height: 4),
                                      const Text('Received', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      case 3:
        // Tab 4: Institutional Focal Person "My Profile" Tab
        final String currentEmail = effectiveFocalEmail;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text(
              'My Profile',
              style: TextStyle(
                color: Color(0xFF171717),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFF3F4F6),
              ),
            ),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('focal_persons')
                .doc(currentEmail)
                .snapshots(),
            builder: (context, snapshot) {
              final localDetails = _getLocalFocalDetails(currentEmail);
              final Map<String, dynamic> focalDoc =
                  (snapshot.hasData && snapshot.data!.exists)
                      ? (snapshot.data!.data() as Map<String, dynamic>? ?? {})
                      : {};
              final String name =
                  (focalDoc['name'] ?? localDetails['name']!).toString();
              final String inst = (focalDoc['institute'] ??
                      focalDoc['assignedDistrict'] ??
                      localDetails['info']!)
                  .toString();

              final String initials = name
                  .replaceAll(RegExp(r'^(Dr\.|Mr\.|Ms\.|Prof\.)\s*', caseSensitive: false), '')
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .join()
                  .toUpperCase();
              final String displayInitials =
                  initials.length > 2 ? initials.substring(0, 2) : initials;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teachers')
                    .where('assignedFocalPersonEmail', isEqualTo: currentEmail)
                    .snapshots(),
                builder: (context, teachersSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('learners')
                        .where('assignedFocalPersonEmail',
                            isEqualTo: currentEmail)
                        .snapshots(),
                    builder: (context, learnersSnap) {
                      int verifiedVolunteersCount = 0;
                      if (teachersSnap.hasData) {
                        for (final doc in teachersSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final st =
                              (data['status'] ?? '').toString().toLowerCase();
                          if (st == 'approved' || st == 'active') {
                            verifiedVolunteersCount++;
                          }
                        }
                      }

                      int certifiedLearnersCount = 0;
                      if (learnersSnap.hasData) {
                        for (final doc in learnersSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final st =
                              (data['status'] ?? '').toString().toLowerCase();
                          if (st == 'certified' || st == 'completed') {
                            certifiedLearnersCount++;
                          }
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22.0, vertical: 18.0),
                        children: [
                          // 2.1 Main Profile Card (Crisp White Card with Soft Shadow)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border:
                                  Border.all(color: const Color(0xFFF3F4F6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Administrator Avatar: Rich emerald/forest-gradient circular emblem
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF065F46),
                                        Color(0xFF047857),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF065F46)
                                            .withOpacity(0.28),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    displayInitials.isNotEmpty
                                        ? displayInitials
                                        : 'DA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Focal Officer Name
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF171717),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Role Pill: INSTITUTIONAL FOCAL PERSON (#CCFF00)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFF00),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'INSTITUTIONAL FOCAL PERSON',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10.5,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Campus Venue
                                Text(
                                  inst,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Administrative KPI Counters (Side-by-Side)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F7),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '$verifiedVolunteersCount',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF171717),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Volunteers Verified',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F7),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '$certifiedLearnersCount',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF171717),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Learners Certified',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // 2.2 Menu Options & Administrative Functionality
                          // ① Account Settings
                          _buildFocalSettingsItem(
                            Icons.person_outline_rounded,
                            'Account Settings',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AccountSettingsScreen(
                                    isFocalPerson: true,
                                    focalEmail: currentEmail,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // ② Security & Login
                          _buildFocalSettingsItem(
                            Icons.shield_outlined,
                            'Security & Login',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SecurityAndLoginScreen(
                                    isFocalPerson: true,
                                    focalEmail: currentEmail,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // ③ Notification Preferences
                          _buildFocalSettingsItem(
                            Icons.notifications_none_rounded,
                            'Notification Preferences',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      NotificationPreferencesScreen(
                                    isFocalPerson: true,
                                    focalEmail: currentEmail,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // ④ Help & Support
                          _buildFocalSettingsItem(
                            Icons.help_outline_rounded,
                            'Help & Support',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HelpSupportScreen(
                                          isFocalPerson: true),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 26),

                          // ⑤ Log Out (#2C2D30 dark charcoal pill button, rounded-[30px])
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C2D30),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () =>
                                  LogoutHelper.showLogoutConfirmation(context),
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              label: const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _buildFocalSettingsItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(icon, color: Colors.black, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNavBarItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFCCFF00), // Lime Green active circle/pill
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCCFF00).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? Colors.black : Colors.grey[500],
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[500],
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _getFocalPage(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCustomNavBarItem(0, Icons.home_outlined, Icons.home, 'HOME'),
            _buildCustomNavBarItem(1, Icons.show_chart, Icons.show_chart, 'MONITOR'),
            _buildCustomNavBarItem(2, Icons.history_outlined, Icons.history, 'HISTORY'),
            _buildCustomNavBarItem(3, Icons.person_outline, Icons.person, 'PROFILE'),
          ],
        ),
      ),
    );
  }
}
