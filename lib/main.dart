import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hello_flutter/api_service.dart';
import 'package:hello_flutter/database_helper.dart';
import 'package:hello_flutter/navigation_wrapper.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hello_flutter/asr_tts.dart';
import 'package:huawei_ml_text/huawei_ml_text.dart';
import 'task_notification_service.dart';
import 'package:intl/intl.dart';
import 'user_storage.dart';

// --- MAIN APPLICATION SETUP ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  const apiKey = 'DgEDAD4Fwo+0Obg0JBKvv4ebb3cGtiXHrIo4nwir/u/lzWYhRNG4cKYW003exwAeVliZwI4GnyOoS2/lRIYqXGcgz7jZNCxs9Dsztw==';
  await MLTextApplication().setApiKey(apiKey);
  await TaskNotificationService.initialize();

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Life Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF42A5F5),
          surface: Colors.white,
        ),
      ),
      home: const NavigationWrapper(),
    );
  }
}

// ====================================================================
// --- NEW PAGE: STUDENT DASHBOARD (Home Page) ---
// ====================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
                setState(() {});
              },
              tooltip: 'Chat Assistant',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildWelcomeCard(context),
            const SizedBox(height: 28),

            _buildSectionHeader('Priority Tasks', Icons.task_alt_rounded),
            const SizedBox(height: 12),
            _buildTasksCard(),
            const SizedBox(height: 28),

            _buildSectionHeader('Next 24 Hours', Icons.schedule_rounded),
            const SizedBox(height: 12),
            _buildScheduleCard(),
            const SizedBox(height: 28),

            _buildSectionHeader('Quick Notes', Icons.note_rounded),
            const SizedBox(height: 12),
            _buildQuickNotesCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final choice = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Quick Add',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActionTile(
                          icon: Icons.task_rounded,
                          title: 'Add Task',
                          subtitle: 'Create a new task with deadline',
                          color: Colors.blue,
                          onTap: () => Navigator.pop(context, 'task'),
                        ),
                        _buildQuickActionTile(
                          icon: Icons.note_add_rounded,
                          title: 'Add Note',
                          subtitle: 'Save a quick note',
                          color: Colors.green,
                          onTap: () => Navigator.pop(context, 'note'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            );

            if (choice == 'task') {
              await _showInputDialog(context, "Enter new task:");
              setState(() {});
            } else if (choice == 'note') {
              await _showInputDialog(context, "Enter note:");
              setState(() {});
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: UserStorage.getUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasUserData = user != null && user['name'] != null && user['name'].isNotEmpty;
        
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1976D2),
                Color(0xFF1565C0),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // Avatar or Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hasUserData ? Icons.person_rounded : Icons.school_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUserData 
                            ? 'Welcome, ${user['name']}!' 
                            : 'Welcome Back!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasUserData
                            ? '${user['levelOfStudy']} • ${user['institution']}'
                            : 'Manage your studies and personal life efficiently.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Edit Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _showUserProfileDialog(context, user),
                    tooltip: 'Edit Profile',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserProfileDialog(BuildContext context, Map<String, dynamic>? existingUser) {
    final nameController = TextEditingController(text: existingUser?['name'] ?? '');
    final ageController = TextEditingController(text: existingUser?['age']?.toString() ?? '');
    final institutionController = TextEditingController(text: existingUser?['institution'] ?? '');
    
    String selectedSex = existingUser?['sex'] ?? 'Male';
    String selectedLevel = existingUser?['levelOfStudy'] ?? 'Undergraduate';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded, color: Colors.blue[700]),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _buildDialogTextField(
                  controller: nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter your name',
                ),
                const SizedBox(height: 16),

                // Age
                _buildDialogTextField(
                  controller: ageController,
                  label: 'Age',
                  icon: Icons.cake_rounded,
                  hint: 'Enter your age',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Sex Selection
                Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Male', style: TextStyle(fontSize: 14)),
                          value: 'Male',
                          groupValue: selectedSex,
                          onChanged: (value) {
                            setDialogState(() => selectedSex = value!);
                          },
                          dense: true,
                          activeColor: Colors.blue[700],
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Female', style: TextStyle(fontSize: 14)),
                          value: 'Female',
                          groupValue: selectedSex,
                          onChanged: (value) {
                            setDialogState(() => selectedSex = value!);
                          },
                          dense: true,
                          activeColor: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Level of Study
                Text(
                  'Level of Study',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLevel,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.blue[700]),
                      items: [
                        'High School',
                        'Undergraduate',
                        'Graduate',
                        'PhD',
                        'Professional',
                      ].map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedLevel = value!);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Institution
                _buildDialogTextField(
                  controller: institutionController,
                  label: 'Institution',
                  icon: Icons.school_rounded,
                  hint: 'Enter your institution',
                ),
                const SizedBox(height: 12),

                // Clear profile option
                if (existingUser != null && existingUser['name'] != null)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Clear Profile?'),
                          content: const Text('This will remove all your profile information.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        await UserStorage.clearUser();
                        Navigator.pop(context);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Profile cleared'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    label: const Text(
                      'Clear Profile',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final ageText = ageController.text.trim();
                final institution = institutionController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter your name'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }

                final age = int.tryParse(ageText) ?? 0;

                await UserStorage.saveUser(
                  name: name,
                  sex: selectedSex,
                  age: age,
                  levelOfStudy: selectedLevel,
                  institution: institution,
                  pinnedNoteId: existingUser?['pinnedNoteId'] ?? 0,
                );

                Navigator.pop(context);
                setState(() {});
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ Profile updated successfully!'),
                    backgroundColor: Colors.green[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.blue[700], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  String tasktitle = '';

  Widget _buildTasksCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.task_alt_rounded, color: Colors.grey[400], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No tasks yet. Tap + to add one.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final tasks = snapshot.data!;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: tasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              final isLast = index == tasks.length - 1;
              
              // Get notification count synchronously
              final notificationCount = TaskNotificationService.getNotificationCount(task['id'].toString());
              final hasReminders = notificationCount > 0;
              
              return Column(
                children: [
                  ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.task_rounded,
                            color: Colors.blue[700],
                            size: 22,
                          ),
                        ),
                        title: Text(
                          task['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: task['due'] != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      task['due'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (hasReminders) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.notifications_active_rounded, size: 10, color: Colors.green[700]),
                                            const SizedBox(width: 3),
                                            Text(
                                              '$notificationCount',
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: hasReminders ? Colors.green[50] : Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  hasReminders ? Icons.alarm_on_rounded : Icons.alarm_add_rounded,
                                  color: hasReminders ? Colors.green[700] : Colors.orange[700],
                                  size: 20,
                                ),
                                onPressed: () async {
                                  // Get notification count
                                  final count = TaskNotificationService.getNotificationCount(task['id'].toString());
                                  
                                  if (count > 0) {
                                    // Cancel all notifications if reminders exist
                                    await TaskNotificationService.cancelAllTaskNotifications(task['id'].toString());
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$count reminder(s) deleted'),
                                        backgroundColor: Colors.orange[700],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  } else {
                                    // Schedule multiple notifications
                                    try {
                                      // Parse the due date string to DateTime
                                      DateTime? taskDueDate;
                                      if (task['due'] != null && task['due'].isNotEmpty) {
                                        try {
                                          taskDueDate = DateTime.parse(task['due']);
                                        } catch (e) {
                                          // If parsing fails, try to use parseDueString or set default
                                          taskDueDate = DateTime.now().add(const Duration(days: 1));
                                        }
                                      } else {
                                        taskDueDate = DateTime.now().add(const Duration(days: 1));
                                      }

                                      final result = await TaskNotificationService.scheduleMultipleNotifications(
                                        taskName: task['title'] ?? 'Task Reminder',
                                        taskDue: taskDueDate,
                                        taskId: task['id'].toString(),
                                        reminderMinutesList: [1440, 60, 30, 10], // 1 day, 1 hour, 30 min, 10 min
                                      );
                                      
                                      setState(() {});
                                      
                                      final scheduledCount = result['totalScheduled'] ?? 0;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$scheduledCount reminder(s) set successfully'),
                                          backgroundColor: Colors.green[700],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error setting reminders: $e'),
                                          backgroundColor: Colors.red[700],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.delete_rounded, color: Colors.red[700], size: 20),
                                onPressed: () async {
                                  await DatabaseHelper.instance.deleteTaskByID(task['id'] as int);
                                  await TaskNotificationService.cancelAllTaskNotifications(task['id'].toString());
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Task deleted'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (!isLast)
                    Divider(height: 1, indent: 72, endIndent: 20, color: Colors.grey[200]),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getSchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: const [
                  _ScheduleEntry(time: '10:00 AM', title: 'Calculus Lecture', icon: Icons.school_rounded),
                  Divider(height: 24),
                  _ScheduleEntry(time: '1:00 PM', title: 'Lunch Break', icon: Icons.restaurant_rounded),
                  Divider(height: 24),
                  _ScheduleEntry(time: '4:00 PM', title: 'Gym Session', icon: Icons.fitness_center_rounded),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final index = entry.key;
                final r = entry.value;
                final isLast = index == rows.length - 1;
                
                return Column(
                  children: [
                    _ScheduleEntry(
                      time: r['time'] ?? '',
                      title: r['title'] ?? '',
                      icon: Icons.schedule_rounded,
                    ),
                    if (!isLast) const Divider(height: 24),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickNotesCard() {
    bool showAll = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getAllNotes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final notes = snapshot.data ?? [];

            if (notes.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.note_rounded, color: Colors.grey[400], size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "No quick notes yet. Tap + → Add Note to create one.",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: UserStorage.getUser(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final user = userSnapshot.data!;
                final pinnedNoteId = user['pinnedNoteId'] as int;

                final pinnedNote = notes.firstWhere(
                  (n) => n['id'] == pinnedNoteId,
                  orElse: () => notes.first,
                );

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pinned note
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!, width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.push_pin_rounded, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  pinnedNote['content'] ?? '',
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Toggle button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              showAll = !showAll;
                            }),
                            icon: Icon(
                              showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18,
                            ),
                            label: Text(showAll ? "Show less" : "Show more"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                            ),
                          ),
                        ),

                        // List of all notes
                        if (showAll)
                          Column(
                            children: notes.map((note) {
                              final isPinned = note['id'] == pinnedNoteId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isPinned ? Colors.orange[50] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isPinned ? Colors.orange[100] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isPinned ? Icons.push_pin_rounded : Icons.note_outlined,
                                      color: isPinned ? Colors.orange[700] : Colors.grey[600],
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    note['content'] ?? '',
                                    style: TextStyle(
                                      color: isPinned ? Colors.orange[900] : Colors.black87,
                                      fontWeight: isPinned ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.push_pin_outlined,
                                            color: Colors.orange[700],
                                            size: 18,
                                          ),
                                          onPressed: () async {
                                            await UserStorage.updatePinnedNoteId(note['id'] as int);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Note ${note['id']} pinned!'),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            );
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.delete_rounded, color: Colors.red[700], size: 18),
                                          onPressed: () async {
                                            await DatabaseHelper.instance.deleteNote(note['id'] as int);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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
    );
  }

  Future<void> _showInputDialog(BuildContext context, String title) async {
    String inputText = '';
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) => inputText = value,
                    decoration: InputDecoration(
                      hintText: title.toLowerCase().contains('task')
                          ? "Enter task name"
                          : "Enter note content",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                      ),
                    ),
                    maxLines: title.toLowerCase().contains('note') ? 3 : 1,
                  ),
                  if (title.toLowerCase().contains('task')) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedDate == null
                                  ? "No date & time chosen"
                                  : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year} "
                                    "${selectedDate!.hour.toString().padLeft(2, '0')}:${selectedDate!.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate != null) {
                                TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );

                                if (pickedTime != null) {
                                  setState(() {
                                    selectedDate = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                  });
                                }
                              }
                            },
                            child: const Text("Select"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (title.toLowerCase().contains('task')) {
                      if (inputText.isNotEmpty) {
                        await DatabaseHelper.instance.addTask(inputText, selectedDate);
                      }
                    } else if (title.toLowerCase().contains('note')) {
                      if (inputText.isNotEmpty) {
                        await DatabaseHelper.instance.addNote(inputText, "Quick Note");
                      }
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ------------------ SCHEDULE ENTRY ------------------
class _ScheduleEntry extends StatelessWidget {
  final String time;
  final String title;
  final IconData icon;

  const _ScheduleEntry({required this.time, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// --- EXISTING CHAT SCREEN (Now a secondary page) ---
// ====================================================================

// --- MESSAGE BUBBLE WIDGET ---
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          )
        : null;
    final bgColor = isUser ? null : const Color(0xFFF0F4F8);
    final textColor = isUser ? Colors.white : const Color(0xFF2C3E50);

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: color,
          color: bgColor,
          borderRadius: isUser
              ? const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
          boxShadow: [
            BoxShadow(
              color: isUser ? Colors.blue.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            code: TextStyle(
              backgroundColor: isUser ? Colors.white.withOpacity(0.2) : Colors.grey[200],
              color: textColor,
            ),
          ),
          selectable: true,
        ),
      ),
    );
  }
}

// --- MAIN CHAT SCREEN ---
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! How can I help you today?', 'isUser': false},
    {'text': 'What you can do...?', 'isUser': true},
    {
      'text': 'I can help you manage tasks, notes, and schedules. I can add/delete tasks, save notes, view your schedule, and answer general questions.',
      'isUser': false
    },
  ];

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'text': text, 'isUser': true});
    });

    await DatabaseHelper.instance.insertChatMessage('user', text);
    _textController.clear();
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    setState(() {
      _messages.add({'text': '...', 'isUser': false});
    });

    final reply = await sendMessageToOpenRouter(text);
    final handledReply = await handleAIResponse(reply, text);

    await DatabaseHelper.instance.insertChatMessage('assistant', handledReply);

    setState(() {
      _messages.removeLast();
      _messages.add({'text': handledReply, 'isUser': false});
    });
    
    // Scroll to bottom again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> handleAIResponse(String reply, String userMassage) async {
    try {
      final parsed = jsonDecode(reply);
      final dbHelper = DatabaseHelper.instance;

      if (parsed["tool_call"] != null) {
        final tool = parsed["tool_call"]["name"];
        final args = parsed["tool_call"]["arguments"];

        switch (tool) {
          case "addTask":
            await dbHelper.addTask(args["title"], await parseDueString(args["due"]));
            final systemFeedback = "🤖 Added task: ${args["title"]}";
            //final response = await sendMessageToOpenRouter('Give stattus for this query : $userMassage', null, systemFeedback);
            return systemFeedback;

          case "deleteTask":
            await dbHelper.deleteTask(args["title"]);
            final systemFeedback = "🤖 Deleted task: ${args["title"]}";
           // final response = await sendMessageToOpenRouter('Give stattus for this query : $userMassage', null, systemFeedback);
            return systemFeedback;

          case "addNote":
            await dbHelper.addNote(args["content"], "Quick Note");
            final systemFeedback = "🗒️ Note added: ${args["content"]}";
           // final response = await sendMessageToOpenRouter('Give stattus for this query : $userMassage', null, systemFeedback);
            return systemFeedback;

          case "getSchedule":
            final schedule = await dbHelper.getSchedule();
            final systemFeedback = "📅 Upcoming schedule:\n$schedule";
            //final response = await sendMessageToOpenRouter('Give stattus for this query : $userMassage', null, systemFeedback);
            return systemFeedback;

          default:
            final systemFeedback = "🤖 Unknown tool: $tool";
            //final response = await sendMessageToOpenRouter('Give stattus for this query : $userMassage', null, systemFeedback);
            return systemFeedback;
        }
      } else {
        return " no tool call detected. Reply: $reply";
      }
    } catch (_) {
      return " failed handle reply,,sorry . Reply: $reply";
    }
  }

  Future<DateTime?> parseDueString(String due) async {

  due = due.toLowerCase().trim();

  final now = DateTime.now();



  DateTime? result;





  try {

    // Handle relative dates

    if (due.contains("tomorrow")) {

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (timeMatch != null) {

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day + 1, hour, minute);

      }

    } else if (due.contains("today")) {

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (timeMatch != null) {

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day, hour, minute);

      }

    }

    // Handle "in X days"

    else if (due.contains("in") && due.contains("days")) {

      final daysMatch = RegExp(r'in\s+(\d+)\s+days').firstMatch(due);

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);



      if (daysMatch != null && timeMatch != null) {

        final addDays = int.parse(daysMatch.group(1)!);

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day + addDays, hour, minute);

      }

    }

    // Handle specific dates (e.g. "12 December 2 pm")

    else {

      final dateMatch = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (dateMatch != null) {

        int day = int.parse(dateMatch.group(1)!);

        String monthName = dateMatch.group(2)!;

        int hour = int.parse(dateMatch.group(3)!);

        int minute = int.tryParse(dateMatch.group(4) ?? '0') ?? 0;

        String meridian = dateMatch.group(5)!;



        final months = {

          'january': 1, 'february': 2, 'march': 3, 'april': 4,

          'may': 5, 'june': 6, 'july': 7, 'august': 8,

          'september': 9, 'october': 10, 'november': 11, 'december': 12

        };



        int? month = months[monthName];

        if (month != null) {

          if (meridian == 'pm' && hour < 12) hour += 12;

          if (meridian == 'am' && hour == 12) hour = 0;



          result = DateTime(now.year, month, day, hour, minute);

          if (result.isBefore(now)) {

            // If the date already passed this year, assume next year

            result = DateTime(now.year + 1, month, day, hour, minute);

          }

        }

      }

    }



    if (result != null && result.isBefore(now)) {

      // Always ensure it's a future date

      result = result.add(const Duration(days: 1));

    }



    return result;

  } catch (e) {

    print("Error parsing due string: $e");

    return now.add(const Duration(days: 1)); // default fallback

  }

} 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'HyLing',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.mic_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EchoBot(),
                  ),
                );
              },
              tooltip: 'Voice Input',
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  text: message['text'] as String,
                  isUser: message['isUser'] as bool,
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: _InputWidget(
                textController: _textController,
                onSubmitted: _handleSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- INPUT WIDGET ---
class _InputWidget extends StatelessWidget {
  final TextEditingController textController;
  final Function(String) onSubmitted;

  const _InputWidget({required this.textController, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: textController,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                ),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: () => onSubmitted(textController.text),
            color: Colors.white,
            iconSize: 22,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}