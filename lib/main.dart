import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buscador Poqomchi\'',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, String>> _resultados = [];
  bool _buscando = false;

  Future<void> _buscar() async {
    final palabraOriginal =
        _searchController.text.trim();

    if (palabraOriginal.isEmpty) {
      return;
    }

    final palabra =
        palabraOriginal.replaceAll("'", "ʼ");

    setState(() {
      _buscando = true;
      _resultados = [];
    });

    final url = Uri.parse(
      '${Uri.base.origin}/.netlify/functions/wol-proxy'
      '?q=${Uri.encodeComponent(palabra)}',
    );

    try {
      final respuesta = await http.get(url);

      if (respuesta.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          _buscando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WOL respondió con el código '
              '${respuesta.statusCode}.',
            ),
          ),
        );

        return;
      }

      final datos =
          jsonDecode(respuesta.body)
              as Map<String, dynamic>;

      final htmlPoqomchi =
          datos['htmlPoqomchi'] as String? ?? '';

      final htmlEspanol =
          datos['htmlEspanol'] as String? ?? '';

      final resultadosPoqomchi =
          _extraerResultados(
        htmlPoqomchi,
      );

      final resultadosEspanol =
          _extraerResultados(
        htmlEspanol,
      );

      final nuevosResultados =
          <Map<String, String>>[];

      for (int i = 0;
          i < resultadosPoqomchi.length;
          i++) {
        final resultadoPoqomchi =
            resultadosPoqomchi[i];

        Map<String, String>? resultadoEspanol;

        if (i < resultadosEspanol.length) {
          resultadoEspanol =
              resultadosEspanol[i];
        }

        nuevosResultados.add({
          'titulo':
              resultadoPoqomchi['titulo'] ?? '',
          'cantidad':
              resultadoPoqomchi['cantidad'] ?? '',
          'fragmento':
              resultadoPoqomchi['fragmento'] ?? '',
          'fragmentoEspanol':
              resultadoEspanol?['fragmento'] ?? '',
          'enlace':
              resultadoPoqomchi['enlace'] ?? '',
        });
      }

      if (!mounted) return;

      setState(() {
        _resultados = nuevosResultados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _buscando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error de conexión: $e',
          ),
        ),
      );
    }
  }

  List<Map<String, String>> _extraerResultados(
    String html,
  ) {
    if (html.isEmpty) {
      return [];
    }

    final documento =
        html_parser.parse(html);

    final enlaces =
        documento.querySelectorAll('a');

    final resultados =
        enlaces.where((enlace) {
      final href =
          enlace.attributes['href'] ?? '';

      return href.contains('/wol/d/');
    }).toList();

    final encontrados =
        <Map<String, String>>[];

    final enlacesProcesados =
        <String>{};

    for (final resultado in resultados) {
      final href =
          resultado.attributes['href'] ?? '';

      if (href.isEmpty) {
        continue;
      }

      if (!enlacesProcesados.add(href)) {
        continue;
      }

      final bloqueResultado =
          resultado.parent?.parent;

      if (bloqueResultado == null) {
        continue;
      }

      final titulo =
          resultado.text.trim();

      final cantidad =
          bloqueResultado
                  .querySelector('.count')
                  ?.text
                  .trim() ??
              '';

      final parrafos =
          bloqueResultado.querySelectorAll(
        'li.searchResult p',
      );

      final fragmento = parrafos
          .map(
            (p) => p.text.trim(),
          )
          .where(
            (texto) => texto.isNotEmpty,
          )
          .join('\n\n');

      if (fragmento.isEmpty) {
        continue;
      }

      encontrados.add({
        'titulo': titulo,
        'cantidad': cantidad,
        'fragmento': fragmento,
        'enlace': href,
      });
    }

    return encontrados;
  }

  List<TextSpan> _resaltarPalabra(
    String texto,
    String palabra,
  ) {
    if (palabra.isEmpty) {
      return [
        TextSpan(text: texto),
      ];
    }

    final palabraWol =
        palabra.replaceAll("'", "ʼ");

    final textoNormalizado =
        texto.replaceAll("'", "ʼ");

    final partes =
        textoNormalizado.split(palabraWol);

    final resultado =
        <TextSpan>[];

    for (int i = 0;
        i < partes.length;
        i++) {
      if (partes[i].isNotEmpty) {
        resultado.add(
          TextSpan(
            text: partes[i],
          ),
        );
      }

      if (i < partes.length - 1) {
        resultado.add(
          TextSpan(
            text: palabraWol,
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return resultado;
  }

  Future<void> _abrirArticulo(
    String enlace,
  ) async {
    if (enlace.isEmpty) {
      return;
    }

    final url = Uri.parse(
      enlace.startsWith('http')
          ? enlace
          : 'https://wol.jw.org$enlace',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget _tituloIdioma(
    String texto,
    IconData icono,
  ) {
    return Row(
      children: [
        Icon(
          icono,
          size: 20,
          color: Colors.indigo,
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _panelIdioma({
    required String idioma,
    required String texto,
    required IconData icono,
    required bool resaltar,
  }) {
    final contenido = resaltar
        ? RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.55,
              ),
              children: _resaltarPalabra(
                texto,
                _searchController.text.trim(),
              ),
            ),
          )
        : Text(
            texto.isEmpty
                ? 'No se encontró el fragmento en español.'
                : texto,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.55,
            ),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _tituloIdioma(
            idioma,
            icono,
          ),
          const SizedBox(height: 12),
          contenido,
        ],
      ),
    );
  }

  Widget _resultadoCard(
    Map<String, String> resultado,
  ) {
    final fragmento =
        resultado['fragmento'] ?? '';

    final fragmentoEspanol =
        resultado['fragmentoEspanol'] ?? '';

    return Card(
      margin:
          const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor:
          Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              resultado['titulo'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            if ((resultado['cantidad'] ?? '')
                .isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.indigo.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  resultado['cantidad'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final ancho =
                    constraints.maxWidth;

                if (ancho >= 700) {
                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child: _panelIdioma(
                          idioma:
                              'POQOMCHÍ',
                          texto:
                              fragmento,
                          icono:
                              Icons.translate,
                          resaltar: true,
                        ),
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: _panelIdioma(
                          idioma:
                              'ESPAÑOL',
                          texto:
                              fragmentoEspanol,
                          icono:
                              Icons.language,
                          resaltar: false,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _panelIdioma(
                      idioma:
                          'POQOMCHÍ',
                      texto:
                          fragmento,
                      icono:
                          Icons.translate,
                      resaltar: true,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    _panelIdioma(
                      idioma:
                          'ESPAÑOL',
                      texto:
                          fragmentoEspanol,
                      icono:
                          Icons.language,
                      resaltar: false,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            Align(
              alignment:
                  Alignment.centerRight,
              child:
                  TextButton.icon(
                onPressed: () {
                  _abrirArticulo(
                    resultado['enlace'] ??
                        '',
                  );
                },
                icon: const Icon(
                  Icons.open_in_new,
                  size: 20,
                ),
                label: const Text(
                  'Abrir artículo en WOL',
                ),
                style:
                    TextButton.styleFrom(
                  foregroundColor:
                      Colors.indigo,
                  textStyle:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.indigo,
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
            ),
            SizedBox(width: 10),
            Text(
              'Buscador Poqomchi\'',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1100,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Buscar en las publicaciones de jw.org',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Encuentra palabras y expresiones '
                  'en poqomchi\'',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey[700],
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          TextField(
                        controller:
                            _searchController,
                        textInputAction:
                            TextInputAction
                                .search,
                        onSubmitted:
                            (_) => _buscar(),
                        decoration:
                            InputDecoration(
                          hintText:
                              "Ejemplo: k'uhb'aal",
                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),
                          suffixIcon:
                              _searchController
                                      .text
                                      .isNotEmpty
                                  ? IconButton(
                                      icon:
                                          const Icon(
                                        Icons.clear,
                                      ),
                                      onPressed:
                                          () {
                                        setState(
                                          () {
                                            _searchController
                                                .clear();
                                            _resultados =
                                                [];
                                          },
                                        );
                                      },
                                    )
                                  : null,
                          filled: true,
                          fillColor:
                              Colors.white,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            borderSide:
                                BorderSide(
                              color:
                                  Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  Colors.indigo,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    SizedBox(
                      height: 56,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _buscando
                                ? null
                                : _buscar,
                        icon: _buscando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.search,
                              ),
                        label: Text(
                          _buscando
                              ? 'Buscando...'
                              : 'Buscar',
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.indigo,
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 22,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                if (_resultados.isNotEmpty)
                  Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      '${_resultados.length} '
                      'resultados encontrados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Colors.grey[800],
                      ),
                    ),
                  ),

                if (_resultados.isNotEmpty)
                  const SizedBox(
                    height: 12,
                  ),

                Expanded(
                  child:
                      _resultados.isEmpty
                          ? Center(
                              child:
                                  Column(
                                mainAxisSize:
                                    MainAxisSize
                                        .min,
                                children: [
                                  Icon(
                                    Icons
                                        .search_rounded,
                                    size: 64,
                                    color:
                                        Colors.grey[400],
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Text(
                                    _buscando
                                        ? 'Buscando resultados...'
                                        : 'Los resultados '
                                            'aparecerán aquí',
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        TextStyle(
                                      fontSize:
                                          16,
                                      color:
                                          Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView
                              .builder(
                              itemCount:
                                  _resultados
                                      .length,
                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                return _resultadoCard(
                                  _resultados[
                                      index],
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}