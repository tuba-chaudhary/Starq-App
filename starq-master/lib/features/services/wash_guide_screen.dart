import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/core/widgets/bottom_nav_bar.dart';
import 'package:starq_app/app/theme/app_theme.dart';

class WashGuideScreen extends StatefulWidget {
  const WashGuideScreen({super.key});

  @override
  State<WashGuideScreen> createState() => _WashGuideScreenState();
}

class _WashGuideScreenState extends State<WashGuideScreen> {
  int _selectedFilter = 0;

  static const _filters = ['All Videos', 'Exterior', 'Interior', 'Full Detailing', 'Premium'];

  static const _videos = [
    _VideoGuide(
      image: 'exterior_wash.png',
      title: 'Exterior Wash',
      description: 'See our step-by-step exterior wash process.',
      category: 'Exterior',
    ),
    _VideoGuide(
      image: 'interior_cleaning.png',
      title: 'Interior Cleaning',
      description: 'Deep clean your car interior for a fresh and hygienic ride.',
      category: 'Interior',
    ),
    _VideoGuide(
      image: 'full_detailing.png',
      title: 'Full Detailing',
      description: 'Complete detailing process for a showroom shine.',
      category: 'Full Detailing',
    ),
    _VideoGuide(
      image: 'premium_wash.png',
      title: 'Premium Wash',
      description: 'Our premium wash for the ultimate clean and protection.',
      category: 'Premium',
    ),
  ];

  List<_VideoGuide> get _filteredVideos {
    if (_selectedFilter == 0) return _videos; // "All Videos"
    final selectedCategory = _filters[_selectedFilter];
    return _videos.where((v) => v.category == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back_ios_new,
                          size: 16, color: AppColors.textDark),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const Spacer(),
                  const StarqLogo(fontSize: 20),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero section — Row layout, no overlap between text and image
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.heading.copyWith(fontSize: 24),
                                    children: [
                                      TextSpan(
                                          text: 'Wash ',
                                          style: TextStyle(color: AppColors.primary)),
                                      TextSpan(
                                          text: 'Guide',
                                          style: TextStyle(color: AppColors.textDark)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Watch how we clean, care for and transform your car.',
                                  style: AppTextStyles.body.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Image.asset(
                              'assets/images/videos.png',
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.local_car_wash,
                                    color: AppColors.primary, size: 40),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filter chips
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = i == _selectedFilter;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = i),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.white,
                                border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _filters[i],
                                style: AppTextStyles.body.copyWith(
                                  color: selected ? Colors.white : AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Video list — shows only the filtered videos
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: _filteredVideos.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text('No videos in this category yet',
                                        style: AppTextStyles.body),
                                  ),
                                ),
                              ]
                            : _filteredVideos
                                .map((v) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _VideoCard(video: v),
                                    ))
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(
        currentIndex: 3,
        items: [
          NavItem(icon: Icons.water_drop, label: 'home', route: '/home'),
          NavItem(icon: Icons.directions_car, label: 'bookings', route: '/bookings'),
          NavItem(icon: Icons.star_border, label: 'rewards', route: '/rewards'),
          NavItem(icon: Icons.play_arrow, label: 'wash guide', route: '/wash-guide'),
        ],
      ),
    );
  }
}

class _VideoGuide {
  final String image;
  final String title;
  final String description;
  final String category;

  const _VideoGuide({
    required this.image,
    required this.title,
    required this.description,
    required this.category,
  });
}

class _VideoCard extends StatelessWidget {
  final _VideoGuide video;
  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(video.title, style: AppTextStyles.subheading),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ctx.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(video.description, style: AppTextStyles.body),
                const SizedBox(height: 16),
                const Text('Care Steps & Pro Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Text('1. Pre-rinse exterior thoroughly to loosen dust and grit.', style: AppTextStyles.body),
                Text('2. Use two-bucket wash technique with microfiber wash mitt.', style: AppTextStyles.body),
                Text('3. Rinse top-to-bottom using controlled pressure washer stream.', style: AppTextStyles.body),
                Text('4. Pat dry with plush microfiber drying towel to avoid swirls.', style: AppTextStyles.body),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ctx.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/${video.image}',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.play_circle_outline, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(video.description, style: AppTextStyles.body),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}