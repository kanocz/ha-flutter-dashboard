import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/home_assistant_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/launcher_bloc.dart';
import 'package:ha_flutter_dashboard/screens/dashboard_screen.dart';
import 'package:ha_flutter_dashboard/screens/setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Check for launcher mode
    context.read<LauncherBloc>().add(CheckLauncherMode());
    
    // Navigate to the appropriate screen after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() {
    final haState = context.read<HomeAssistantBloc>().state;
    
    if (haState is HomeAssistantLoaded && 
        haState.selectedInstanceId != null && 
        haState.isAuthenticated) {
      // User is already set up, go to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // User needs to set up the app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.home,
                  size: 150,
                  color: Colors.blue,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Home Assistant Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
