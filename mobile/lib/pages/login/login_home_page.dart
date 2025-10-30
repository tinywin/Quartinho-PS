import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/pages/login/login.dart';
//import 'package:mobile/core/app_routes.dart';
import 'package:mobile/pages/login/widgets/button_login_email.dart';
import 'package:mobile/pages/login/widgets/buttom_gmail.dart';
import 'package:mobile/pages/login/widgets/login_image_home.dart';
import 'package:mobile/pages/login/widgets/buttom_facebook.dart';
import 'package:mobile/pages/signup/signup_page.dart'; //  importa sua tela de cadastro
import 'package:mobile/core/services/auth_service.dart';
import 'package:mobile/pages/choose_role/choose_role_page.dart';
import 'package:mobile/pages/inicial/inicial_page.dart';

class LoginHomePage extends StatelessWidget {
  const LoginHomePage({super.key});
  final String _img = 'assets/images/login_home.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(),
            child: Column(
              children: [
              Padding(
                padding: EdgeInsets.only(top: 150, bottom: 26),
                child: LoginImageHome(img: _img,),
              ),

              // Título
              Container(
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.only(left: 30),
                child: Text(
                  'Procurando\num Quartinho?',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Botão email
              SizedBox(height: 24),
              ButtonLoginEmail(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Login()),
                  );
                },
              ),
              // Divisão Rodapé
              SizedBox(height: 40),
              Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                  Text(
                    ' ou ',
                    style: GoogleFonts.roboto(
                      color: Color(0xFFA1A5C1),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                ],
              ),

              // Gmail e Facebook
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(child: ButtomGmail(onPressed: () async {
                    try {
                      final result = await AuthService.loginWithGoogleMobile();
                      if (result != null && result['token'] != null) {
                        final user = result['user'] as Map<String, dynamic>?;
                        final name = user != null ? (user['username'] ?? user['full_name'] ?? '') : '';
                        final email = user != null ? (user['email'] ?? '') : '';
                        if (context.mounted) {
                          final done = email.isNotEmpty ? await AuthService.isOnboardingCompleted(email) : false;
                          if (done) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InicialPage(
                                  name: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Usuário'),
                                  city: '',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChooseRolePage(
                                  name: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Usuário'),
                                  email: email,
                                ),
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha no login Google')));
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      }
                    }
                  })),
                  SizedBox(width: 20),
                  Container(child: ButtomFacebook(onPressed: () async {
                    try {
                      final result = await AuthService.loginWithFacebookMobile();
                      if (result != null && result['token'] != null) {
                        final user = result['user'] as Map<String, dynamic>?;
                        final name = user != null ? (user['username'] ?? user['full_name'] ?? '') : '';
                        final email = user != null ? (user['email'] ?? '') : '';
                        if (context.mounted) {
                          final done = email.isNotEmpty ? await AuthService.isOnboardingCompleted(email) : false;
                          if (done) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InicialPage(
                                  name: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Usuário'),
                                  city: '',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChooseRolePage(
                                  name: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Usuário'),
                                  email: email,
                                ),
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha no login Facebook')));
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                      }
                    }
                  })),
                ],
              ),

              // Cadastre-se
            
              //Cadastre-se
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Não têm uma conta?',
                    style: GoogleFonts.roboto(
                      color: Color(0xFF404040),
                    ),
                  ),
                 
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Cadastre-se',
                      style: GoogleFonts.roboto(
                        color: Color(0xFF404040),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}