import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/adaptativo.dart';
import 'home_screen.dart';

// Mesmos usuarios de demonstracao mostrados no login da Web (criados pelo DbInitializer).
// Para esconder numa versao de producao: flutter build ... --dart-define=ESCONDER_DEMO=true
const _esconderDemo = bool.fromEnvironment('ESCONDER_DEMO');
const _acessosDemo = [
  ('Diretoria', 'estrategico@modamax.com'),
  ('Gerência', 'tatico@modamax.com'),
  ('Vendas', 'operacional@modamax.com'),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await ApiService.instancia.login(_email.text.trim(), _senha.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ios = ehIOS(context);

    final conteudo = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      icone(context, material: Icons.checkroom, ios: CupertinoIcons.tag_fill),
                      size: 64,
                      color: corDestaque(context),
                      semanticLabel: 'Logo ModaMax',
                    ),
                    const SizedBox(height: 12),
                    Text('ModaMax', textAlign: TextAlign.center, style: estiloTituloGrande(context).copyWith(fontSize: 32)),
                    Text('Gestão comercial na palma da mão', textAlign: TextAlign.center, style: estiloSecundario(context)),
                    const SizedBox(height: 24),
                    SecaoFormulario(children: [
                      CampoTexto(
                        controle: _email,
                        rotulo: 'E-mail',
                        dica: 'nome@modamax.com',
                        teclado: TextInputType.emailAddress,
                        acaoTeclado: TextInputAction.next,
                        preenchimento: const [AutofillHints.email],
                        validar: (v) => v.contains('@') ? null : 'Informe um e-mail válido.',
                      ),
                      CampoTexto(
                        controle: _senha,
                        rotulo: 'Senha',
                        oculto: !_mostrarSenha,
                        preenchimento: const [AutofillHints.password],
                        aoConfirmar: (_) => _entrar(),
                        validar: (v) => v.isEmpty ? 'Informe a senha.' : null,
                        sufixo: ios
                            ? CupertinoButton(
                                padding: const EdgeInsets.only(right: 4),
                                minimumSize: const Size(32, 32),
                                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                                child: Icon(_mostrarSenha ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20),
                              )
                            : IconButton(
                                tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                                icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                              ),
                      ),
                    ]),
                    if (_erro != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_erro!, textAlign: TextAlign.center, style: TextStyle(color: corVermelha(context))),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Botao.principal('Entrar', carregando: _carregando, aoTocar: _entrar),
                    ),
                    if (!_esconderDemo) ...[
                      const SizedBox(height: 28),
                      Text('Acessos de demonstração (senha 123456)',
                          textAlign: TextAlign.center, style: estiloLegenda(context)),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (nome, email) in _acessosDemo)
                            ios
                                ? CupertinoButton.tinted(
                                    sizeStyle: CupertinoButtonSize.small,
                                    onPressed: () => _preencher(email),
                                    child: Text(nome),
                                  )
                                : ActionChip(label: Text(nome), tooltip: 'Preencher com $email', onPressed: () => _preencher(email)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (ios) {
      return CupertinoPageScaffold(
        backgroundColor: fundoAgrupado(context),
        child: Material(type: MaterialType.transparency, child: conteudo),
      );
    }
    return Scaffold(body: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: conteudo));
  }

  void _preencher(String email) => setState(() {
        _email.text = email;
        _senha.text = '123456';
        _erro = null;
      });
}
