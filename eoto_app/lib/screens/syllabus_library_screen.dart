import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';

class SyllabusLibraryScreen extends StatefulWidget {
  const SyllabusLibraryScreen({Key? key}) : super(key: key);

  @override
  State<SyllabusLibraryScreen> createState() => _SyllabusLibraryScreenState();
}

class _SyllabusLibraryScreenState extends State<SyllabusLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationController>(
      builder: (context, controller, child) {
        final allBooks = controller.syllabusBooks.where((b) {
          final cat = (b['cat'] ?? '').toString().toLowerCase();
          final title = (b['title'] ?? '').toString().toLowerCase();
          return !cat.contains('assessment') && !title.contains('baseline') && !title.contains('midterm');
        }).toList();

        final q = _searchQuery.trim().toLowerCase();
        final books = allBooks.where((b) {
          if (q.isEmpty) return true;
          final title = (b['title'] ?? '').toString().toLowerCase();
          final cat = (b['cat'] ?? '').toString().toLowerCase();
          final size = (b['size'] ?? '').toString().toLowerCase();
          return title.contains(q) || cat.contains(q) || size.contains(q);
        }).toList();

        if (allBooks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLime.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: AppTheme.textBlack,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Books Published Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Standard textbooks, syllabus guides, and vocational manuals uploaded by Super Admin will appear here. Assessment sheets are managed in their respective evaluation stages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Search Bar for Books
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search textbooks, syllabi, manuals...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            if (books.isEmpty && _searchQuery.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No books found matching "$_searchQuery"',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
            final book = books[index];
            final bool downloaded = book['downloaded'] ?? false;
            final bool isDownloading = book['isDownloading'] ?? false;
            final double progress = book['progress'] ?? 0.0;
            final int originalIndex = controller.syllabusBooks.indexWhere((b) => b['id'] == book['id']);

            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 64,
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLime.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: AppTheme.primaryLime.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.book_rounded,
                      color: AppTheme.textBlack,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textBlack,
                              ),
                        ),
                        const SizedBox(height: 6.0),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Size: ${book['size']}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: AppTheme.textGrey,
                                  ),
                            ),
                            if (book['cat'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  book['cat'].toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (isDownloading) ...[
                          const SizedBox(height: 8.0),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              backgroundColor: AppTheme.inputFill,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryLime,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  _buildDownloadButton(
                    context,
                    book,
                    downloaded,
                    isDownloading,
                    () => _triggerDirectDownload(context, book, controller, originalIndex != -1 ? originalIndex : index),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
      },
    );
  }

  void _triggerDirectDownload(
    BuildContext context,
    Map<String, dynamic> book,
    RegistrationController controller,
    int index,
  ) async {
    final String url = (book['downloadUrl'] ?? '').toString().trim();
    final String title = (book['title'] ?? 'Textbook').toString().trim();

    if (url.isEmpty) {
      AppTheme.showErrorSnackBar(context, 'Document file is not available for download.');
      return;
    }

    AppTheme.showInfoSnackBar(
      context,
      'Downloading "$title" directly to your device...',
      isLoading: true,
    );

    final success = await controller.downloadBook(index);

    if (context.mounted) {
      AppTheme.showSuccessSnackBar(
        context,
        success 
          ? '"$title" saved directly to your device downloads!'
          : 'Download triggered in device browser downloads.',
      );
    }
  }

  Widget _buildDownloadButton(
    BuildContext context,
    Map<String, dynamic> book,
    bool downloaded,
    bool isDownloading,
    VoidCallback onTap,
  ) {
    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.all(8),
        width: 38,
        height: 38,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textBlack),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: downloaded ? const Color(0xFFE8F5E9) : AppTheme.primaryLime,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: downloaded ? Colors.green.withOpacity(0.4) : Colors.black12,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              downloaded ? Icons.check_circle_rounded : Icons.file_download_outlined,
              color: downloaded ? Colors.green[800] : Colors.black,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              downloaded ? 'DOWNLOAD' : 'DOWNLOAD',
              style: TextStyle(
                color: downloaded ? Colors.green[900] : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
