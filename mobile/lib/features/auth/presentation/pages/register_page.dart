import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_checkbox.dart';
import '../../providers/auth_provider.dart';
import 'preparing_experience_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _doRegister() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa aceitar os termos de uso.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final success = await ref.read(authProvider.notifier).register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            city: _cityController.text.trim(),
          );
      
      if (success && mounted) {
        // Redirecionar para a tela animada de carregamento (Onboarding)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PreparingExperiencePage()),
        );
      } else if (mounted) {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Erro desconhecido'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.all(12),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/ecopulse_logo.png', height: 32),
                      const SizedBox(width: 8),
                      const Text(
                        'EcoPulse',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Títulos
                const Text(
                  'Criar conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Participe do EcoPulse e ajude a construir cidades mais resilientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Inputs
                AuthTextField(
                  label: 'Nome completo',
                  hint: 'João Silva',
                  prefixIcon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Informe seu nome completo.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'E-mail',
                  hint: 'joao@email.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Informe seu e-mail.';
                    if (!val.contains('@')) return 'Digite um e-mail válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Senha',
                  hint: 'Mínimo de 8 caracteres',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  controller: _passwordController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Informe sua senha.';
                    if (val.length < 8) return 'A senha deve possuir pelo menos 8 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Confirmar senha',
                  hint: 'Repita a senha',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  controller: _confirmPasswordController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Confirme sua senha.';
                    if (val != _passwordController.text) return 'As senhas não coincidem.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Cidade',
                  hint: 'Sua cidade',
                  prefixIcon: Icons.location_on_outlined,
                  controller: _cityController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Informe sua cidade.';
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Termos
                AuthCheckbox(
                  value: _acceptedTerms,
                  onChanged: (val) {
                    setState(() => _acceptedTerms = val ?? false);
                  },
                  label: GestureDetector(
                    onTap: () {
                      setState(() => _acceptedTerms = !_acceptedTerms);
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: 'Li e aceito os ',
                        style: TextStyle(color: AppTheme.textSecondary),
                        children: [
                          TextSpan(
                            text: 'termos de uso',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botão Cadastrar
                AuthPrimaryButton(
                  text: 'Cadastrar',
                  isLoading: isLoading,
                  onPressed: _doRegister,
                ),
                
                const SizedBox(height: 24),
                
                // Link para Login
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text(
                      'Já tenho conta',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
