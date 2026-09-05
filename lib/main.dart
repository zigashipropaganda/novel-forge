import 'package:flutter/material.dart';

void main() {
  runApp(const NovelForgeApp());
}

class NovelForgeApp extends StatelessWidget {
  const NovelForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'novel-forge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BinderScreen(),
    );
  }
}

class BinderScreen extends StatefulWidget {
  const BinderScreen({super.key});

  @override
  State<BinderScreen> createState() => _BinderScreenState();
}

class _BinderScreenState extends State<BinderScreen> {
  final List<String> _documents = [];

  void _addDocument() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Document title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _documents.add(controller.text.trim());
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('novel-forge'),
      ),
      body: _documents.isEmpty
          ? const Center(
              child: Text(
                'No documents yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_documents[index]),
                  onTap: () {
                    // Editor screen comes next
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        child: const Icon(Icons.add),
      ),
    );
  }
}
