export default async (req) => {
  try {
    const incomingUrl = new URL(req.url);
    const palabra = incomingUrl.searchParams.get('q');

    if (!palabra) {
      return new Response(
        JSON.stringify({ error: 'Falta el parámetro q.' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
        },
      );
    }

    const urlWol = new URL(
      'https://wol.jw.org/poh/wol/s/r1086/lp-pqm',
    );

    urlWol.searchParams.set('q', palabra);
    urlWol.searchParams.set('p', 'par');
    urlWol.searchParams.set('r', 'occ');
    urlWol.searchParams.set('st', 'b');

    const respuesta = await fetch(urlWol);

    const cuerpo = await respuesta.text();

    return new Response(cuerpo, {
      status: respuesta.status,
      headers: {
        'Content-Type':
          respuesta.headers.get('Content-Type') ||
          'text/html; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
      },
    });
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