import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/features/providers/admin_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchBookings();
      context.read<AdminProvider>().fetchPartners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StarqLogo(height: 24),
              const SizedBox(width: 8),
              Text('Ops', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<AuthProvider>().logout();
                context.go('/login');
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bookings'),
              Tab(text: 'Partners'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingsView(),
            _PartnersView(),
          ],
        ),
      ),
    );
  }
}

class _BookingsView extends StatelessWidget {
  const _BookingsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.error != null) return Center(child: Text(provider.error!));
    if (provider.bookings.isEmpty) return const Center(child: Text('No bookings'));

    return ListView.builder(
      itemCount: provider.bookings.length,
      itemBuilder: (context, index) {
        final b = provider.bookings[index];
        return ListTile(
          title: Text('Booking #${b.id.substring(0,8)} - ${b.status.name}'),
          subtitle: Text('Customer: ${b.address?.addressLine ?? ''}\nAmount: ${b.finalTotalAmount}'),
          trailing: PopupMenuButton(
            itemBuilder: (ctx) => [
              if (['CONFIRMED', 'ASSIGNMENT_PENDING'].contains(b.status.name.toUpperCase()))
                const PopupMenuItem(value: 'assign', child: Text('Assign Partner')),
              const PopupMenuItem(value: 'cancel', child: Text('Cancel Booking')),
            ],
            onSelected: (val) async {
              if (val == 'cancel') {
                await provider.cancelBooking(b.id);
              } else if (val == 'assign') {
                if (provider.partners.isEmpty) return;
                final partnerId = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Select Partner'),
                    children: provider.partners.map((p) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, p['id']),
                      child: Text('${p['user']['fullName']} (${p['status']})'),
                    )).toList(),
                  )
                );
                if (partnerId != null) {
                  await provider.assignPartner(b.id, partnerId);
                }
              }
            },
          ),
        );
      },
    );
  }
}

class _PartnersView extends StatelessWidget {
  const _PartnersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.error != null) return Center(child: Text(provider.error!));
    if (provider.partners.isEmpty) return const Center(child: Text('No partners'));

    return ListView.builder(
      itemCount: provider.partners.length,
      itemBuilder: (context, index) {
        final p = provider.partners[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(p['user']['fullName'] ?? 'Unknown'),
          subtitle: Text('Status: ${p['status']}'),
        );
      },
    );
  }
}
