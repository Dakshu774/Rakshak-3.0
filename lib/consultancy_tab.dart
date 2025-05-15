import 'package:flutter/material.dart';
import '../theme.dart';

class ConsultancyTab extends StatelessWidget {
  const ConsultancyTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          title: 'Emergency Services',
          items: [
            _buildServiceItem(
              title: 'Police',
              subtitle: 'Emergency: 911',
              icon: Icons.local_police,
              onTap: () => _showContactDialog(context, 'Police', '911'),
            ),
            _buildServiceItem(
              title: 'Ambulance',
              subtitle: 'Emergency: 911',
              icon: Icons.medical_services,
              onTap: () => _showContactDialog(context, 'Ambulance', '911'),
            ),
            _buildServiceItem(
              title: 'Fire Department',
              subtitle: 'Emergency: 911',
              icon: Icons.fire_truck,
              onTap: () => _showContactDialog(context, 'Fire Department', '911'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: 'Support Services',
          items: [
            _buildServiceItem(
              title: 'Crisis Hotline',
              subtitle: '24/7 Support',
              icon: Icons.phone_in_talk,
              onTap: () => _showContactDialog(context, 'Crisis Hotline', '1-800-273-8255'),
            ),
            _buildServiceItem(
              title: 'Domestic Violence',
              subtitle: '24/7 Support',
              icon: Icons.shield,
              onTap: () => _showContactDialog(context, 'Domestic Violence Hotline', '1-800-799-7233'),
            ),
            _buildServiceItem(
              title: 'Suicide Prevention',
              subtitle: '24/7 Support',
              icon: Icons.health_and_safety,
              onTap: () => _showContactDialog(context, 'Suicide Prevention Lifeline', '1-800-273-8255'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildServiceItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title, style: AppTheme.bodyLarge),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showContactDialog(BuildContext context, String service, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Emergency Number: $number'),
            const SizedBox(height: 16),
            const Text(
              'Would you like to call this number?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement phone call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $service...')),
              );
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }
}
