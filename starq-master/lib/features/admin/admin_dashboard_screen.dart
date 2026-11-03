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
      context.read<AdminProvider>().fetchApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(text: 'Applications'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingsView(),
            _PartnersView(),
            _ApplicationsView(),
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

class _ApplicationsView extends StatelessWidget {
  const _ApplicationsView({Key? key}) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'SUSPENDED':
        return Colors.grey;
      case 'PENDING_VERIFICATION':
      default:
        return Colors.amber.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.error != null) return Center(child: Text(provider.error!));
    if (provider.applications.isEmpty) return const Center(child: Text('No partner applications'));

    return RefreshIndicator(
      onRefresh: () => provider.fetchApplications(),
      child: ListView.builder(
        itemCount: provider.applications.length,
        itemBuilder: (context, index) {
          final app = provider.applications[index];
          final status = (app['status'] ?? 'PENDING_VERIFICATION').toString();
          final user = app['user'] ?? {};

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      app['fullName'] ?? user['fullName'] ?? 'Unknown Applicant',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'ID: #${app['applicationId'] ?? ''} · ${app['city'] ?? ''}\nDoc: ${app['idDocumentType'] ?? ''} · Phone: ${app['phone'] ?? user['phone'] ?? ''}',
                  style: const TextStyle(height: 1.3, fontSize: 13),
                ),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) async {
                  if (val == 'approve') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Approve Partner'),
                        content: Text('Approve ${app['fullName']} as an active STARQ Service Partner?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Approve', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await provider.approveApplication(app['id']);
                    }
                  } else if (val == 'reject') {
                    final reasonController = TextEditingController();
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reject Application'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Please enter a mandatory rejection reason for the applicant:'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: reasonController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Unreadable ID proof, blurry photo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              if (reasonController.text.trim().isNotEmpty) {
                                Navigator.pop(ctx, reasonController.text.trim());
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Reject', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (reason != null && reason.isNotEmpty) {
                      await provider.rejectApplication(app['id'], reason);
                    }
                  } else if (val == 'suspend') {
                    await provider.suspendApplication(app['id']);
                  } else if (val == 'details') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(app['fullName'] ?? 'Applicant Details'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Application ID: ${app['applicationId'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text('Email: ${app['email'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text('Phone: ${app['phone'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text('Address: ${app['address'] ?? ''}, ${app['city'] ?? ''} - ${app['pinCode'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text('ID Proof Type: ${app['idDocumentType'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text('Status: $status'),
                              if (app['rejectionReason'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Rejection Reason: ${app['rejectionReason']}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'details', child: Text('View Details')),
                  if (status != 'APPROVED')
                    const PopupMenuItem(value: 'approve', child: Text('Approve Partner', style: TextStyle(color: Colors.green))),
                  if (status != 'REJECTED')
                    const PopupMenuItem(value: 'reject', child: Text('Reject Application', style: TextStyle(color: Colors.red))),
                  if (status == 'APPROVED')
                    const PopupMenuItem(value: 'suspend', child: Text('Suspend Partner', style: TextStyle(color: Colors.orange))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
