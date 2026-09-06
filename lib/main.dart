import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NovelForgeApp());
}

const _accent = Color(0xFF4E7FFF);
const _bg = Color(0xFFF6F6F6);
const _storageKey = 'binder_data_v1';

class NovelForgeApp extends StatelessWidget {
  const NovelForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'novel-forge',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.light),
      ),
      home: const BinderScreen(),
    );
  }
}

// ---------- Data models ----------

class BinderDocument {
  String title;
  String content;
  BinderDocument({required this.title, this.content = ''});

  Map<String, dynamic> toJson() => {'title': title, 'content': content};
  factory BinderDocument.fromJson(Map<String, dynamic> j) =>
      BinderDocument(title: j['title'], content: j['content'] ?? '');
}

class BinderFolder {
  String name;
  List<BinderDocument> documents;
  BinderFolder({required this.name, List<BinderDocument>? documents}) : documents = documents ?? [];

  Map<String, dynamic> toJson() =>
      {'name': name, 'documents': documents.map((d) => d.toJson()).toList()};
  factory BinderFolder.fromJson(Map<String, dynamic> j) => BinderFolder(
        name: j['name'],
        documents: (j['documents'] as List).map((d) => BinderDocument.fromJson(d)).toList(),
      );
}

// ---------- Persistence ----------

class Storage {
  static Future<List<BinderFolder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => BinderFolder.fromJson(e)).toList();
  }

  static Future<void> save(List<BinderFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(folders.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}

// ---------- Helpers ----------

int _wordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

int _readingMinutes(int words) => (words / 200).ceil().clamp(0, 999);

Future<String?> _showNameSheet(BuildContext context, String title, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Name',
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _showDeleteConfirm(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete?'),
      content: Text('Delete "$name"? This can\'t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _showItemOptions(BuildContext context, {required VoidCallback onRename, required VoidCallback onDelete}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _accent),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _roundedCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: child,
  );
}

// ---------- Top-level binder screen (folders) ----------

class BinderScreen extends StatefulWidget {
  const BinderScreen({super.key});

  @override
  State<BinderScreen> createState() => _BinderScreenState();
}

class _BinderScreenState extends State<BinderScreen> {
  List<BinderFolder> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await Storage.load();
    setState(() {
      _folders = loaded;
      _loading = false;
    });
  }

  void _persist() => Storage.save(_folders);

  Future<void> _addFolder() async {
    final name = await _showNameSheet(context, 'New Folder');
    if (name != null && name.isNotEmpty) {
      setState(() => _folders.add(BinderFolder(name: name)));
      _persist();
    }
  }

  Future<void> _renameFolder(BinderFolder folder) async {
    final name = await _showNameSheet(context, 'Rename Folder', initial: folder.name);
    if (name != null && name.isNotEmpty) {
      setState(() => folder.name = name);
      _persist();
    }
  }

  Future<void> _deleteFolder(BinderFolder folder) async {
    final confirmed = await _showDeleteConfirm(context, folder.name);
    if (confirmed) {
      setState(() => _folders.remove(folder));
      _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('novel-forge', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: _bg,
            surfaceTintColor: Colors.transparent,
          ),
          if (_folders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No folders yet.\nTap + below to create one.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final folder = _folders[index];
                    return _roundedCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.folder_outlined, color: _accent),
                        ),
                        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${folder.documents.length} document${folder.documents.length == 1 ? '' : 's'}'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FolderScreen(folder: folder, onChanged: _persist)),
                          );
                          setState(() {});
                        },
                        onLongPress: () => _showItemOptions(
                          context,
                          onRename: () => _renameFolder(folder),
                          onDelete: () => _deleteFolder(folder),
                        ),
                      ),
                    );
                  },
                  childCount: _folders.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 4),
        child: FloatingActionButton(
          onPressed: _addFolder,
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------- Folder contents screen (documents) ----------

class FolderScreen extends StatefulWidget {
  final BinderFolder folder;
  final VoidCallback onChanged;
  const FolderScreen({super.key, required this.folder, required this.onChanged});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  Future<void> _addDocument() async {
    final name = await _showNameSheet(context, 'New Document');
    if (name != null && name.isNotEmpty) {
      setState(() => widget.folder.documents.add(BinderDocument(title: name)));
      widget.onChanged();
    }
  }

  Future<void> _renameDocument(BinderDocument doc) async {
    final name = await _showNameSheet(context, 'Rename Document', initial: doc.title);
    if (name != null && name.isNotEmpty) {
      setState(() => doc.title = name);
      widget.onChanged();
    }
  }

  Future<void> _deleteDocument(BinderDocument doc) async {
    final confirmed = await _showDeleteConfirm(context, doc.title);
    if (confirmed) {
      setState(() => widget.folder.documents.remove(doc));
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.folder.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: _bg,
            surfaceTintColor: Colors.transparent,
          ),
          if (widget.folder.documents.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No documents yet.\nTap + below to create one.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = widget.folder.documents[index];
                    final words = _wordCount(doc.content);
                    final minutes = _readingMinutes(words);
                    return _roundedCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.description_outlined, color: _accent),
                        ),
                        title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$words words \u00b7 $minutes min read'),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditorScreen(document: doc, onChanged: widget.onChanged)),
                          );
                          setState(() {});
                        },
                        onLongPress: () => _showItemOptions(
                          context,
                          onRename: () => _renameDocument(doc),
                          onDelete: () => _deleteDocument(doc),
                        ),
                      ),
                    );
                  },
                  childCount: widget.folder.documents.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 4),
        child: FloatingActionButton(
          onPressed: _addDocument,
          backgroundColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------- Editor screen ----------

class EditorScreen extends StatefulWidget {
  final BinderDocument document;
  final VoidCallback onChanged;
  const EditorScreen({super.key, required this.document, required this.onChanged});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.document.content);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    widget.document.content = _controller.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), widget.onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.onChanged();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.document.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontSize: 16, height: 1.5),
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Start writing...'),
        ),
      ),
    );
  }
}
