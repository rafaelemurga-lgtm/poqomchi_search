export default async (req) => {
  try {
    const incomingUrl = new URL(req.url);
    const palabra = incomingUrl.searchParams.get('q');

    if (!palabra) {
      return new Response(
        JSON.stringify({
          error: 'Falta el parámetro q.',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
          },
        },
      );
    }

    // =========================================================
    // 1. Buscar en Pocomchí
    // =========================================================

    const urlPoqomchi = new URL(
      'https://wol.jw.org/poh/wol/s/r1086/lp-pqm',
    );

    urlPoqomchi.searchParams.set('q', palabra);
    urlPoqomchi.searchParams.set('p', 'par');
    urlPoqomchi.searchParams.set('r', 'occ');
    urlPoqomchi.searchParams.set('st', 'b');

    const respuestaPoqomchi = await fetch(urlPoqomchi);

    if (!respuestaPoqomchi.ok) {
      const cuerpo = await respuestaPoqomchi.text();

      return new Response(
        JSON.stringify({
          error: `WOL respondió con el código ${respuestaPoqomchi.status}.`,
          detalle: cuerpo,
        }),
        {
          status: respuestaPoqomchi.status,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin': '*',
          },
        },
      );
    }

    const htmlPoqomchi = await respuestaPoqomchi.text();

    // =========================================================
    // 2. Encontrar los identificadores de los artículos
    // =========================================================

    const patronEnlaces =
      /\/poh\/wol\/d\/r1086\/lp-pqm\/(\d+)/g;

    const ids = new Set();

    let coincidencia;

    while ((coincidencia = patronEnlaces.exec(htmlPoqomchi)) !== null) {
      ids.add(coincidencia[1]);
    }

    // =========================================================
    // 3. Obtener las versiones españolas
    // =========================================================

    const articulosEspanol = {};

    for (const id of ids) {
      try {
        const urlEspanol = new URL(
          `https://wol.jw.org/es/wol/d/r4/lp-s/${id}`,
        );

        const respuestaEspanol = await fetch(urlEspanol);

        if (respuestaEspanol.ok) {
          articulosEspanol[id] =
              await respuestaEspanol.text();
        }
      } catch (error) {
        // Si un artículo no tiene versión española,
        // simplemente continuamos con los demás.
      }
    }

    // =========================================================
    // 4. Enviar todo a Flutter
    // =========================================================

    return new Response(
      JSON.stringify({
        ok: true,
        palabra: palabra,
        htmlPoqomchi: htmlPoqomchi,
        articulosEspanol: articulosEspanol,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: 'No se pudo conectar con WOL.',
        detalle: String(error),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      },
    );
  }
};