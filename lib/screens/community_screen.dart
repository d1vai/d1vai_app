import 'package:flutter/material.dart';
import 'package:easy_refresh/easy_refresh.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late EasyRefreshController _controller;
  int _count = 10;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: EasyRefresh(
        controller: _controller,
        header: const ClassicHeader(),
        footer: const ClassicFooter(),
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          setState(() {
            _count = 10;
          });
          _controller.finishRefresh();
        },
        onLoad: () async {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          setState(() {
            _count += 5;
          });
          _controller.finishLoad(_count >= 20 ? IndicatorResult.noMore : IndicatorResult.success);
        },
        child: ListView.builder(
          itemCount: _count,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Text('U${index + 1}', style: const TextStyle(color: Colors.deepPurple)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('2 hours ago', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.more_horiz, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Community Post Title ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'This is a simulated community post content. It demonstrates how a longer text would look like in this card layout.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.favorite_border, size: 20, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('12', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 16),
                        const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('4', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
