// api/search.js - Endpoint Serverless para Busca Preço SEFAZ-AM (Foco em Parintins)

export default async function handler(req, res) {
  // Compatibilidade com HTTP nativo do Node.js
  if (!res.status) {
    res.status = function(code) {
      this.statusCode = code;
      return this;
    };
  }
  if (!res.json) {
    res.json = function(data) {
      this.setHeader('Content-Type', 'application/json');
      this.end(JSON.stringify(data));
    };
  }

  // Configura CORS para permitir chamadas do Godot Web e Mobile
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const query = req.query.q || req.body?.q || '';
  const municipio = req.query.municipio || req.body?.municipio || 'Parintins';
  const dias = req.query.dias || req.body?.dias || '168'; // 168h = 7 dias, 48h = 2 dias, 24h = 1 dia
  const page = req.query.page || req.body?.page || '1';

  if (!query || query.trim().length === 0) {
    return res.status(400).json({ error: 'Termo de busca (q) é obrigatório' });
  }

  try {
    const params = new URLSearchParams();
    params.append('descricaoProd', query.trim());
    params.append('municipio', municipio);
    params.append('tipoConsulta', dias);
    params.append('distancia', '9999');
    params.append('cdGtin', '');
    params.append('latitude', '');
    params.append('longitude', '');

    const sefazUrl = `https://buscapreco.sefaz.am.gov.br/item/grupo/page/${page}`;
    
    const response = await fetch(sefazUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      },
      body: params.toString()
    });

    if (!response.ok) {
      return res.status(502).json({ error: `Erro na SEFAZ: HTTP ${response.status}` });
    }

    const html = await response.text();
    const items = parseSefazHtml(html, municipio);

    return res.status(200).json({
      query: query.trim(),
      municipio,
      dias,
      total: items.length,
      items
    });

  } catch (err) {
    console.error('Erro na consulta SEFAZ:', err);
    return res.status(500).json({ error: 'Falha ao consultar SEFAZ-AM', details: err.message });
  }
}

// Parser Regex robusto do HTML retornado pela SEFAZ
function parseSefazHtml(html, defaultMunicipio) {
  const items = [];
  
  // Encontra os blocos de cartões de produtos
  const cardRegex = /<div class="card small p hoverable">([\s\S]*?)<\/div>\s*<\/div>\s*<\/div>/g;
  let match;

  while ((match = cardRegex.exec(html)) !== null) {
    const cardHtml = match[1];

    // Nome do Produto
    const titleMatch = cardHtml.match(/data-tooltip="([^"]+)"/);
    const title = titleMatch ? cleanText(titleMatch[1]) : '';

    // Preço
    const priceMatch = cardHtml.match(/<b>R\$\s*([^<]+)<\/b>/i);
    let priceStr = priceMatch ? priceMatch[1].trim() : '0,00';
    let priceNum = parseFloat(priceStr.replace(/\./g, '').replace(',', '.'));
    if (isNaN(priceNum)) priceNum = 0;

    // Tempo desde a emissão da nota fiscal
    const timeMatch = cardHtml.match(/<p class="tb-valor-10">([\s\S]*?)<\/p>/i);
    let timeAgo = timeMatch ? cleanText(timeMatch[1]) : '';

    // Nome do Estabelecimento / Loja
    const storeMatch = cardHtml.match(/<p class="truncate tooltipped padding10"[^>]*data-tooltip="([^"]+)"/i);
    const store = storeMatch ? cleanText(storeMatch[1]) : 'Estabelecimento não identificado';

    // Endereço / Bairro
    const addrMatch = cardHtml.match(/class="truncate grey-text text-darken-4 tb-valor-10 tooltipped"[^>]*data-tooltip="([^"]+)"/i);
    const address = addrMatch ? cleanText(addrMatch[1]) : '';

    // Extrair Bairro do endereço (ex: "PARAIBA, NRO 1325, PALMARES, PARINTINS-AM, CEP 69153-010")
    let bairro = '';
    if (address) {
      const parts = address.split(',').map(p => p.trim());
      if (parts.length >= 3) {
        // Geralmente o bairro é o penúltimo antes da cidade
        for (let i = 1; i < parts.length; i++) {
          if (parts[i].toUpperCase().includes('PARINTINS') || parts[i].toUpperCase().includes('MANAUS')) {
            bairro = parts[i - 1] || '';
            break;
          }
        }
      }
      if (!bairro && parts.length >= 2) {
        bairro = parts[1];
      }
    }

    if (title && priceNum > 0) {
      items.push({
        id: `${store}-${title}-${priceNum}`.toLowerCase().replace(/[^a-z0-9]/g, '_'),
        nome: title,
        preco: priceNum,
        precoFormatado: `R$ ${priceStr}`,
        estabelecimento: store,
        endereco: address,
        bairro: bairro || 'Parintins',
        tempo: timeAgo
      });
    }
  }

  // Ordena pelo menor preço
  items.sort((a, b) => a.preco - b.preco);

  return items;
}

function cleanText(str) {
  if (!str) return '';
  return str
    .replace(/H\uFFFD|H/g, 'Há')
    .replace(/&amp;/g, '&')
    .replace(/&aacute;/g, 'á')
    .replace(/&eacute;/g, 'é')
    .replace(/&iacute;/g, 'í')
    .replace(/&oacute;/g, 'ó')
    .replace(/&uacute;/g, 'ú')
    .replace(/&atilde;/g, 'ã')
    .replace(/&otilde;/g, 'õ')
    .replace(/&ccedil;/g, 'ç')
    .replace(/&Aacute;/g, 'Á')
    .replace(/&Eacute;/g, 'É')
    .replace(/&Iacute;/g, 'Í')
    .replace(/&Oacute;/g, 'Ó')
    .replace(/&Uacute;/g, 'Ú')
    .replace(/&Atilde;/g, 'Ã')
    .replace(/&Otilde;/g, 'Õ')
    .replace(/&Ccedil;/g, 'Ç')
    .replace(/\s+/g, ' ')
    .trim();
}
